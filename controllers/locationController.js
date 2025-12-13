const Professional = require('../models/Professional');
const User = require('../models/User');

class LocationController {
  // Atualizar localização do profissional
  async updateLocation(req, res) {
    try {
      const { userId } = req.user;
      const { latitude, longitude } = req.body;

      // Atualizar localização no perfil do profissional
      const professional = await Professional.findByUserId(userId);
      if (professional) {
        // Aqui você pode armazenar a localização em uma tabela separada
        // ou atualizar no perfil do profissional
        console.log(`Localização atualizada para profissional ${userId}: ${latitude}, ${longitude}`);
      }

      res.json({
        success: true,
        message: 'Localização atualizada com sucesso'
      });
    } catch (error) {
      console.error('Update location error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Buscar profissionais próximos
  async getNearbyProfessionals(req, res) {
    try {
      const { latitude, longitude, radius = 10, especialidade } = req.query;

      // Em uma implementação real, você usaria geoqueries
      // Por enquanto, retornaremos uma lista simulada
      const professionals = await Professional.findBySpecialtyAndLocation(
        especialidade,
        null, // estado
        null  // cidade
      );

      // Filtrar por proximidade (simulação)
      const nearbyProfessionals = professionals.filter(prof => {
        if (!prof.latitude || !prof.longitude) return false;
        
        const distance = calculateDistance(
          parseFloat(latitude),
          parseFloat(longitude),
          parseFloat(prof.latitude),
          parseFloat(prof.longitude)
        );
        
        return distance <= radius;
      });

      res.json({
        success: true,
        data: nearbyProfessionals,
        total: nearbyProfessionals.length
      });
    } catch (error) {
      console.error('Get nearby professionals error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }
}

// Função auxiliar para calcular distância
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Raio da Terra em km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  const distance = R * c;
  return distance;
}

module.exports = new LocationController();