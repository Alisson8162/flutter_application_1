const { mysql, postgres } = require('../config/database');

class Address {
  constructor(addressData) {
    this.id = addressData.id;
    this.user_id = addressData.user_id;
    this.estado = addressData.estado;
    this.cidade = addressData.cidade;
    this.endereco_completo = addressData.endereco_completo;
    this.bairro = addressData.bairro;
    this.cep = addressData.cep;
    this.latitude = addressData.latitude;
    this.longitude = addressData.longitude;
    this.created_at = addressData.created_at;
  }

  // Criar endereço
  static async create(addressData, dbType = 'mysql') {
    const { user_id, estado, cidade, endereco_completo, bairro, cep, latitude, longitude } = addressData;

    if (dbType === 'mysql') {
      const [result] = await mysql.execute(
        `INSERT INTO addresses (user_id, estado, cidade, endereco_completo, bairro, cep, latitude, longitude) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [user_id, estado, cidade, endereco_completo, bairro, cep, latitude, longitude]
      );
      return result.insertId;
    } else {
      const result = await postgres.query(
        `INSERT INTO addresses (user_id, estado, cidade, endereco_completo, bairro, cep, latitude, longitude) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
        [user_id, estado, cidade, endereco_completo, bairro, cep, latitude, longitude]
      );
      return result.rows[0].id;
    }
  }

  // Buscar por user_id
  static async findByUserId(userId, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM addresses WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
        [userId]
      );
      return rows[0] ? new Address(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM addresses WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1',
        [userId]
      );
      return result.rows[0] ? new Address(result.rows[0]) : null;
    }
  }

  // Buscar por ID
  static async findById(id, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM addresses WHERE id = ?',
        [id]
      );
      return rows[0] ? new Address(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM addresses WHERE id = $1',
        [id]
      );
      return result.rows[0] ? new Address(result.rows[0]) : null;
    }
  }

  // Atualizar endereço
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
        `UPDATE addresses SET ${fields.join(', ')} WHERE id = ?`,
        values
      );
    } else {
      await postgres.query(
        `UPDATE addresses SET ${fields.join(', ').replace(/\?/g, (_, index) => `$${index + 1}`)} WHERE id = $${values.length}`,
        values
      );
    }
  }
}

module.exports = Address;
