const express = require('express');
const RideController = require('../controllers/rideController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// Cliente solicita corrida
router.post('/', authenticate, authorize(['cliente']), RideController.createRide);

// Profissional busca corridas pendentes
router.get('/pending', authenticate, authorize(['profissional']), RideController.getPendingRides);

// Profissional aceita corrida
router.post('/:id/accept', authenticate, authorize(['profissional']), RideController.acceptRide);

// Profissional completa corrida
router.post('/:id/complete', authenticate, authorize(['profissional']), RideController.completeRide);

// Histórico de corridas do profissional
router.get('/professional/history', authenticate, authorize(['profissional']), RideController.getProfessionalRides);

module.exports = router;