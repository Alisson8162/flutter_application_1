const Ride = require('../models/Ride');
const Professional = require('../models/Professional');
const User = require('../models/User');

class RideController {
  // Criar nova corrida
  async createRide(req, res) {
    try {
      const { client_id, pickup_location, destination, distance, estimated_price } = req.body;

      const rideId = await Ride.create({
        client_id,
        pickup_location,
        destination,
        distance,
        estimated_price
      });

      res.status(201).json({
        success: true,
        message: 'Corrida solicitada com sucesso',
        data: { id: rideId }
      });
    } catch (error) {
      console.error('Create ride error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Buscar corridas pendentes
  async getPendingRides(req, res) {
    try {
      const rides = await Ride.findPending();

      // Enriquecer dados com informações do cliente
      const enrichedRides = await Promise.all(
        rides.map(async (ride) => {
          const client = await User.findById(ride.client_id);
          return {
            id: ride.id,
            client_id: ride.client_id,
            client_name: client ? client.name : 'Cliente',
            pickup_location: ride.pickup_location,
            destination: ride.destination,
            distance: ride.distance,
            estimated_price: ride.estimated_price,
            status: ride.status,
            created_at: ride.created_at
          };
        })
      );

      res.json({
        success: true,
        data: enrichedRides
      });
    } catch (error) {
      console.error('Get pending rides error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Aceitar corrida
  async acceptRide(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user; // ID do profissional

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({
          success: false,
          message: 'Corrida não encontrada'
        });
      }

      if (ride.status !== 'pending') {
        return res.status(400).json({
          success: false,
          message: 'Corrida não está mais disponível'
        });
      }

      // Atualizar corrida
      await ride.update({
        status: 'accepted',
        driver_id: userId,
        accepted_at: new Date()
      });

      res.json({
        success: true,
        message: 'Corrida aceita com sucesso'
      });
    } catch (error) {
      console.error('Accept ride error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Completar corrida
  async completeRide(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({
          success: false,
          message: 'Corrida não encontrada'
        });
      }

      if (ride.driver_id !== userId) {
        return res.status(403).json({
          success: false,
          message: 'Você não é o motorista desta corrida'
        });
      }

      await ride.update({
        status: 'completed',
        completed_at: new Date()
      });

      res.json({
        success: true,
        message: 'Corrida finalizada com sucesso'
      });
    } catch (error) {
      console.error('Complete ride error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Buscar histórico de corridas do profissional
  async getProfessionalRides(req, res) {
    try {
      const { userId } = req.user;
      const { page = 1, limit = 10 } = req.query;

      const rides = await Ride.findByDriverId(userId, page, limit);

      res.json({
        success: true,
        data: rides
      });
    } catch (error) {
      console.error('Get professional rides error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }
}

module.exports = new RideController();