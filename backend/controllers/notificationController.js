const DeviceToken = require('../models/DeviceToken');

class NotificationController {
  // Chamado pelo app assim que obtém/renova o token FCM do dispositivo
  // (login, ou refresh automático do token pela própria FCM).
  async registerToken(req, res) {
    try {
      const { token, platform } = req.body;
      if (!token) {
        return res.status(400).json({ success: false, message: 'token é obrigatório' });
      }

      await DeviceToken.register(req.user.userId, token, platform);
      res.json({ success: true });
    } catch (error) {
      console.error('Register push token error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Chamado no logout - evita continuar mandando push pra um dispositivo
  // que já não está mais "logado" com esse usuário.
  async unregisterToken(req, res) {
    try {
      const { token } = req.body;
      if (token) await DeviceToken.unregister(token);
      res.json({ success: true });
    } catch (error) {
      console.error('Unregister push token error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }
}

module.exports = new NotificationController();
