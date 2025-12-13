const express = require('express');
const AuthController = require('../controllers/authController');
const { validateLogin, validateVerification, validateRegistration } = require('../middleware/validation');

const router = express.Router();

// Iniciar processo de login
router.post('/login/start', validateLogin, AuthController.startLogin);

// Login com senha
router.post('/login/password', validateLogin, AuthController.loginWithPassword);

// Verificar código
router.post('/verify', validateVerification, AuthController.verifyCode);

// Cadastro completo
router.post('/register/complete', validateRegistration, AuthController.completeRegistration);

// Reenviar código
router.post('/resend-code', AuthController.resendCode);

// Logout
router.post('/logout', AuthController.logout);

module.exports = router;