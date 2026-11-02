const Professional = require('../models/Professional');
const Ride = require('../models/Ride');
const { calculateDistanceKm } = require('../utils/helpers');
const { broadcastToRide } = require('../utils/realtime');

class LocationController {
  // Atualizar localização do profissional.
  // BUG CORRIGIDO: a versão original apenas dava `console.log` e nunca
  // persistia a localização em lugar nenhum, então "profissionais próximos"
  // nunca teria dados reais para filtrar.
  async updateLocation(req, res) {
    try {
      const { userId } = req.user;
      const { latitude, longitude } = req.body;

      if (latitude === undefined || longitude === undefined) {
        return res.status(400).json({ success: false, message: 'latitude e longitude são obrigatórios' });
      }

      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Perfil profissional não encontrado' });
      }

      await professional.updateLocation(latitude, longitude);

      // Se o profissional está em uma corrida ativa, propaga a localização
      // em tempo real para o cliente conectado via WebSocket.
      const activeRide = await Ride.findActiveForUser(userId, 'profissional');
      if (activeRide) {
        broadcastToRide(activeRide.id, {
          type: 'location',
          id: userId,
          lat: latitude,
          lng: longitude,
        });
      }

      res.json({ success: true, message: 'Localização atualizada com sucesso' });
    } catch (error) {
      console.error('Update location error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Buscar profissionais disponíveis próximos de um ponto
  async getNearbyProfessionals(req, res) {
    try {
      const { latitude, longitude, radius = 10, especialidade } = req.query;

      if (latitude === undefined || longitude === undefined) {
        return res.status(400).json({ success: false, message: 'latitude e longitude são obrigatórios' });
      }

      const professionals = await Professional.findAvailableWithLocation(especialidade);

      const nearby = professionals
        .map((prof) => {
          const distance = calculateDistanceKm(
            parseFloat(latitude),
            parseFloat(longitude),
            parseFloat(prof.current_latitude),
            parseFloat(prof.current_longitude)
          );
          return { ...prof, distance_km: Number(distance.toFixed(2)) };
        })
        .filter((prof) => prof.distance_km <= Number(radius))
        .sort((a, b) => a.distance_km - b.distance_km);

      res.json({ success: true, data: nearby, total: nearby.length });
    } catch (error) {
      console.error('Get nearby professionals error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }
}

module.exports = new LocationController();
