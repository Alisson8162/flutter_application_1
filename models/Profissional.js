const { mysql, postgres } = require('../config/database');

class Professional {
  constructor(professionalData) {
    this.id = professionalData.id;
    this.user_id = professionalData.user_id;
    this.especialidade = professionalData.especialidade;
    this.tipo_veiculo_atendido = professionalData.tipo_veiculo_atendido;
    this.avaliacao_media = professionalData.avaliacao_media;
    this.total_avaliacoes = professionalData.total_avaliacoes;
    this.disponivel = professionalData.disponivel;
    this.documentacao_aprovada = professionalData.documentacao_aprovada;
  }

  // Criar perfil profissional
  static async create(professionalData, dbType = 'mysql') {
    const { user_id, especialidade, tipo_veiculo_atendido } = professionalData;

    if (dbType === 'mysql') {
      const [result] = await mysql.execute(
        `INSERT INTO professionals (user_id, especialidade, tipo_veiculo_atendido) 
         VALUES (?, ?, ?)`,
        [user_id, especialidade, tipo_veiculo_atendido]
      );
      return result.insertId;
    } else {
      const result = await postgres.query(
        `INSERT INTO professionals (user_id, especialidade, tipo_veiculo_atendido) 
         VALUES ($1, $2, $3) RETURNING id`,
        [user_id, especialidade, tipo_veiculo_atendido]
      );
      return result.rows[0].id;
    }
  }

  // Buscar por user_id
  static async findByUserId(userId, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM professionals WHERE user_id = ?',
        [userId]
      );
      return rows[0] ? new Professional(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM professionals WHERE user_id = $1',
        [userId]
      );
      return result.rows[0] ? new Professional(result.rows[0]) : null;
    }
  }

  // Buscar profissionais por especialidade e localização
  static async findBySpecialtyAndLocation(especialidade, estado, cidade, dbType = 'mysql') {
    let query = `
      SELECT p.*, u.name, u.phone, u.foto_url, a.latitude, a.longitude
      FROM professionals p
      JOIN users u ON p.user_id = u.id
      LEFT JOIN addresses a ON u.id = a.user_id
      WHERE p.especialidade = ? AND p.disponivel = TRUE AND p.documentacao_aprovada = TRUE
    `;

    const params = [especialidade];

    if (estado && cidade) {
      query += ' AND a.estado = ? AND a.cidade = ?';
      params.push(estado, cidade);
    }

    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(query, params);
      return rows;
    } else {
      const result = await postgres.query(
        query.replace(/\?/g, (_, index) => `$${index + 1}`),
        params
      );
      return result.rows;
    }
  }
}

module.exports = Professional;