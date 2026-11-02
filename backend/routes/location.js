const express = require('express');
const LocationController = require('../controllers/locationController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// Atualizar localização do profissional
router.post('/update', authenticate, authorize(['profissional']), LocationController.updateLocation);

// Buscar profissionais próximos
router.get('/nearby', authenticate, LocationController.getNearbyProfessionals);

module.exports = router;
