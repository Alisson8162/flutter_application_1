const { mysql, postgres } = require('../config/database');

class Verification {
  constructor(verificationData) {
    this.id = verificationData.id;
    this.user_id = verificationData.user_id;
    this.identifier = verificationData.identifier;
    this.code = verificationData.code;
    this.type = verificationData.type;
    this.expires_at = verificationData.expires_at;
    this.used = verificationData.used;
    this.created_at = verificationData.created_at;
  }

  // Criar código de verificação
  static async create(verificationData, dbType = 'mysql') {
    const { user_id, identifier, code, type, expiresAt } = verificationData;

    if (dbType === 'mysql') {
      const [result] = await mysql.execute(
        `INSERT INTO verifications (user_id, identifier, code, type, expires_at) 
         VALUES (?, ?, ?, ?, ?)`,
        [user_id, identifier, code, type, expiresAt]
      );
      return result.insertId;
    } else {
      const result = await postgres.query(
        `INSERT INTO verifications (user_id, identifier, code, type, expires_at) 
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [user_id, identifier, code, type, expiresAt]
      );
      return result.rows[0].id;
    }
  }

  // Buscar código válido
  static async findValidCode(identifier, code, dbType = 'mysql') {
    const now = new Date();

    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM verifications WHERE identifier = ? AND code = ? AND used = FALSE AND expires_at > ?',
        [identifier, code, now]
      );
      return rows[0] ? new Verification(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM verifications WHERE identifier = $1 AND code = $2 AND used = FALSE AND expires_at > $3',
        [identifier, code, now]
      );
      return result.rows[0] ? new Verification(result.rows[0]) : null;
    }
  }

  // Marcar como usado
  async markAsUsed(dbType = 'mysql') {
    if (dbType === 'mysql') {
      await mysql.execute(
        'UPDATE verifications SET used = TRUE WHERE id = ?',
        [this.id]
      );
    } else {
      await postgres.query(
        'UPDATE verifications SET used = TRUE WHERE id = $1',
        [this.id]
      );
    }
  }

  // Limpar códigos expirados
  static async cleanupExpired(dbType = 'mysql') {
    const now = new Date();
    
    if (dbType === 'mysql') {
      await mysql.execute(
        'DELETE FROM verifications WHERE expires_at < ?',
        [now]
      );
    } else {
      await postgres.query(
        'DELETE FROM verifications WHERE expires_at < $1',
        [now]
      );
    }
  }
}

module.exports = Verification;