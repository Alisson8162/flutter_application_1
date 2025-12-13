const { mysql, postgres } = require('../config/database');

class Document {
  constructor(documentData) {
    this.id = documentData.id;
    this.user_id = documentData.user_id;
    this.tipo = documentData.tipo;
    this.url = documentData.url;
    this.public_id = documentData.public_id;
    this.aprovado = documentData.aprovado;
    this.created_at = documentData.created_at;
  }

  // Criar documento
  static async create(documentData, dbType = 'mysql') {
    const { user_id, tipo, url, public_id, descricao } = documentData;

    if (dbType === 'mysql') {
      const [result] = await mysql.execute(
        `INSERT INTO documents (user_id, tipo, url, public_id, descricao) 
         VALUES (?, ?, ?, ?, ?)`,
        [user_id, tipo, url, public_id, descricao]
      );
      return result.insertId;
    } else {
      const result = await postgres.query(
        `INSERT INTO documents (user_id, tipo, url, public_id, descricao) 
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [user_id, tipo, url, public_id, descricao]
      );
      return result.rows[0].id;
    }
  }

  // Buscar por user_id
  static async findByUserId(userId, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM documents WHERE user_id = ? ORDER BY created_at DESC',
        [userId]
      );
      return rows.map(row => new Document(row));
    } else {
      const result = await postgres.query(
        'SELECT * FROM documents WHERE user_id = $1 ORDER BY created_at DESC',
        [userId]
      );
      return result.rows.map(row => new Document(row));
    }
  }

  // Buscar por tipo
  static async findByType(userId, tipo, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM documents WHERE user_id = ? AND tipo = ? ORDER BY created_at DESC LIMIT 1',
        [userId, tipo]
      );
      return rows[0] ? new Document(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM documents WHERE user_id = $1 AND tipo = $2 ORDER BY created_at DESC LIMIT 1',
        [userId, tipo]
      );
      return result.rows[0] ? new Document(result.rows[0]) : null;
    }
  }
}

module.exports = Document;