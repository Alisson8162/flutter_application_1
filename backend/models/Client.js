const { query } = require('../config/database');

class Client {
  constructor(clientData) {
    this.id = clientData.id;
    this.user_id = clientData.user_id;
    this.tipo_veiculo_preferido = clientData.tipo_veiculo_preferido;
    this.endereco_id = clientData.endereco_id;
    this.stripe_customer_id = clientData.stripe_customer_id;
    this.created_at = clientData.created_at;
    this.updated_at = clientData.updated_at;
  }

  static async create(clientData) {
    const { user_id, tipo_veiculo_preferido, endereco_id } = clientData;

    const result = await query(
      `INSERT INTO clients (user_id, tipo_veiculo_preferido, endereco_id)
       VALUES ($1, $2, $3) RETURNING id`,
      [user_id, tipo_veiculo_preferido || null, endereco_id || null]
    );
    return result.rows[0].id;
  }

  static async findByUserId(userId) {
    const result = await query('SELECT * FROM clients WHERE user_id = $1', [userId]);
    return result.rows[0] ? new Client(result.rows[0]) : null;
  }

  static async findById(id) {
    const result = await query('SELECT * FROM clients WHERE id = $1', [id]);
    return result.rows[0] ? new Client(result.rows[0]) : null;
  }

  async update(updates) {
    const allowedFields = ['tipo_veiculo_preferido', 'endereco_id', 'stripe_customer_id'];

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
      `UPDATE clients SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${i} RETURNING *`,
      values
    );

    if (result.rows[0]) {
      Object.assign(this, new Client(result.rows[0]));
    }
  }
}

module.exports = Client;
