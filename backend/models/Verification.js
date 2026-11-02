const { query } = require('../config/database');

class Verification {
  constructor(data) {
    this.id = data.id;
    this.user_id = data.user_id;
    this.identifier = data.identifier;
    this.code = data.code;
    this.type = data.type;
    this.expires_at = data.expires_at;
    this.used = data.used;
    this.created_at = data.created_at;
  }

  static async create(verificationData) {
    const { user_id, identifier, code, type, expiresAt } = verificationData;

    const result = await query(
      `INSERT INTO verifications (user_id, identifier, code, type, expires_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [user_id || null, identifier, code, type, expiresAt]
    );
    return result.rows[0].id;
  }

  static async findValidCode(identifier, code) {
    const result = await query(
      `SELECT * FROM verifications
       WHERE identifier = $1 AND code = $2 AND used = FALSE AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [identifier, code]
    );
    return result.rows[0] ? new Verification(result.rows[0]) : null;
  }

  // Último código (para reenvio)
  static async findLatestByIdentifier(identifier) {
    const result = await query(
      `SELECT * FROM verifications WHERE identifier = $1 ORDER BY created_at DESC LIMIT 1`,
      [identifier]
    );
    return result.rows[0] ? new Verification(result.rows[0]) : null;
  }

  async markAsUsed() {
    await query('UPDATE verifications SET used = TRUE WHERE id = $1', [this.id]);
    this.used = true;
  }

  static async cleanupExpired() {
    await query('DELETE FROM verifications WHERE expires_at < NOW()');
  }
}

module.exports = Verification;
