const { stripe, isConfigured } = require('../config/stripe');
const User = require('../models/User');
const Professional = require('../models/Professional');
const ProfessionalSubscription = require('../models/ProfessionalSubscription');

const notConfiguredResponse = (res) =>
  res.status(503).json({
    success: false,
    message: 'Pagamentos não configurados no servidor (defina STRIPE_SECRET_KEY no .env)',
  });

// Valor da mensalidade: usa um Price já criado no dashboard da Stripe se
// STRIPE_SUBSCRIPTION_PRICE_ID estiver definido; caso contrário, cria o
// preço "na hora" (price_data) usando STRIPE_SUBSCRIPTION_AMOUNT_CENTS -
// assim a assinatura funciona sem precisar configurar nada manualmente no
// painel da Stripe antes de começar a testar.
const DEFAULT_AMOUNT_CENTS = 4990; // R$ 49,90

function buildSubscriptionItem() {
  if (process.env.STRIPE_SUBSCRIPTION_PRICE_ID) {
    return { price: process.env.STRIPE_SUBSCRIPTION_PRICE_ID };
  }
  const amount = Number(process.env.STRIPE_SUBSCRIPTION_AMOUNT_CENTS) || DEFAULT_AMOUNT_CENTS;
  return {
    price_data: {
      currency: 'brl',
      unit_amount: amount,
      recurring: { interval: 'month' },
      product_data: { name: 'Assinatura mensal - Profissional FalaComigo' },
    },
  };
}

class SubscriptionController {
  async _ensureStripeCustomer(professional, user, subscription) {
    if (subscription?.stripe_customer_id) return subscription.stripe_customer_id;

    const customer = await stripe.customers.create({
      name: user.name,
      email: user.email || undefined,
      phone: user.phone || undefined,
      metadata: { professional_id: professional.id, user_id: user.id },
    });

    await ProfessionalSubscription.upsert(professional.id, { stripe_customer_id: customer.id });
    return customer.id;
  }

  // Passo 1: cria um SetupIntent para o app coletar o cartão direto com a
  // Stripe (o número do cartão nunca passa pelo nosso backend).
  async createSetupIntent(req, res) {
    try {
      if (!isConfigured()) return notConfiguredResponse(res);

      const { userId } = req.user;
      const user = await User.findById(userId);
      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Perfil profissional não encontrado' });
      }

      const subscription = await ProfessionalSubscription.findByProfessionalId(professional.id);
      const stripeCustomerId = await this._ensureStripeCustomer(professional, user, subscription);

      const setupIntent = await stripe.setupIntents.create({
        customer: stripeCustomerId,
        payment_method_types: ['card'],
      });

      res.json({
        success: true,
        data: { client_secret: setupIntent.client_secret, customer_id: stripeCustomerId },
      });
    } catch (error) {
      console.error('Create subscription setup intent error:', error);
      res.status(500).json({ success: false, message: 'Erro ao iniciar cadastro da assinatura' });
    }
  }

  // Passo 2: depois que o app confirma o SetupIntent com o SDK da Stripe,
  // cria de fato a assinatura recorrente usando o cartão confirmado.
  async confirmSubscription(req, res) {
    try {
      if (!isConfigured()) return notConfiguredResponse(res);

      const { userId } = req.user;
      const { payment_method_id } = req.body;

      if (!payment_method_id) {
        return res.status(400).json({ success: false, message: 'payment_method_id é obrigatório' });
      }

      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Perfil profissional não encontrado' });
      }

      let subscriptionRecord = await ProfessionalSubscription.findByProfessionalId(professional.id);
      if (!subscriptionRecord?.stripe_customer_id) {
        return res.status(400).json({
          success: false,
          message: 'Inicie o cadastro do cartão primeiro (POST /subscription/setup-intent)',
        });
      }

      // Se já existe uma assinatura Stripe ativa/incompleta para este
      // profissional, não cria outra - só troca o cartão (evita cobrar duas
      // mensalidades por engano se o app chamar confirm duas vezes).
      if (subscriptionRecord.stripe_subscription_id) {
        await stripe.subscriptions.update(subscriptionRecord.stripe_subscription_id, {
          default_payment_method: payment_method_id,
        });
      } else {
        await stripe.paymentMethods.attach(payment_method_id, {
          customer: subscriptionRecord.stripe_customer_id,
        });
        await stripe.customers.update(subscriptionRecord.stripe_customer_id, {
          invoice_settings: { default_payment_method: payment_method_id },
        });

        const stripeSubscription = await stripe.subscriptions.create({
          customer: subscriptionRecord.stripe_customer_id,
          items: [buildSubscriptionItem()],
          default_payment_method: payment_method_id,
          expand: ['latest_invoice.payment_intent'],
          metadata: { professional_id: professional.id },
        });

        subscriptionRecord = await ProfessionalSubscription.upsert(professional.id, {
          stripe_subscription_id: stripeSubscription.id,
          stripe_payment_method_id: payment_method_id,
          status: stripeSubscription.status,
          current_period_end: new Date(stripeSubscription.current_period_end * 1000),
        });
      }

      // A conta só é ativada de verdade quando a Stripe confirma o status
      // "active" (a cobrança da primeira fatura foi aprovada). Isso também
      // é reforçado pelo webhook (invoice.paid), que é a fonte de verdade
      // para renovações futuras - aqui é só para o app já refletir o
      // resultado imediatamente após a confirmação, sem esperar o webhook.
      await professional.update({ conta_ativa: subscriptionRecord.status === 'active' });

      res.json({
        success: true,
        message:
          subscriptionRecord.status === 'active'
            ? 'Assinatura ativada com sucesso!'
            : 'Assinatura criada, aguardando confirmação do pagamento.',
        data: { status: subscriptionRecord.status },
      });
    } catch (error) {
      console.error('Confirm subscription error:', error);
      if (error.type === 'StripeCardError') {
        return res.status(402).json({ success: false, message: 'Cartão recusado: ' + error.message });
      }
      res.status(500).json({ success: false, message: 'Erro ao confirmar assinatura' });
    }
  }

  async getStatus(req, res) {
    try {
      const { userId } = req.user;
      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Perfil profissional não encontrado' });
      }

      const subscription = await ProfessionalSubscription.findByProfessionalId(professional.id);

      res.json({
        success: true,
        data: {
          conta_ativa: professional.conta_ativa,
          documentacao_aprovada: professional.documentacao_aprovada,
          subscription_status: subscription?.status || 'inactive',
          current_period_end: subscription?.current_period_end || null,
        },
      });
    } catch (error) {
      console.error('Get subscription status error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Cancela a assinatura (o profissional decide sair da plataforma). A
  // conta continua ativa até o fim do período já pago (comportamento padrão
  // da Stripe com `cancel_at_period_end`), e é desativada automaticamente
  // pelo webhook quando o período acabar.
  async cancelSubscription(req, res) {
    try {
      if (!isConfigured()) return notConfiguredResponse(res);

      const { userId } = req.user;
      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Perfil profissional não encontrado' });
      }

      const subscription = await ProfessionalSubscription.findByProfessionalId(professional.id);
      if (!subscription?.stripe_subscription_id) {
        return res.status(400).json({ success: false, message: 'Nenhuma assinatura ativa encontrada' });
      }

      await stripe.subscriptions.update(subscription.stripe_subscription_id, {
        cancel_at_period_end: true,
      });

      res.json({
        success: true,
        message: 'Assinatura cancelada. Você continua ativo até o fim do período já pago.',
      });
    } catch (error) {
      console.error('Cancel subscription error:', error);
      res.status(500).json({ success: false, message: 'Erro ao cancelar assinatura' });
    }
  }

  // Chamado pelo webhook central (paymentController.webhook) para os
  // eventos de ciclo de vida da assinatura. É a FONTE DE VERDADE de
  // `professionals.conta_ativa` - cobre tanto a primeira cobrança quanto
  // renovações mensais e falhas de pagamento futuras (cartão expirado,
  // saldo insuficiente etc.), que não passam pelo fluxo de confirmSubscription.
  async handleWebhookEvent(event) {
    const object = event.data.object;
    const stripeSubscriptionId = object.subscription || object.id;
    if (!stripeSubscriptionId) return;

    const subscriptionRecord = await ProfessionalSubscription.findByStripeSubscriptionId(
      stripeSubscriptionId
    );
    if (!subscriptionRecord) return;

    const professional = await Professional.findById(subscriptionRecord.professional_id);
    if (!professional) return;

    switch (event.type) {
      case 'invoice.paid': {
        const stripeSubscription = await stripe.subscriptions.retrieve(stripeSubscriptionId);
        await ProfessionalSubscription.upsert(professional.id, {
          status: 'active',
          current_period_end: new Date(stripeSubscription.current_period_end * 1000),
        });
        await professional.update({ conta_ativa: true });
        break;
      }
      case 'invoice.payment_failed': {
        await ProfessionalSubscription.upsert(professional.id, { status: 'past_due' });
        // Requisito de negócio: mensalidade não paga = conta desativada.
        await professional.update({ conta_ativa: false, disponivel: false });
        break;
      }
      case 'customer.subscription.updated': {
        await ProfessionalSubscription.upsert(professional.id, {
          status: object.status,
          current_period_end: new Date(object.current_period_end * 1000),
        });
        await professional.update({ conta_ativa: object.status === 'active' });
        break;
      }
      case 'customer.subscription.deleted': {
        await ProfessionalSubscription.upsert(professional.id, { status: 'canceled' });
        await professional.update({ conta_ativa: false, disponivel: false });
        break;
      }
      default:
        break;
    }
  }
}

module.exports = new SubscriptionController();
