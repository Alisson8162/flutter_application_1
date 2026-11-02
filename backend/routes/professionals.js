const express = require('express');
const ProfessionalController = require('../controllers/professionalController');
const { authenticate, authorize } = require('../middleware/auth');
const { uploadProfessionalDocs } = require('../middleware/upload');

const router = express.Router();

// Buscar profissionais (público)
router.get('/search', ProfessionalController.searchProfessionals);

// Perfil profissional (apenas para profissionais)
router.get('/profile', authenticate, authorize(['profissional']), ProfessionalController.getProfile);
router.put('/profile', authenticate, authorize(['profissional']), ProfessionalController.updateProfile);

// Disponibilidade
router.put(
  '/availability',
  authenticate,
  authorize(['profissional']),
  ProfessionalController.updateAvailability
);

// Documentação profissional
router.post(
  '/documents',
  authenticate,
  authorize(['profissional']),
  uploadProfessionalDocs,
  ProfessionalController.uploadProfessionalDocuments
);
router.get(
  '/documents/status',
  authenticate,
  authorize(['profissional']),
  ProfessionalController.getDocumentStatus
);

// Ganhos
router.get('/earnings', authenticate, authorize(['profissional']), ProfessionalController.getEarnings);

// Avaliações (público)
router.get('/:id/reviews', ProfessionalController.getReviews);

module.exports = router;
