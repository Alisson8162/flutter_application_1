const express = require('express');
const PaymentController = require('../controllers/paymentController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// Cadastro de cartão (SetupIntent) - apenas clientes
router.post('/setup-intent', authenticate, authorize(['cliente']), PaymentController.createSetupIntent);
router.post('/confirm-method', authenticate, authorize(['cliente']), PaymentController.confirmPaymentMethod);

// Listagem/gestão de cartões salvos
router.get('/methods', authenticate, authorize(['cliente']), PaymentController.listPaymentMethods);
router.put('/methods/:id/default', authenticate, authorize(['cliente']), PaymentController.setDefaultPaymentMethod);
router.delete('/methods/:id', authenticate, authorize(['cliente']), PaymentController.removePaymentMethod);

// Cobrança de uma corrida concluída (chamado pelo app do profissional/cliente
// após a corrida ser marcada como completed)
router.post('/rides/:id/charge', authenticate, authorize(['cliente']), PaymentController.chargeRide);

// PIX: gera QR code / copia-e-cola para pagar a corrida (alternativa ao
// cartão salvo). A confirmação chega depois via webhook da Stripe.
router.post('/rides/:id/charge-pix', authenticate, authorize(['cliente']), PaymentController.createPixCharge);

// Carteira digital: paga a corrida com o saldo já disponível (sem Stripe).
router.post('/rides/:id/charge-wallet', authenticate, authorize(['cliente']), PaymentController.chargeRideWithWallet);

// Status de pagamento da corrida (útil para o app fazer polling enquanto
// aguarda a confirmação de um PIX pendente)
router.get('/rides/:id/status', authenticate, PaymentController.getPaymentStatus);

// Webhook da Stripe é montado separadamente em server.js (precisa do corpo
// bruto da requisição, antes do express.json()).

module.exports = router;
