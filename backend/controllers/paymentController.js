const { stripe, isConfigured } = require('../config/stripe');
const { query } = require('../config/database');
const Client = require('../models/Client');
const User = require('../models/User');
const Ride = require('../models/Ride');
const PaymentMethod = require('../models/PaymentMethod');
const Wallet = require('../models/Wallet');

const notConfiguredResponse = (res) =>
  res.status(503).json({
    success: false,
    message:
      'Pagamentos não configurados no servidor (defina STRIPE_SECRET_KEY no .env)',
  });

class PaymentController {
  // Garante que o cliente tem um Stripe Customer, criando se necessário
  async _ensureStripeCustomer(client, user) {
    if (client.stripe_customer_id) return client.stripe_customer_id;

    const customer = await stripe.customers.create({
      name: user.name,
      email: user.email || undefined,
      phone: user.phone || undefined,
      metadata: { client_id: client.id, user_id: user.id },
    });

    await client.update({ stripe_customer_id: customer.id });
    return customer.id;
  }

  // Cria um SetupIntent: o app usa o client_secret retornado com o SDK da
  // Stripe (flutter_stripe) para coletar o cartão e confirmá-lo SEM que o
  // número do cartão jamais passe pelo nosso backend.
  async createSetupIntent(req, res) {
    try {
      if (!isConfigured()) return notConfiguredResponse(res);

      const { userId } = req.user;
      const user = await User.findById(userId);
      const client = await Client.findByUserId(userId);

      if (!client) {
        return res.status(404).json({ success: false, message: 'Perfil de cliente não encontrado' });
      }

      const stripeCustomerId = await this._ensureStripeCustomer(client, user);

      const setupIntent = await stripe.setupIntents.create({
        customer: stripeCustomerId,
        payment_method_types: ['card'],
      });

      res.json({
        success: true,
        data: {
          client_secret: setupIntent.client_secret,
          customer_id: stripeCustomerId,
        },
      });
    } catch (error) {
      console.error('Create setup intent error:', error);
      res.status(500).json({ success: false, message: 'Erro ao iniciar cadastro de cartão' });
    }
  }

  // Chamado pelo app depois que o SetupIntent foi confirmado com sucesso
  // pelo SDK da Stripe - recebe apenas o payment_method_id (nunca dados do
  // cartão) e persiste os metadados não sensíveis (bandeira, últimos 4
  // dígitos, validade) para exibição.
  async confirmPaymentMethod(req, res) {
    try {
      if (!isConfigured()) return notConfiguredResponse(res);

      const { userId } = req.user;
      const { payment_method_id, set_as_default } = req.body;

      if (!payment_method_id) {
        return res.status(400).json({ success: false, message: 'payment_method_id é obrigatório' });
      }

      const client = await Client.findByUserId(userId);
      if (!client) {
        return res.status(404).json({ success: false, message: 'Perfil de cliente não encontrado' });
      }

      const pm = await stripe.paymentMethods.retrieve(payment_method_id);

      if (!pm.card) {
        return res.status(400).json({ success: false, message: 'Método de pagamento inválido' });
      }

      const existing = await PaymentMethod.findByClientId(client.id);
      const alreadySaved = existing.find((p) => p.stripe_payment_method_id === payment_method_id);

      let id = alreadySaved?.id;
      if (!alreadySaved) {
        id = await PaymentMethod.create({
          client_id: client.id,
          stripe_payment_method_id: payment_method_id,
          brand: pm.card.brand,
          ultimos_quatro: pm.card.last4,
          exp_month: pm.card.exp_month,
          exp_year: pm.card.exp_year,
          is_default: set_as_default === true || existing.length === 0,
        });
      } else if (set_as_default) {
        await PaymentMethod.setDefault(id, client.id);
      }

      res.status(201).json({ success: true, message: 'Cartão salvo com sucesso', data: { id } });
    } catch (error) {
      console.error('Confirm payment method error:', error);
      res.status(500).json({ success: false, message: 'Erro ao salvar cartão' });
    }
  }

  async listPaymentMethods(req, res) {
    try {
      const { userId } = req.user;
      const client = await Client.findByUserId(userId);
      if (!client) {
        return res.status(404).json({ success: false, message: 'Perfil de cliente não encontrado' });
      }

      const methods = await PaymentMethod.findByClientId(client.id);
      res.json({ success: true, data: methods });
    } catch (error) {
      console.error('List payment methods error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  async setDefaultPaymentMethod(req, res) {
    try {
      const { userId } = req.user;
      const { id } = req.params;

      const client = await Client.findByUserId(userId);
      const method = await PaymentMethod.findById(id);

      if (!client || !method || method.client_id !== client.id) {
        return res.status(404).json({ success: false, message: 'Método de pagamento não encontrado' });
      }

      await PaymentMethod.setDefault(id, client.id);
      res.json({ success: true, message: 'Cartão definido como padrão' });
    } catch (error) {
      console.error('Set default payment method error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  async removePaymentMethod(req, res) {
    try {
      const { userId } = req.user;
      const { id } = req.params;

      const client = await Client.findByUserId(userId);
      const method = await PaymentMethod.findById(id);

      if (!client || !method || method.client_id !== client.id) {
        return res.status(404).json({ success: false, message: 'Método de pagamento não encontrado' });
      }

      if (isConfigured()) {
        try {
          await stripe.paymentMethods.detach(method.stripe_payment_method_id);
        } catch (e) {
          // Se já foi destacado na Stripe por algum outro motivo, seguimos
          // removendo o registro local mesmo assim.
          console.warn('Stripe detach warning:', e.message);
        }
      }

      await PaymentMethod.delete(id);
      res.json({ success: true, message: 'Cartão removido com sucesso' });
    } catch (error) {
      console.error('Remove payment method error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Lógica de cobrança reutilizável: usada tanto pela rota
  // POST /api/payments/rides/:id/charge quanto pela cobrança automática
  // disparada pelo RideController assim que uma corrida é concluída.
  async chargeRideInternal(rideId) {
    if (!isConfigured()) {
      return { success: false, message: 'Stripe não configurada' };
    }

    const ride = await Ride.findById(rideId);
    if (!ride) return { success: false, message: 'Corrida não encontrada' };
    if (ride.status !== 'completed') {
      return { success: false, message: 'Só é possível cobrar corridas concluídas' };
    }
    if (ride.payment_status === 'paid') {
      return { success: false, message: 'Corrida já foi paga' };
    }

    const client = await Client.findByUserId(ride.client_id);
    const user = await User.findById(ride.client_id);
    if (!client) return { success: false, message: 'Cliente não encontrado' };

    const defaultMethod = await PaymentMethod.findDefaultForClient(client.id);
    if (!defaultMethod) {
      return { success: false, message: 'Cliente não possui método de pagamento cadastrado' };
    }

    const stripeCustomerId = await this._ensureStripeCustomer(client, user);

    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(Number(ride.final_price) * 100),
        currency: 'brl',
        customer: stripeCustomerId,
        payment_method: defaultMethod.stripe_payment_method_id,
        off_session: true,
        confirm: true,
        metadata: { ride_id: ride.id },
      });

      await ride.update({
        payment_status: paymentIntent.status === 'succeeded' ? 'paid' : 'pending',
        stripe_payment_intent_id: paymentIntent.id,
        payment_method: 'card',
      });

      return { success: true, status: paymentIntent.status };
    } catch (error) {
      if (error.type === 'StripeCardError') {
        await ride.update({ payment_status: 'failed' });
        return { success: false, message: 'Cartão recusado: ' + error.message };
      }
      throw error;
    }
  }

  // Cobra o valor final de uma corrida concluída usando o cartão padrão do
  // cliente. Chamado após RideController.completeRide (rota manual, caso a
  // cobrança automática tenha falhado ou não tenha sido tentada).
  async chargeRide(req, res) {
    try {
      if (!isConfigured()) return notConfiguredResponse(res);

      // CORRIGIDO: este endpoint cobrava a corrida sem checar se quem
      // estava chamando era o próprio cliente dela - qualquer usuário
      // autenticado podia disparar a cobrança de QUALQUER corrida
      // informando o id. Os endpoints de PIX/carteira já nasceram com essa
      // checagem; faltava aqui.
      const ride = await Ride.findById(req.params.id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.client_id !== req.user.userId) {
        return res.status(403).json({ success: false, message: 'Você não é o cliente desta corrida' });
      }

      const result = await this.chargeRideInternal(req.params.id);

      if (!result.success) {
        const status = result.message?.includes('recusado') ? 402 : 400;
        return res.status(status).json(result);
      }

      res.json({ success: true, message: 'Pagamento processado', data: { status: result.status } });
    } catch (error) {
      console.error('Charge ride error:', error);
      res.status(500).json({ success: false, message: 'Erro ao processar pagamento' });
    }
  }

  // Cobra o valor final de uma corrida concluída usando o saldo da
  // carteira digital do cliente - alternativa ao cartão/PIX, sem depender
  // da Stripe (débito é puramente interno).
  async chargeRideWithWallet(req, res) {
    try {
      const { userId } = req.user;
      const { id } = req.params;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.client_id !== userId) {
        return res.status(403).json({ success: false, message: 'Você não é o cliente desta corrida' });
      }
      if (ride.status !== 'completed') {
        return res.status(400).json({ success: false, message: 'Só é possível cobrar corridas concluídas' });
      }
      if (ride.payment_status === 'paid') {
        return res.status(400).json({ success: false, message: 'Corrida já foi paga' });
      }

      const amount = Number(ride.final_price ?? ride.estimated_price);
      const debit = await Wallet.debit(userId, amount, {
        description: `Pagamento da corrida`,
        rideId: ride.id,
      });

      if (!debit.success) {
        return res.status(402).json(debit);
      }

      await ride.update({ payment_status: 'paid', payment_method: 'wallet' });

      res.json({
        success: true,
        message: 'Pagamento processado via carteira',
        data: { balance: debit.wallet.balance },
      });
    } catch (error) {
      console.error('Charge ride with wallet error:', error);
      res.status(500).json({ success: false, message: 'Erro ao processar pagamento' });
    }
  }

  // Gera uma cobrança PIX para a corrida - alternativa ao cartão salvo.
  // Diferente do cartão, o PIX não confirma na hora: devolvemos o QR
  // code/copia-e-cola para o app exibir, e a confirmação chega depois via
  // webhook (payment_intent.succeeded), do mesmo jeito que já acontecia
  // para cartão.
  async createPixCharge(req, res) {
    try {
      if (!isConfigured()) return notConfiguredResponse(res);

      const { userId } = req.user;
      const { id } = req.params;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.client_id !== userId) {
        return res.status(403).json({ success: false, message: 'Você não é o cliente desta corrida' });
      }
      if (ride.status !== 'completed') {
        return res.status(400).json({ success: false, message: 'Só é possível cobrar corridas concluídas' });
      }
      if (ride.payment_status === 'paid') {
        return res.status(400).json({ success: false, message: 'Corrida já foi paga' });
      }

      const client = await Client.findByUserId(userId);
      const user = await User.findById(userId);
      const stripeCustomerId = await this._ensureStripeCustomer(client, user);

      const amount = Math.round(Number(ride.final_price ?? ride.estimated_price) * 100);

      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency: 'brl',
        customer: stripeCustomerId,
        payment_method_types: ['pix'],
        payment_method_data: { type: 'pix' },
        confirm: true,
        metadata: { ride_id: ride.id },
      });

      await ride.update({
        stripe_payment_intent_id: paymentIntent.id,
        payment_method: 'pix',
      });

      const pix = paymentIntent.next_action?.pix_display_qr_code;
      if (!pix) {
        return res.status(500).json({
          success: false,
          message: 'A Stripe não retornou os dados do QR code PIX. Tente novamente.',
        });
      }

      res.json({
        success: true,
        data: {
          qrCodeText: pix.data, // string "copia e cola"
          qrCodeImageUrl: pix.image_url_png,
          expiresAt: pix.expires_at ? new Date(pix.expires_at * 1000).toISOString() : null,
          paymentIntentId: paymentIntent.id,
        },
      });
    } catch (error) {
      console.error('Create PIX charge error:', error);
      res.status(500).json({ success: false, message: 'Erro ao gerar cobrança PIX' });
    }
  }

  // O app pode chamar isso enquanto aguarda a confirmação do PIX (polling
  // simples), em vez de depender só do WebSocket/webhook.
  async getPaymentStatus(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.client_id !== userId && ride.driver_id !== userId) {
        return res.status(403).json({ success: false, message: 'Acesso não autorizado a esta corrida' });
      }

      res.json({
        success: true,
        data: {
          payment_status: ride.payment_status,
          payment_method: ride.payment_method,
        },
      });
    } catch (error) {
      console.error('Get payment status error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Reembolsa uma corrida já cobrada. Reaproveitável: chamado tanto pelo
  // endpoint manual do painel admin quanto automaticamente pelo
  // RideController quando uma corrida já paga precisa ser cancelada (rede
  // de segurança - evita cliente pagar por um serviço cancelado).
  async refundRideInternal(rideId, reason) {
    const ride = await Ride.findById(rideId);
    if (!ride) return { success: false, message: 'Corrida não encontrada' };
    if (ride.payment_status !== 'paid') {
      return { success: false, message: 'Só é possível reembolsar corridas com pagamento confirmado' };
    }

    // Pago com saldo da carteira: reembolso é só devolver o valor pro
    // saldo, sem envolver a Stripe (não houve cobrança externa nenhuma).
    if (ride.payment_method === 'wallet') {
      const amount = Number(ride.final_price ?? ride.estimated_price);
      await Wallet.credit(ride.client_id, amount, {
        description: 'Reembolso de corrida',
        rideId: ride.id,
      });
      await ride.update({
        payment_status: 'refunded',
        refunded_at: new Date(),
        refund_reason: reason || null,
      });
      return { success: true, refundId: null };
    }

    if (!isConfigured()) {
      return { success: false, message: 'Stripe não configurada' };
    }
    if (!ride.stripe_payment_intent_id) {
      return { success: false, message: 'Corrida não possui cobrança associada' };
    }

    try {
      const refund = await stripe.refunds.create({
        payment_intent: ride.stripe_payment_intent_id,
        reason: 'requested_by_customer',
        metadata: { ride_id: ride.id },
      });

      await ride.update({
        payment_status: 'refunded',
        stripe_refund_id: refund.id,
        refunded_at: new Date(),
        refund_reason: reason || null,
      });

      return { success: true, refundId: refund.id };
    } catch (error) {
      console.error('Refund error:', error.message);
      return { success: false, message: 'Erro ao processar reembolso: ' + error.message };
    }
  }

  // Endpoint manual (painel admin) para reembolsar uma corrida - ex.:
  // serviço não prestado a contento, cobrança duplicada, etc.
  async refundRide(req, res) {
    try {
      const { reason } = req.body;
      const result = await this.refundRideInternal(req.params.id, reason);

      if (!result.success) {
        return res.status(400).json(result);
      }

      res.json({ success: true, message: 'Reembolso processado com sucesso', data: { refundId: result.refundId } });
    } catch (error) {
      console.error('Refund ride error:', error);
      res.status(500).json({ success: false, message: 'Erro ao processar reembolso' });
    }
  }

  // Webhook da Stripe (pagamentos de corrida + assinatura mensal do profissional)
  async webhook(req, res) {
    if (!isConfigured()) return res.status(503).send('Stripe not configured');

    // BUG CORRIGIDO: a assinatura do webhook (`stripe-signature` header)
    // nunca era lida - a variável `sig` era usada em
    // `stripe.webhooks.constructEvent(req.body, sig, ...)` sem jamais ter
    // sido declarada. Isso derrubava (ReferenceError) TODA chamada de
    // webhook sempre que STRIPE_WEBHOOK_SECRET estava configurado - ou
    // seja, exatamente na configuração correta de produção. Sem o webhook
    // funcionando, nenhuma cobrança (corrida ou assinatura) jamais
    // atualizava o status no banco.
    const sig = req.headers['stripe-signature'];
    let event;

    try {
      if (process.env.STRIPE_WEBHOOK_SECRET) {
        event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
      } else {
        // Sem secret configurado (ex: ambiente de dev sem Stripe CLI) - aceita
        // o payload como veio, sem verificar assinatura. NÃO faça isso em
        // produção: configure STRIPE_WEBHOOK_SECRET.
        event = JSON.parse(req.body.toString());
      }
    } catch (err) {
      console.error('Webhook signature verification failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    try {
      if (event.type === 'payment_intent.succeeded' || event.type === 'payment_intent.payment_failed') {
        const paymentIntent = event.data.object;
        const rideId = paymentIntent.metadata?.ride_id;
        if (rideId) {
          const ride = await Ride.findById(rideId);
          if (ride) {
            await ride.update({
              payment_status: event.type === 'payment_intent.succeeded' ? 'paid' : 'failed',
            });
          }
        }
      }

      // Reembolso feito diretamente no painel da Stripe (fora do nosso
      // endpoint /rides/:id/refund) - mantém `rides.payment_status`
      // sincronizado mesmo quando o estorno não passou pelo nosso backend.
      if (event.type === 'charge.refunded') {
        const charge = event.data.object;
        const paymentIntentId = charge.payment_intent;
        if (paymentIntentId) {
          const result = await query('SELECT id FROM rides WHERE stripe_payment_intent_id = $1', [paymentIntentId]);
          const rideId = result.rows[0]?.id;
          if (rideId) {
            const ride = await Ride.findById(rideId);
            if (ride && ride.payment_status !== 'refunded') {
              await ride.update({
                payment_status: 'refunded',
                stripe_refund_id: charge.refunds?.data?.[0]?.id || ride.stripe_refund_id,
                refunded_at: new Date(),
              });
            }
          }
        }
      }

      // Assinatura mensal do profissional: é isso que liga/desliga
      // `professionals.conta_ativa`, o gate que decide se ele pode ficar
      // online. Delegado ao SubscriptionController para manter a lógica de
      // assinatura toda em um lugar só.
      if (
        [
          'invoice.paid',
          'invoice.payment_failed',
          'customer.subscription.updated',
          'customer.subscription.deleted',
        ].includes(event.type)
      ) {
        // eslint-disable-next-line global-require
        const SubscriptionController = require('./subscriptionController');
        await SubscriptionController.handleWebhookEvent(event);
      }

      res.json({ received: true });
    } catch (error) {
      console.error('Webhook handling error:', error);
      res.status(500).json({ received: false });
    }
  }
}

module.exports = new PaymentController();
