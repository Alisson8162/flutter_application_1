const { query } = require('../config/database');

class DeviceToken {
  // Um token pertence a um único dispositivo/instalação; se o mesmo token
  // aparecer de novo (reabrir o app) só atualizamos o dono/plataforma em vez
  // de duplicar a linha.
  static async register(userId, token, platform) {
    await query(
      `INSERT INTO device_tokens (user_id, token, platform, updated_at)
       VALUES ($1, $2, $3, NOW())
       ON CONFLICT (token) DO UPDATE SET user_id = $1, platform = $3, updated_at = NOW()`,
      [userId, token, platform || null]
    );
  }

  static async unregister(token) {
    await query('DELETE FROM device_tokens WHERE token = $1', [token]);
  }

  static async findTokensForUser(userId) {
    const result = await query('SELECT token FROM device_tokens WHERE user_id = $1', [userId]);
    return result.rows.map((r) => r.token);
  }

  // Para notificar vários usuários de uma vez (ex.: "nova corrida
  // disponível" para todos os profissionais compatíveis online) sem uma
  // query por usuário.
  static async findTokensForUsers(userIds) {
    if (!userIds || userIds.length === 0) return [];
    const result = await query('SELECT token FROM device_tokens WHERE user_id = ANY($1)', [userIds]);
    return result.rows.map((r) => r.token);
  }

  // Tokens que a FCM reportou como inválidos/desinstalados - removidos em
  // lote após uma tentativa de envio.
  static async removeTokens(tokens) {
    if (!tokens || tokens.length === 0) return;
    await query('DELETE FROM device_tokens WHERE token = ANY($1)', [tokens]);
  }
}

module.exports = DeviceToken;
