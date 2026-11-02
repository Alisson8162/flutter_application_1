const express = require('express');
const rateLimit = require('express-rate-limit');
const AdminController = require('../controllers/adminController');
const CouponController = require('../controllers/couponController');
const { authenticate, authorize } = require('../middleware/auth');
const { createRateLimitStore } = require('../utils/rateLimitStore');

const router = express.Router();

// O login do admin é o alvo de força bruta mais crítico do sistema (acesso
// total de aprovação/dados) - limite bem mais apertado que o geral do app.
const adminLoginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  store: createRateLimitStore(),
  message: { success: false, message: 'Muitas tentativas. Aguarde alguns minutos e tente novamente.' },
});

// Login do painel administrativo (não usa /api/auth - admins não são
// clientes nem profissionais)
router.post('/login', adminLoginLimiter, AdminController.login);

// A partir daqui, todas as rotas exigem um JWT de admin válido
router.use(authenticate, authorize(['admin']));

router.get('/stats', AdminController.getStats);

router.get('/professionals/pending', AdminController.listPendingProfessionals);
router.post('/professionals/:id/approve', AdminController.approveProfessional);
router.post('/professionals/:id/reject', AdminController.rejectProfessional);

router.post('/documents/:id/approve', AdminController.approveDocument);
router.post('/documents/:id/reject', AdminController.rejectDocument);

router.get('/rides/recent', AdminController.listRecentRides);
router.post('/rides/:id/refund', AdminController.refundRide);

// Cupons de desconto
router.get('/coupons', CouponController.listCoupons);
router.post('/coupons', CouponController.createCoupon);
router.put('/coupons/:id/active', CouponController.setCouponActive);

// Crédito manual na carteira digital de um cliente (suporte)
router.post('/wallet/:userId/credit', AdminController.creditWallet);

module.exports = router;
