const { query } = require('../config/database');

class ProfessionalSubscription {
  constructor(data) {
    this.id = data.id;
    this.professional_id = data.professional_id;
    this.stripe_customer_id = data.stripe_customer_id;
    this.stripe_subscription_id = data.stripe_subscription_id;
    this.stripe_payment_method_id = data.stripe_payment_method_id;
    this.status = data.status;
    this.current_period_end = data.current_period_end;
    this.created_at = data.created_at;
    this.updated_at = data.updated_at;
  }

  static async findByProfessionalId(professionalId) {
    const result = await query('SELECT * FROM professional_subscriptions WHERE professional_id = $1', [
      professionalId,
    ]);
    return result.rows[0] ? new ProfessionalSubscription(result.rows[0]) : null;
  }

  static async findByStripeSubscriptionId(stripeSubscriptionId) {
    const result = await query(
      'SELECT * FROM professional_subscriptions WHERE stripe_subscription_id = $1',
      [stripeSubscriptionId]
    );
    return result.rows[0] ? new ProfessionalSubscription(result.rows[0]) : null;
  }

  // Upsert: um profissional tem no máximo uma linha de assinatura. Chamado
  // tanto ao criar/tentar a assinatura quanto ao processar webhooks.
  static async upsert(professionalId, data) {
    const existing = await ProfessionalSubscription.findByProfessionalId(professionalId);

    if (existing) {
      const fields = [];
      const values = [];
      let i = 1;
      const allowed = [
        'stripe_customer_id',
        'stripe_subscription_id',
        'stripe_payment_method_id',
        'status',
        'current_period_end',
      ];
      Object.keys(data).forEach((key) => {
        if (allowed.includes(key) && data[key] !== undefined) {
          fields.push(`${key} = $${i}`);
          values.push(data[key]);
          i += 1;
        }
      });
      if (fields.length === 0) return existing;
      values.push(professionalId);
      const result = await query(
        `UPDATE professional_subscriptions SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP
         WHERE professional_id = $${i} RETURNING *`,
        values
      );
      return new ProfessionalSubscription(result.rows[0]);
    }

    const result = await query(
      `INSERT INTO professional_subscriptions
         (professional_id, stripe_customer_id, stripe_subscription_id, stripe_payment_method_id, status, current_period_end)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [
        professionalId,
        data.stripe_customer_id || null,
        data.stripe_subscription_id || null,
        data.stripe_payment_method_id || null,
        data.status || 'inactive',
        data.current_period_end || null,
      ]
    );
    return new ProfessionalSubscription(result.rows[0]);
  }
}

module.exports = ProfessionalSubscription;
