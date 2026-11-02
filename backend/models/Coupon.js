const { query } = require('../config/database');

class Coupon {
  constructor(data) {
    this.id = data.id;
    this.code = data.code;
    this.description = data.description;
    this.discount_type = data.discount_type; // 'percentage' | 'fixed'
    this.discount_value = Number(data.discount_value);
    this.min_ride_value = Number(data.min_ride_value || 0);
    this.max_uses = data.max_uses;
    this.uses_count = data.uses_count;
    this.max_uses_per_client = data.max_uses_per_client;
    this.valid_from = data.valid_from;
    this.valid_until = data.valid_until;
    this.active = data.active;
    this.created_at = data.created_at;
  }

  static async create({ code, description, discount_type, discount_value, min_ride_value, max_uses, max_uses_per_client, valid_from, valid_until }) {
    const result = await query(
      `INSERT INTO coupons (code, description, discount_type, discount_value, min_ride_value, max_uses, max_uses_per_client, valid_from, valid_until)
       VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8, CURRENT_TIMESTAMP), $9)
       RETURNING *`,
      [
        code.trim().toUpperCase(),
        description || null,
        discount_type,
        discount_value,
        min_ride_value || 0,
        max_uses || null,
        max_uses_per_client || 1,
        valid_from || null,
        valid_until || null,
      ]
    );
    return new Coupon(result.rows[0]);
  }

  static async findByCode(code) {
    const result = await query('SELECT * FROM coupons WHERE code = $1', [code.trim().toUpperCase()]);
    return result.rows[0] ? new Coupon(result.rows[0]) : null;
  }

  static async findAll() {
    const result = await query('SELECT * FROM coupons ORDER BY created_at DESC');
    return result.rows.map((row) => new Coupon(row));
  }

  static async setActive(id, active) {
    await query('UPDATE coupons SET active = $1 WHERE id = $2', [active, id]);
  }

  async countUsesByClient(clientId) {
    const result = await query(
      'SELECT COUNT(*)::int AS count FROM coupon_redemptions WHERE coupon_id = $1 AND client_id = $2',
      [this.id, clientId]
    );
    return result.rows[0].count;
  }

  // Valida o cupom para um cliente/valor de corrida específicos, sem
  // consumir nada ainda (usado tanto no "prévia de desconto" quanto como
  // primeira checagem antes de efetivamente aplicar na criação da corrida).
  async validateFor(clientId, rideValue) {
    if (!this.active) return { valid: false, message: 'Cupom inativo' };

    const now = new Date();
    if (this.valid_from && new Date(this.valid_from) > now) {
      return { valid: false, message: 'Cupom ainda não está válido' };
    }
    if (this.valid_until && new Date(this.valid_until) < now) {
      return { valid: false, message: 'Cupom expirado' };
    }
    if (this.max_uses != null && this.uses_count >= this.max_uses) {
      return { valid: false, message: 'Cupom atingiu o limite de usos' };
    }
    if (rideValue < this.min_ride_value) {
      return {
        valid: false,
        message: `Valor mínimo da corrida para este cupom: R$ ${this.min_ride_value.toFixed(2)}`,
      };
    }

    const usesByClient = await this.countUsesByClient(clientId);
    if (usesByClient >= this.max_uses_per_client) {
      return { valid: false, message: 'Você já utilizou este cupom o máximo de vezes permitido' };
    }

    return { valid: true };
  }

  calculateDiscount(rideValue) {
    const raw =
      this.discount_type === 'percentage' ? (rideValue * this.discount_value) / 100 : this.discount_value;
    // Nunca desconta mais que o valor da corrida (evita preço final negativo).
    return Math.min(raw, rideValue);
  }

  // Registra o resgate (histórico) e incrementa o contador de usos - chamado
  // só depois que a corrida com o cupom já foi criada com sucesso.
  async redeem({ clientId, rideId, discountApplied }) {
    await query(
      `INSERT INTO coupon_redemptions (coupon_id, client_id, ride_id, discount_applied)
       VALUES ($1, $2, $3, $4)`,
      [this.id, clientId, rideId, discountApplied]
    );
    await query('UPDATE coupons SET uses_count = uses_count + 1 WHERE id = $1', [this.id]);
    this.uses_count += 1;
  }
}

module.exports = Coupon;
