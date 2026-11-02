const { query } = require('../config/database');
const crypto = require('crypto');

// Refresh tokens: reaproveita a tabela `sessions`, que já existia no schema
// original com o comentário "reservado para futura denylist/refresh de
// tokens" mas nunca era usada por nenhum controller. Cada linha é um
// refresh token de 30 dias, armazenado como hash (nunca em texto puro).
const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 dias

class Session {
  constructor(row) {
    this.id = row.id;
    this.user_id = row.user_id;
    this.token_hash = row.token_hash;
    this.revoked = row.revoked;
    this.device_info = row.device_info;
    this.expires_at = row.expires_at;
    this.created_at = row.created_at;
    this.last_used_at = row.last_used_at;
  }

  static hash(rawToken) {
    return crypto.createHash('sha256').update(rawToken).digest('hex');
  }

  // Gera um refresh token opaco (não é um JWT) + já retorna o hash pronto
  // para persistir. O valor bruto só existe em memória neste request e no
  // corpo da resposta HTTP - nunca é salvo no banco.
  static generate() {
    const raw = crypto.randomBytes(48).toString('base64url');
    return { raw, hash: Session.hash(raw) };
  }

  static async create({ user_id, tokenHash, device_info }) {
    const expires_at = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);
    const result = await query(
      `INSERT INTO sessions (user_id, token_hash, device_info, expires_at)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [user_id, tokenHash, device_info || null, expires_at]
    );
    return new Session(result.rows[0]);
  }

  static async findValidByRawToken(rawToken) {
    const tokenHash = Session.hash(rawToken);
    const result = await query(
      `SELECT * FROM sessions
       WHERE token_hash = $1 AND revoked = FALSE AND expires_at > NOW()`,
      [tokenHash]
    );
    return result.rows[0] ? new Session(result.rows[0]) : null;
  }

  async touch() {
    await query('UPDATE sessions SET last_used_at = NOW() WHERE id = $1', [this.id]);
  }

  async revoke() {
    await query('UPDATE sessions SET revoked = TRUE WHERE id = $1', [this.id]);
    this.revoked = true;
  }

  static async revokeAllForUser(user_id) {
    await query('UPDATE sessions SET revoked = TRUE WHERE user_id = $1 AND revoked = FALSE', [user_id]);
  }
}

module.exports = Session;
