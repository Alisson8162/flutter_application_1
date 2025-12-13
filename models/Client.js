// models/Client.js (atualizado)
const { mysql, postgres } = require('../config/database');

class Client {
  constructor(clientData) {
    this.id = clientData.id;
    this.user_id = clientData.user_id;
    this.tipo_veiculo_preferido = clientData.tipo_veiculo_preferido;
    this.foto_documento_frente = clientData.foto_documento_frente;
    this.foto_documento_verso = clientData.foto_documento_verso;
    this.foto_selfie = clientData.foto_selfie;
    this.endereco_id = clientData.endereco_id;
    this.numero_cartao = clientData.numero_cartao;
    this.nome_cartao = clientData.nome_cartao;
    this.validade_cartao = clientData.validade_cartao;
    this.cvv_cartao = clientData.cvv_cartao;
    this.created_at = clientData.created_at;
    this.updated_at = clientData.updated_at;
  }

  // Criar perfil de cliente
  static async create(clientData, dbType = 'mysql') {
    const { 
      user_id, 
      tipo_veiculo_preferido, 
      foto_documento_frente, 
      foto_documento_verso, 
      foto_selfie, 
      endereco_id,
      numero_cartao,
      nome_cartao,
      validade_cartao,
      cvv_cartao
    } = clientData;

    if (dbType === 'mysql') {
      const [result] = await mysql.execute(
        `INSERT INTO clients (user_id, tipo_veiculo_preferido, foto_documento_frente, 
         foto_documento_verso, foto_selfie, endereco_id, numero_cartao, nome_cartao, 
         validade_cartao, cvv_cartao) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [user_id, tipo_veiculo_preferido, foto_documento_frente, foto_documento_verso, 
         foto_selfie, endereco_id, numero_cartao, nome_cartao, validade_cartao, cvv_cartao]
      );
      return result.insertId;
    } else {
      const result = await postgres.query(
        `INSERT INTO clients (user_id, tipo_veiculo_preferido, foto_documento_frente, 
         foto_documento_verso, foto_selfie, endereco_id, numero_cartao, nome_cartao, 
         validade_cartao, cvv_cartao) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id`,
        [user_id, tipo_veiculo_preferido, foto_documento_frente, foto_documento_verso, 
         foto_selfie, endereco_id, numero_cartao, nome_cartao, validade_cartao, cvv_cartao]
      );
      return result.rows[0].id;
    }
  }

  // Buscar por user_id
  static async findByUserId(userId, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM clients WHERE user_id = ?',
        [userId]
      );
      return rows[0] ? new Client(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM clients WHERE user_id = $1',
        [userId]
      );
      return result.rows[0] ? new Client(result.rows[0]) : null;
    }
  }

  // Atualizar cliente
  async update(updates, dbType = 'mysql') {
    const fields = [];
    const values = [];
    
    Object.keys(updates).forEach(key => {
      if (updates[key] !== undefined) {
        fields.push(`${key} = ?`);
        values.push(updates[key]);
      }
    });

    if (fields.length === 0) return;

    values.push(this.id);

    if (dbType === 'mysql') {
      await mysql.execute(
        `UPDATE clients SET ${fields.join(', ')} WHERE id = ?`,
        values
      );
    } else {
      await postgres.query(
        `UPDATE clients SET ${fields.join(', ').replace(/\?/g, (_, index) => `$${index + 1}`)} WHERE id = $${values.length}`,
        values
      );
    }
  }
}

module.exports = Client;