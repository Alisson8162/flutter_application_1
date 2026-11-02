const { query } = require('../config/database');

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

  static async create(addressData) {
    const {
      user_id,
      estado,
      cidade,
      endereco_completo,
      bairro,
      cep,
      latitude,
      longitude,
    } = addressData;

    const result = await query(
      `INSERT INTO addresses (user_id, estado, cidade, endereco_completo, bairro, cep, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
      [user_id, estado, cidade, endereco_completo, bairro, cep, latitude || null, longitude || null]
    );
    return result.rows[0].id;
  }

  static async findByUserId(userId) {
    const result = await query(
      'SELECT * FROM addresses WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1',
      [userId]
    );
    return result.rows[0] ? new Address(result.rows[0]) : null;
  }

  static async findById(id) {
    const result = await query('SELECT * FROM addresses WHERE id = $1', [id]);
    return result.rows[0] ? new Address(result.rows[0]) : null;
  }

  async update(updates) {
    const allowedFields = [
      'estado',
      'cidade',
      'endereco_completo',
      'bairro',
      'cep',
      'latitude',
      'longitude',
    ];

    const fields = [];
    const values = [];
    let i = 1;

    Object.keys(updates).forEach((key) => {
      if (allowedFields.includes(key) && updates[key] !== undefined) {
        fields.push(`${key} = $${i}`);
        values.push(updates[key]);
        i += 1;
      }
    });

    if (fields.length === 0) return;

    values.push(this.id);

    const result = await query(
      `UPDATE addresses SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
      values
    );

    if (result.rows[0]) {
      Object.assign(this, new Address(result.rows[0]));
    }
  }
}

module.exports = Address;
