const { stripe, isConfigured } = require('../config/stripe');
const Client = require('../models/Client');
const User = require('../models/User');
const PaymentMethod = require('../models/PaymentMethod');
const Wallet = require('../models/Wallet');
const PaymentController = require('./paymentController');

const notConfiguredResponse = (res) =>
  res.status(503).json({
    success: false,
    message: 'Pagamentos não configurados no servidor (defina STRIPE_SECRET_KEY no .env)',
  });

class WalletController {
  async getWallet(req, res) {
    try {
      const { userId } = req.user;
      const wallet = await Wallet.findOrCreateForUser(userId);
      const transactions = await Wallet.findTransactions(userId, { limit: req.query.limit });

      res.json({ success: true, data: { balance: wallet.balance, transactions } });
    } catch (error) {
      console.error('Get wallet error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Recarrega a carteira cobrando o cartão padrão salvo do cliente - mesmo
  // padrão de cobrança "off_session" já usado em
  // PaymentController.chargeRideInternal.
  async addFunds(req, res) {
    try {
      if (!isConfigured()) return notConfiguredResponse(res);

      const { amount } = req.body;
      const value = Number(amount);
      if (!value || value <= 0) {
        return res.status(400).json({ success: false, message: 'Informe um valor de recarga válido' });
      }

      const { userId } = req.user;
      const client = await Client.findByUserId(userId);
      if (!client) {
        return res.status(404).json({ success: false, message: 'Perfil de cliente não encontrado' });
      }

      const defaultMethod = await PaymentMethod.findDefaultForClient(client.id);
      if (!defaultMethod) {
        return res.status(400).json({ success: false, message: 'Cadastre um cartão antes de adicionar saldo' });
      }

      const user = await User.findById(userId);
      const stripeCustomerId = await PaymentController._ensureStripeCustomer(client, user);

      let paymentIntent;
      try {
        paymentIntent = await stripe.paymentIntents.create({
          amount: Math.round(value * 100),
          currency: 'brl',
          customer: stripeCustomerId,
          payment_method: defaultMethod.stripe_payment_method_id,
          off_session: true,
          confirm: true,
          metadata: { wallet_topup: 'true', user_id: userId },
        });
      } catch (error) {
        if (error.type === 'StripeCardError') {
          return res.status(402).json({ success: false, message: 'Cartão recusado: ' + error.message });
        }
        throw error;
      }

      if (paymentIntent.status !== 'succeeded') {
        return res.status(402).json({ success: false, message: 'Pagamento não confirmado pela operadora do cartão' });
      }

      const wallet = await Wallet.credit(userId, value, {
        description: 'Recarga via cartão',
        stripePaymentIntentId: paymentIntent.id,
      });

      res.json({ success: true, message: 'Saldo adicionado com sucesso', data: { balance: wallet.balance } });
    } catch (error) {
      console.error('Add funds error:', error);
      res.status(500).json({ success: false, message: 'Erro ao adicionar saldo' });
    }
  }
}

module.exports = new WalletController();
