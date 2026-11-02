const express = require('express');
const UserController = require('../controllers/userController');
const { authenticate } = require('../middleware/auth');
const { uploadImages } = require('../middleware/upload');

const router = express.Router();

// Perfil do usuário
router.get('/profile', authenticate, UserController.getProfile);
router.put('/profile', authenticate, UserController.updateProfile);

// Upload de documentos
router.post('/documents', authenticate, uploadImages, UserController.uploadDocuments);

// Endereço
router.post('/address', authenticate, UserController.addAddress);
router.get('/address', authenticate, UserController.getAddress);
router.put('/address/:id', authenticate, UserController.updateAddress);

// Métodos de pagamento: ver /api/payments/* (routes/payments.js), que usa a
// Stripe em vez de receber dados de cartão diretamente neste backend.

module.exports = router;
