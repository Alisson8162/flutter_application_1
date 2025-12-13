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

// Métodos de pagamento (apenas para clientes)
router.get('/payment-methods', authenticate, UserController.getPaymentMethods);
router.post('/payment-methods', authenticate, UserController.addPaymentMethod);
router.delete('/payment-methods/:id', authenticate, UserController.removePaymentMethod);

module.exports = router;