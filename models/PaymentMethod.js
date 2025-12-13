const { mysql, postgres } = require('../config/database');
const bcrypt = require('bcryptjs');

class PaymentMethod {
  constructor(paymentData) {
    this.id = paymentData.id;
    this.client_id = paymentData.client_id;
    this.numero_cartao_hash = paymentData.numero_cartao_hash;
    this.ultimos_quatro = paymentData.ultimos_quatro;
    this.nome_cartao = paymentData.nome_cartao;
    this.validade = paymentData.validade;
    this.cvv_hash = paymentData.cvv_hash;
    this.ativo = paymentData.ativo;
    this.created_at = paymentData.created_at;
  }

  // Criar método de pagamento
  static async create(paymentData, dbType = 'mysql') {
    const { client_id, numero_cartao, nome_cartao, validade, cvv } = paymentData;

    // Criptografar dados sensíveis
    const numeroCartaoHash = await bcrypt.hash(numero_cartao, 10);
    const cvvHash = await bcrypt.hash(cvv, 10);
    const ultimosQuatro = numero_cartao.slice(-4);

    if (dbType === 'mysql') {
      const [result] = await mysql.execute(
        `INSERT INTO payment_methods (client_id, numero_cartao_hash, ultimos_quatro, nome_cartao, validade, cvv_hash) 
         VALUES (?, ?, ?, ?, ?, ?)`,
        [client_id, numeroCartaoHash, ultimosQuatro, nome_cartao, validade, cvvHash]
      );
      return result.insertId;
    } else {
      const result = await postgres.query(
        `INSERT INTO payment_methods (client_id, numero_cartao_hash, ultimos_quatro, nome_cartao, validade, cvv_hash) 
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
        [client_id, numeroCartaoHash, ultimosQuatro, nome_cartao, validade, cvvHash]
      );
      return result.rows[0].id;
    }
  }

  // Buscar por client_id
  static async findByClientId(clientId, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM payment_methods WHERE client_id = ? AND ativo = TRUE ORDER BY created_at DESC',
        [clientId]
      );
      return rows.map(row => new PaymentMethod(row));
    } else {
      const result = await postgres.query(
        'SELECT * FROM payment_methods WHERE client_id = $1 AND ativo = TRUE ORDER BY created_at DESC',
        [clientId]
      );
      return result.rows.map(row => new PaymentMethod(row));
    }
  }

  // Buscar por ID
  static async findById(id, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM payment_methods WHERE id = ?',
        [id]
      );
      return rows[0] ? new PaymentMethod(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM payment_methods WHERE id = $1',
        [id]
      );
      return result.rows[0] ? new PaymentMethod(result.rows[0]) : null;
    }
  }

  // Deletar (desativar) método de pagamento
  static async delete(id, dbType = 'mysql') {
    if (dbType === 'mysql') {
      await mysql.execute(
        'UPDATE payment_methods SET ativo = FALSE WHERE id = ?',
        [id]
      );
    } else {
      await postgres.query(
        'UPDATE payment_methods SET ativo = FALSE WHERE id = $1',
        [id]
      );
    }
  }
}

module.exports = PaymentMethod;