const { query } = require('../config/database');

class Review {
  constructor(data) {
    this.id = data.id;
    this.ride_id = data.ride_id;
    this.client_id = data.client_id;
    this.professional_id = data.professional_id;
    this.nota = data.nota;
    this.comentario = data.comentario;
    this.created_at = data.created_at;
  }

  static async create(reviewData) {
    const { ride_id, client_id, professional_id, nota, comentario } = reviewData;

    const result = await query(
      `INSERT INTO reviews (ride_id, client_id, professional_id, nota, comentario)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [ride_id, client_id, professional_id, nota, comentario || null]
    );
    return result.rows[0].id;
  }

  static async findByRideId(rideId) {
    const result = await query('SELECT * FROM reviews WHERE ride_id = $1', [rideId]);
    return result.rows[0] ? new Review(result.rows[0]) : null;
  }

  static async findByProfessionalId(professionalId, page = 1, limit = 10) {
    const safePage = Math.max(1, parseInt(page, 10) || 1);
    const safeLimit = Math.min(50, Math.max(1, parseInt(limit, 10) || 10));
    const offset = (safePage - 1) * safeLimit;

    const result = await query(
      `SELECT r.*, u.name AS client_name
       FROM reviews r
       JOIN clients c ON r.client_id = c.id
       JOIN users u ON c.user_id = u.id
       WHERE r.professional_id = $1
       ORDER BY r.created_at DESC
       LIMIT $2 OFFSET $3`,
      [professionalId, safeLimit, offset]
    );
    return result.rows;
  }
}

module.exports = Review;
