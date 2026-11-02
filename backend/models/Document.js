const { query } = require('../config/database');

class Document {
  constructor(data) {
    this.id = data.id;
    this.user_id = data.user_id;
    this.tipo = data.tipo;
    this.url = data.url;
    this.public_id = data.public_id;
    this.aprovado = data.aprovado;
    this.rejeitado = data.rejeitado;
    this.motivo_rejeicao = data.motivo_rejeicao;
    this.created_at = data.created_at;
  }

  static async create(documentData) {
    const { user_id, tipo, url, public_id } = documentData;

    const result = await query(
      `INSERT INTO documents (user_id, tipo, url, public_id)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [user_id, tipo, url, public_id || null]
    );
    return result.rows[0].id;
  }

  static async findByUserId(userId) {
    const result = await query(
      'SELECT * FROM documents WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );
    return result.rows.map((row) => new Document(row));
  }

  static async findByType(userId, tipo) {
    const result = await query(
      'SELECT * FROM documents WHERE user_id = $1 AND tipo = $2 ORDER BY created_at DESC LIMIT 1',
      [userId, tipo]
    );
    return result.rows[0] ? new Document(result.rows[0]) : null;
  }

  static async approve(id) {
    const result = await query(
      'UPDATE documents SET aprovado = TRUE, rejeitado = FALSE, motivo_rejeicao = NULL WHERE id = $1 RETURNING *',
      [id]
    );
    return result.rows[0] ? new Document(result.rows[0]) : null;
  }

  static async reject(id, motivo) {
    const result = await query(
      'UPDATE documents SET aprovado = FALSE, rejeitado = TRUE, motivo_rejeicao = $2 WHERE id = $1 RETURNING *',
      [id, motivo || null]
    );
    return result.rows[0] ? new Document(result.rows[0]) : null;
  }

  static async findPendingCount() {
    const result = await query(
      'SELECT COUNT(*) AS total FROM documents WHERE aprovado = FALSE AND rejeitado = FALSE'
    );
    return Number(result.rows[0].total);
  }

  // Todos os documentos de um profissional foram aprovados?
  static async allApproved(userId) {
    const result = await query(
      `SELECT COUNT(*) FILTER (WHERE aprovado = FALSE) AS pendentes, COUNT(*) AS total
       FROM documents WHERE user_id = $1`,
      [userId]
    );
    const { pendentes, total } = result.rows[0];
    return Number(total) > 0 && Number(pendentes) === 0;
  }
}

module.exports = Document;
