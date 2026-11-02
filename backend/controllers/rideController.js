const Ride = require('../models/Ride');
const User = require('../models/User');
const Professional = require('../models/Professional');
const Client = require('../models/Client');
const Review = require('../models/Review');
const Coupon = require('../models/Coupon');
const { broadcastToRide } = require('../utils/realtime');
const { isConfigured: stripeConfigured } = require('../config/stripe');
const pushService = require('../utils/pushService');

class RideController {
  // Cliente solicita uma corrida/atendimento
  async createRide(req, res) {
    try {
      const { userId } = req.user;
      const { pickup_location, destination, distance, estimated_price, coupon_code } = req.body;

      if (!pickup_location || !distance || !estimated_price) {
        return res.status(400).json({
          success: false,
          message: 'pickup_location, distance e estimated_price são obrigatórios',
        });
      }

      const client = await Client.findByUserId(userId);
      if (!client) {
        return res.status(403).json({ success: false, message: 'Apenas clientes podem solicitar corridas' });
      }

      const existingActive = await Ride.findActiveForUser(userId, 'cliente');
      if (existingActive) {
        return res.status(400).json({
          success: false,
          message: 'Você já possui uma solicitação em andamento',
          data: existingActive,
        });
      }

      // Cupom de desconto (opcional): valida de novo aqui (mesmo que o app
      // já tenha chamado /coupons/validate antes) porque tempo pode ter
      // passado entre a prévia e a confirmação - alguém pode ter esgotado
      // o cupom nesse meio tempo.
      let coupon = null;
      let discountApplied = 0;
      let finalEstimatedPrice = Number(estimated_price);

      if (coupon_code) {
        coupon = await Coupon.findByCode(coupon_code);
        if (!coupon) {
          return res.status(404).json({ success: false, message: 'Cupom não encontrado' });
        }
        const check = await coupon.validateFor(userId, finalEstimatedPrice);
        if (!check.valid) {
          return res.status(400).json({ success: false, message: check.message });
        }
        discountApplied = coupon.calculateDiscount(finalEstimatedPrice);
        finalEstimatedPrice -= discountApplied;
      }

      const rideId = await Ride.create({
        client_id: userId,
        pickup_location,
        destination,
        distance,
        estimated_price: finalEstimatedPrice,
        coupon_id: coupon?.id || null,
        discount_applied: discountApplied,
      });

      if (coupon) {
        await coupon.redeem({ clientId: userId, rideId, discountApplied });
      }

      const ride = await Ride.findById(rideId);

      // Avisa profissionais compatíveis e disponíveis (best-effort - a
      // descoberta "de verdade" continua sendo GET /rides/pending, que o
      // app já consulta periodicamente; o push só torna isso imediato em
      // vez de esperar o próximo ciclo de polling).
      const tipoServico = pickup_location?.tipo_servico;
      Professional.findAvailableWithLocation(tipoServico)
        .then((professionals) => {
          const userIds = professionals.map((p) => p.user_id).filter((uid) => uid !== userId);
          if (userIds.length === 0) return;
          return pushService.sendToUsers(userIds, {
            title: 'Nova corrida disponível',
            body: pickup_location?.descricao || 'Um cliente precisa de ajuda perto de você',
            data: { type: 'new_ride', ride_id: rideId },
          });
        })
        .catch((e) => console.error('Push de nova corrida falhou:', e.message));

      res.status(201).json({
        success: true,
        message: 'Corrida solicitada com sucesso',
        data: ride,
      });
    } catch (error) {
      console.error('Create ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Profissional busca corridas pendentes
  async getPendingRides(req, res) {
    try {
      const rides = await Ride.findPending();

      const enrichedRides = await Promise.all(
        rides.map(async (ride) => {
          const client = await User.findById(ride.client_id);
          return {
            id: ride.id,
            client_id: ride.client_id,
            client_name: client ? client.name : 'Cliente',
            client_phone: client ? client.phone : null,
            pickup_location: ride.pickup_location,
            destination: ride.destination,
            distance: ride.distance,
            estimated_price: ride.estimated_price,
            status: ride.status,
            created_at: ride.created_at,
          };
        })
      );

      res.json({ success: true, data: enrichedRides });
    } catch (error) {
      console.error('Get pending rides error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Buscar corrida por id (cliente ou motorista dono da corrida)
  async getRide(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }

      if (ride.client_id !== userId && ride.driver_id !== userId) {
        return res.status(403).json({ success: false, message: 'Acesso não autorizado a esta corrida' });
      }

      res.json({ success: true, data: ride });
    } catch (error) {
      console.error('Get ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Corrida ativa do usuário logado (cliente ou profissional)
  async getActiveRide(req, res) {
    try {
      const { userId, role } = req.user;
      const ride = await Ride.findActiveForUser(userId, role);
      res.json({ success: true, data: ride });
    } catch (error) {
      console.error('Get active ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Profissional aceita corrida
  async acceptRide(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;

      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(403).json({ success: false, message: 'Apenas profissionais podem aceitar corridas' });
      }
      if (!professional.documentacao_aprovada) {
        return res.status(403).json({
          success: false,
          message: 'Sua documentação ainda não foi aprovada',
        });
      }

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.status !== 'pending') {
        return res.status(400).json({ success: false, message: 'Corrida não está mais disponível' });
      }

      await ride.update({ status: 'accepted', driver_id: userId, accepted_at: new Date() });

      const driver = await User.findById(userId);
      broadcastToRide(id, {
        type: 'status',
        status: 'accepted',
        driver: driver ? { id: driver.id, name: driver.name, phone: driver.phone } : null,
      });

      pushService
        .sendToUser(ride.client_id, {
          title: 'Profissional a caminho',
          body: driver ? `${driver.name} aceitou sua solicitação` : 'Um profissional aceitou sua solicitação',
          data: { type: 'ride_accepted', ride_id: id },
        })
        .catch((e) => console.error('Push de corrida aceita falhou:', e.message));

      res.json({ success: true, message: 'Corrida aceita com sucesso', data: ride });
    } catch (error) {
      console.error('Accept ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Profissional inicia o atendimento (chegou / em andamento)
  async startRide(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.driver_id !== userId) {
        return res.status(403).json({ success: false, message: 'Você não é o profissional desta corrida' });
      }
      if (ride.status !== 'accepted') {
        return res.status(400).json({ success: false, message: 'Corrida precisa estar aceita para iniciar' });
      }

      await ride.update({ status: 'in_progress', started_at: new Date() });

      broadcastToRide(id, { type: 'status', status: 'in_progress' });

      pushService
        .sendToUser(ride.client_id, {
          title: 'Atendimento iniciado',
          body: 'O profissional iniciou o atendimento',
          data: { type: 'ride_in_progress', ride_id: id },
        })
        .catch((e) => console.error('Push de corrida iniciada falhou:', e.message));

      res.json({ success: true, message: 'Corrida iniciada', data: ride });
    } catch (error) {
      console.error('Start ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Completar corrida
  async completeRide(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;
      const { final_price } = req.body;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.driver_id !== userId) {
        return res.status(403).json({ success: false, message: 'Você não é o profissional desta corrida' });
      }

      await ride.update({
        status: 'completed',
        completed_at: new Date(),
        final_price: final_price || ride.estimated_price,
      });

      broadcastToRide(id, { type: 'status', status: 'completed', final_price: ride.final_price });

      pushService
        .sendToUser(ride.client_id, {
          title: 'Corrida finalizada',
          body: `Atendimento concluído - R$ ${Number(ride.final_price).toFixed(2)}`,
          data: { type: 'ride_completed', ride_id: id },
        })
        .catch((e) => console.error('Push de corrida concluída falhou:', e.message));

      // MUDANÇA DE MODELO DE NEGÓCIO: o cliente não paga mais pela corrida
      // dentro do app - o valor é definido e cobrado pelo próprio
      // profissional diretamente com o cliente (dinheiro, PIX pessoal,
      // maquininha etc.), fora da plataforma. Quem paga a plataforma agora
      // é o profissional, via mensalidade (ver subscriptionController.js).
      // A cobrança automática que existia aqui (debitar o cartão do cliente
      // ao concluir a corrida) foi desativada.

      res.json({ success: true, message: 'Corrida finalizada com sucesso', data: ride });
    } catch (error) {
      console.error('Complete ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Cancelar corrida (cliente ou profissional envolvido)
  async cancelRide(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.client_id !== userId && ride.driver_id !== userId) {
        return res.status(403).json({ success: false, message: 'Acesso não autorizado a esta corrida' });
      }
      if (['completed', 'cancelled'].includes(ride.status)) {
        return res.status(400).json({ success: false, message: 'Corrida já finalizada' });
      }

      await ride.update({ status: 'cancelled', cancelled_at: new Date() });

      broadcastToRide(id, { type: 'status', status: 'cancelled' });

      // Notifica quem NÃO cancelou (o outro lado da corrida) - se foi o
      // cliente que cancelou e já havia um profissional, avisa o
      // profissional; se foi o profissional, avisa o cliente.
      const otherPartyId = ride.client_id === userId ? ride.driver_id : ride.client_id;
      if (otherPartyId) {
        pushService
          .sendToUser(otherPartyId, {
            title: 'Corrida cancelada',
            body: 'A corrida foi cancelada.',
            data: { type: 'ride_cancelled', ride_id: id },
          })
          .catch((e) => console.error('Push de corrida cancelada falhou:', e.message));
      }

      // Rede de segurança: no fluxo normal uma corrida só é cobrada depois
      // de concluída (RideController.completeRide), então cancelar não
      // deveria nunca encontrar payment_status === 'paid'. Mas se isso
      // acontecer por qualquer motivo (corrida cobrada manualmente e só
      // depois cancelada, etc.), o cliente não deve ficar pagando por um
      // serviço cancelado - reembolsa automaticamente, best-effort, sem
      // bloquear a resposta do cancelamento.
      if (ride.payment_status === 'paid' && (ride.payment_method === 'wallet' || stripeConfigured())) {
        // eslint-disable-next-line global-require
        const PaymentController = require('./paymentController');
        PaymentController.refundRideInternal(id, 'Corrida cancelada após cobrança').catch((e) =>
          console.error('Reembolso automático por cancelamento falhou:', e.message)
        );
      }

      res.json({ success: true, message: 'Corrida cancelada', data: ride });
    } catch (error) {
      console.error('Cancel ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Cliente avalia o profissional após a corrida
  async reviewRide(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;
      const { nota, comentario } = req.body;

      if (!nota || nota < 1 || nota > 5) {
        return res.status(400).json({ success: false, message: 'Nota deve ser entre 1 e 5' });
      }

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (ride.client_id !== userId) {
        return res.status(403).json({ success: false, message: 'Apenas o cliente da corrida pode avaliar' });
      }
      if (ride.status !== 'completed') {
        return res.status(400).json({ success: false, message: 'Só é possível avaliar corridas concluídas' });
      }

      const existing = await Review.findByRideId(id);
      if (existing) {
        return res.status(400).json({ success: false, message: 'Esta corrida já foi avaliada' });
      }

      const client = await Client.findByUserId(userId);
      const professional = await Professional.findByUserId(ride.driver_id);

      await Review.create({
        ride_id: id,
        client_id: client.id,
        professional_id: professional.id,
        nota,
        comentario,
      });

      await professional.recalculateRating();

      res.status(201).json({ success: true, message: 'Avaliação registrada com sucesso' });
    } catch (error) {
      console.error('Review ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Histórico de corridas do profissional
  async getProfessionalRides(req, res) {
    try {
      const { userId } = req.user;
      const { page = 1, limit = 10 } = req.query;

      const rides = await Ride.findByDriverId(userId, page, limit);

      res.json({ success: true, data: rides });
    } catch (error) {
      console.error('Get professional rides error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Histórico de corridas do cliente
  async getClientRides(req, res) {
    try {
      const { userId } = req.user;
      const { page = 1, limit = 10 } = req.query;

      const rides = await Ride.findByClientId(userId, page, limit);

      res.json({ success: true, data: rides });
    } catch (error) {
      console.error('Get client rides error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }
}

module.exports = new RideController();
