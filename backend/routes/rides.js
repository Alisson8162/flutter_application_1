const express = require('express');
const RideController = require('../controllers/rideController');
const MessageController = require('../controllers/messageController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// Cliente solicita corrida
router.post('/', authenticate, authorize(['cliente']), RideController.createRide);

// Corrida ativa do usuário logado
router.get('/active', authenticate, RideController.getActiveRide);

// Profissional busca corridas pendentes
router.get('/pending', authenticate, authorize(['profissional']), RideController.getPendingRides);

// Histórico
router.get('/professional/history', authenticate, authorize(['profissional']), RideController.getProfessionalRides);
router.get('/client/history', authenticate, authorize(['cliente']), RideController.getClientRides);

// Detalhe de uma corrida
router.get('/:id', authenticate, RideController.getRide);

// Ações sobre uma corrida
router.post('/:id/accept', authenticate, authorize(['profissional']), RideController.acceptRide);
router.post('/:id/start', authenticate, authorize(['profissional']), RideController.startRide);
router.post('/:id/complete', authenticate, authorize(['profissional']), RideController.completeRide);
router.post('/:id/cancel', authenticate, RideController.cancelRide);
router.post('/:id/review', authenticate, authorize(['cliente']), RideController.reviewRide);

// Chat da corrida (cliente <-> profissional) - entrega em tempo real pelo
// mesmo WebSocket já usado para status/localização (ws/trip/:rideId).
router.get('/:id/messages', authenticate, MessageController.getMessages);
router.post('/:id/messages', authenticate, MessageController.sendMessage);

module.exports = router;
