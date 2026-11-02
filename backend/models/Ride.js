const { query } = require('../config/database');

class Ride {
  constructor(data) {
    this.id = data.id;
    this.client_id = data.client_id;
    this.driver_id = data.driver_id;
    this.pickup_location = data.pickup_location;
    this.destination = data.destination;
    this.distance = data.distance;
    this.estimated_price = data.estimated_price;
    this.final_price = data.final_price;
    this.status = data.status;
    this.payment_status = data.payment_status;
    this.stripe_payment_intent_id = data.stripe_payment_intent_id;
    this.stripe_refund_id = data.stripe_refund_id;
    this.refunded_at = data.refunded_at;
    this.refund_reason = data.refund_reason;
    this.payment_method = data.payment_method;
    this.coupon_id = data.coupon_id;
    this.discount_applied = data.discount_applied;
    this.created_at = data.created_at;
    this.accepted_at = data.accepted_at;
    this.started_at = data.started_at;
    this.completed_at = data.completed_at;
    this.cancelled_at = data.cancelled_at;
  }

  static async create(rideData) {
    const { client_id, pickup_location, destination, distance, estimated_price, coupon_id, discount_applied } = rideData;

    const result = await query(
      `INSERT INTO rides (client_id, pickup_location, destination, distance, estimated_price, coupon_id, discount_applied)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [
        client_id,
        JSON.stringify(pickup_location),
        JSON.stringify(destination),
        distance,
        estimated_price,
        coupon_id || null,
        discount_applied || 0,
      ]
    );
    return result.rows[0].id;
  }

  static async findById(id) {
    const result = await query('SELECT * FROM rides WHERE id = $1', [id]);
    return result.rows[0] ? new Ride(result.rows[0]) : null;
  }

  static async findPending() {
    const result = await query(
      "SELECT * FROM rides WHERE status = 'pending' ORDER BY created_at DESC"
    );
    return result.rows.map((row) => new Ride(row));
  }

  static async findByDriverId(driverId, page = 1, limit = 10) {
    const safePage = Math.max(1, parseInt(page, 10) || 1);
    const safeLimit = Math.min(50, Math.max(1, parseInt(limit, 10) || 10));
    const offset = (safePage - 1) * safeLimit;

    const result = await query(
      'SELECT * FROM rides WHERE driver_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
      [driverId, safeLimit, offset]
    );
    return result.rows.map((row) => new Ride(row));
  }

  static async findByClientId(clientId, page = 1, limit = 10) {
    const safePage = Math.max(1, parseInt(page, 10) || 1);
    const safeLimit = Math.min(50, Math.max(1, parseInt(limit, 10) || 10));
    const offset = (safePage - 1) * safeLimit;

    const result = await query(
      'SELECT * FROM rides WHERE client_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
      [clientId, safeLimit, offset]
    );
    return result.rows.map((row) => new Ride(row));
  }

  // Corrida ativa (não finalizada/cancelada) de um cliente ou motorista
  static async findActiveForUser(userId, role) {
    const column = role === 'profissional' ? 'driver_id' : 'client_id';
    const result = await query(
      `SELECT r.*, du.name AS driver_name, du.phone AS driver_phone, cu.name AS client_name
       FROM rides r
       LEFT JOIN users du ON r.driver_id = du.id
       JOIN users cu ON r.client_id = cu.id
       WHERE r.${column} = $1 AND r.status IN ('pending','accepted','in_progress')
       ORDER BY r.created_at DESC LIMIT 1`,
      [userId]
    );
    if (!result.rows[0]) return null;
    const ride = new Ride(result.rows[0]);
    ride.driver_name = result.rows[0].driver_name;
    ride.driver_phone = result.rows[0].driver_phone;
    ride.client_name = result.rows[0].client_name;
    return ride;
  }

  // Usado pelo painel administrativo para monitoramento/suporte
  static async findRecent(limit = 50) {
    const safeLimit = Math.min(200, Math.max(1, parseInt(limit, 10) || 50));
    const result = await query(
      `SELECT r.*, cu.name AS client_name, du.name AS driver_name
       FROM rides r
       JOIN users cu ON r.client_id = cu.id
       LEFT JOIN users du ON r.driver_id = du.id
       ORDER BY r.created_at DESC
       LIMIT $1`,
      [safeLimit]
    );
    return result.rows;
  }

  async update(updates) {
    const allowedFields = [
      'driver_id',
      'status',
      'final_price',
      'accepted_at',
      'started_at',
      'completed_at',
      'cancelled_at',
      'payment_status',
      'stripe_payment_intent_id',
      'stripe_refund_id',
      'refunded_at',
      'refund_reason',
      'payment_method',
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
      `UPDATE rides SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
      values
    );

    if (result.rows[0]) {
      Object.assign(this, new Ride(result.rows[0]));
    }
  }
}

module.exports = Ride;
