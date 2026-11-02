const express = require('express');
const rateLimit = require('express-rate-limit');
const AuthController = require('../controllers/authController');
const { authenticate } = require('../middleware/auth');
const { createRateLimitStore } = require('../utils/rateLimitStore');
const {
  validateLogin,
  validateVerification,
  validateRegistration,
  handleValidationErrors,
} = require('../middleware/validations');

const router = express.Router();

// Limite mais rígido específico para tentativas de login/2FA, além do
// limite geral por IP já aplicado em todo o app (server.js). Isso cobre a
// recomendação de segurança "proteção contra força bruta em login": mesmo
// que o IP tenha cota sobrando no limite geral, tentativas repetidas de
// login batem nesse teto bem mais cedo.
const loginAttemptLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 20, // 20 tentativas de login/verificação por IP a cada 15 min
  standardHeaders: true,
  legacyHeaders: false,
  store: createRateLimitStore(),
  message: { success: false, message: 'Muitas tentativas. Aguarde alguns minutos e tente novamente.' },
});

// Cadastro direto (nome, email/telefone, senha, cpf, role)
router.post('/register', validateRegistration, handleValidationErrors, AuthController.register);

// Iniciar processo de login
router.post('/login/start', loginAttemptLimiter, validateLogin, handleValidationErrors, AuthController.startLogin);

// Login com senha
router.post('/login/password', loginAttemptLimiter, validateLogin, handleValidationErrors, AuthController.loginWithPassword);

// Verificar código (OTP)
router.post('/verify', loginAttemptLimiter, validateVerification, handleValidationErrors, AuthController.verifyCode);

// Cadastro completo (após OTP, quando o usuário ainda não tinha dados definitivos)
router.post('/register/complete', authenticate, AuthController.completeRegistration);

// Reenviar código
router.post('/resend-code', loginAttemptLimiter, AuthController.resendCode);

// Refresh token: troca um refresh token válido por um novo access token
router.post('/refresh', AuthController.refreshAccessToken);

// Logout (revoga o refresh token enviado e o access token atual)
router.post('/logout', authenticate, AuthController.logout);

// Logout em todos os dispositivos (revoga todas as sessões do usuário)
router.post('/logout-all', authenticate, AuthController.logoutAllDevices);

// --- Autenticação em duas etapas (2FA / TOTP) ---
router.post('/2fa/setup', authenticate, AuthController.setupTwoFactor);
router.post('/2fa/enable', authenticate, AuthController.enableTwoFactor);
router.post('/2fa/disable', authenticate, AuthController.disableTwoFactor);
router.post('/2fa/verify-login', loginAttemptLimiter, AuthController.verifyTwoFactorLogin);

module.exports = router;
