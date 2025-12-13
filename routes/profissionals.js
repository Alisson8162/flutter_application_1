const express = require('express');
const ProfessionalController = require('../controllers/professionalController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// Buscar profissionais
router.get('/search', ProfessionalController.searchProfessionals);

// Perfil profissional (apenas para profissionais)
router.get('/profile', authenticate, authorize(['profissional']), ProfessionalController.getProfile);
router.put('/profile', authenticate, authorize(['profissional']), ProfessionalController.updateProfile);

// Disponibilidade
router.put('/availability', authenticate, authorize(['profissional']), ProfessionalController.updateAvailability);

// Documentação profissional
router.post('/documents', authenticate, authorize(['profissional']), ProfessionalController.uploadProfessionalDocuments);
router.get('/documents/status', authenticate, authorize(['profissional']), ProfessionalController.getDocumentStatus);

// Avaliações
router.get('/:id/reviews', ProfessionalController.getReviews);

router.post('/location', authenticate, async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    const userId = req.user.userId;

    // Atualizar a localização do profissional no banco de dados
    // ... lógica para atualizar ...

    res.json({ success: true });
  } catch (error) {
    console.error('Error updating location:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
