const Ride = require('../models/Ride');
const User = require('../models/User');
const RideMessage = require('../models/RideMessage');
const { broadcastToRide } = require('../utils/realtime');
const pushService = require('../utils/pushService');

// Status em que faz sentido conversar: depois que um profissional aceitou
// (senão não há com quem falar) e antes/durante o atendimento. Corridas
// finalizadas ou canceladas ficam com o histórico disponível para leitura,
// mas não aceitam novas mensagens.
const CHATTABLE_STATUSES = ['accepted', 'in_progress'];

function isParticipant(ride, userId) {
  return ride.client_id === userId || ride.driver_id === userId;
}

class MessageController {
  async sendMessage(req, res) {
    try {
      const { id } = req.params;
      const { content } = req.body;
      const { userId } = req.user;

      if (!content || !content.trim()) {
        return res.status(400).json({ success: false, message: 'Mensagem vazia' });
      }
      if (content.length > 2000) {
        return res.status(400).json({ success: false, message: 'Mensagem muito longa (máx. 2000 caracteres)' });
      }

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (!isParticipant(ride, userId)) {
        return res.status(403).json({ success: false, message: 'Você não faz parte desta corrida' });
      }
      if (!CHATTABLE_STATUSES.includes(ride.status)) {
        return res.status(400).json({
          success: false,
          message: 'O chat só está disponível enquanto a corrida está em andamento',
        });
      }

      const message = await RideMessage.create({ ride_id: id, sender_id: userId, content: content.trim() });
      const sender = await User.findById(userId);

      const payload = {
        type: 'message',
        id: message.id,
        ride_id: id,
        sender_id: userId,
        sender_name: sender?.name || 'Usuário',
        content: message.content,
        created_at: message.created_at,
      };

      broadcastToRide(id, payload);

      // Push só é útil quando o app está em segundo plano (em primeiro
      // plano a mensagem já chega na hora via WebSocket) - best-effort.
      const recipientId = ride.client_id === userId ? ride.driver_id : ride.client_id;
      if (recipientId) {
        pushService
          .sendToUser(recipientId, {
            title: sender?.name || 'Nova mensagem',
            body: message.content,
            data: { type: 'chat_message', ride_id: id },
          })
          .catch((e) => console.error('Push de mensagem falhou:', e.message));
      }

      res.status(201).json({ success: true, data: payload });
    } catch (error) {
      console.error('Send message error:', error);
      res.status(500).json({ success: false, message: 'Erro ao enviar mensagem' });
    }
  }

  async getMessages(req, res) {
    try {
      const { id } = req.params;
      const { userId } = req.user;

      const ride = await Ride.findById(id);
      if (!ride) {
        return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
      }
      if (!isParticipant(ride, userId)) {
        return res.status(403).json({ success: false, message: 'Você não faz parte desta corrida' });
      }

      const messages = await RideMessage.findByRide(id, { limit: req.query.limit });
      res.json({ success: true, data: messages });
    } catch (error) {
      console.error('Get messages error:', error);
      res.status(500).json({ success: false, message: 'Erro ao buscar mensagens' });
    }
  }
}

module.exports = new MessageController();
