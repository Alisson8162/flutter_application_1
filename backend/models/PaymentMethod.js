const { query } = require('../config/database');

// REESCRITO PARA STRIPE: a versão anterior guardava um hash do número do
// cartão e do CVV, gerados no próprio backend a partir do número de cartão
// enviado pelo app - ou seja, o número de cartão em texto puro passava pelo
// nosso servidor antes de virar hash, o que já é um problema sério de
// escopo PCI-DSS (o correto é o número do cartão nunca tocar seu servidor).
//
// Agora o fluxo é: o app usa o SDK da Stripe (flutter_stripe) para coletar
// o cartão e confirmar um SetupIntent DIRETAMENTE com a Stripe. Nosso
// backend nunca vê o número do cartão - apenas recebe de volta um
// `payment_method_id` da Stripe, que é o que persistimos aqui.
class PaymentMethod {
  constructor(data) {
    this.id = data.id;
    this.client_id = data.client_id;
    this.stripe_payment_method_id = data.stripe_payment_method_id;
    this.brand = data.brand;
    this.ultimos_quatro = data.ultimos_quatro;
    this.exp_month = data.exp_month;
    this.exp_year = data.exp_year;
    this.is_default = data.is_default;
    this.ativo = data.ativo;
    this.created_at = data.created_at;
  }

  static async create(data) {
    const {
      client_id,
      stripe_payment_method_id,
      brand,
      ultimos_quatro,
      exp_month,
      exp_year,
      is_default = false,
    } = data;

    if (is_default) {
      await query('UPDATE payment_methods SET is_default = FALSE WHERE client_id = $1', [client_id]);
    }

    const result = await query(
      `INSERT INTO payment_methods
         (client_id, stripe_payment_method_id, brand, ultimos_quatro, exp_month, exp_year, is_default)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [client_id, stripe_payment_method_id, brand, ultimos_quatro, exp_month, exp_year, is_default]
    );
    return result.rows[0].id;
  }

  static async findByClientId(clientId) {
    const result = await query(
      `SELECT id, client_id, stripe_payment_method_id, brand, ultimos_quatro, exp_month, exp_year, is_default, ativo, created_at
       FROM payment_methods WHERE client_id = $1 AND ativo = TRUE ORDER BY is_default DESC, created_at DESC`,
      [clientId]
    );
    return result.rows.map((row) => new PaymentMethod(row));
  }

  static async findById(id) {
    const result = await query('SELECT * FROM payment_methods WHERE id = $1', [id]);
    return result.rows[0] ? new PaymentMethod(result.rows[0]) : null;
  }

  static async findDefaultForClient(clientId) {
    const result = await query(
      `SELECT * FROM payment_methods WHERE client_id = $1 AND ativo = TRUE
       ORDER BY is_default DESC, created_at DESC LIMIT 1`,
      [clientId]
    );
    return result.rows[0] ? new PaymentMethod(result.rows[0]) : null;
  }

  static async setDefault(id, clientId) {
    await query('UPDATE payment_methods SET is_default = FALSE WHERE client_id = $1', [clientId]);
    await query('UPDATE payment_methods SET is_default = TRUE WHERE id = $1', [id]);
  }

  static async delete(id) {
    await query('UPDATE payment_methods SET ativo = FALSE, is_default = FALSE WHERE id = $1', [id]);
  }
}

module.exports = PaymentMethod;
