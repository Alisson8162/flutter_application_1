const { query } = require('../config/database');

class RideMessage {
  constructor(data) {
    this.id = data.id;
    this.ride_id = data.ride_id;
    this.sender_id = data.sender_id;
    this.sender_name = data.sender_name; // presente quando vem do JOIN em findByRide
    this.content = data.content;
    this.created_at = data.created_at;
  }

  static async create({ ride_id, sender_id, content }) {
    const result = await query(
      `INSERT INTO ride_messages (ride_id, sender_id, content)
       VALUES ($1, $2, $3) RETURNING *`,
      [ride_id, sender_id, content]
    );
    return new RideMessage(result.rows[0]);
  }

  // Histórico de uma corrida, com o nome de quem enviou cada mensagem já
  // resolvido (evita o app ter que casar sender_id com client/driver).
  static async findByRide(rideId, { limit = 200 } = {}) {
    const safeLimit = Math.min(500, Math.max(1, Number(limit) || 200));
    const result = await query(
      `SELECT m.*, u.name AS sender_name
       FROM ride_messages m
       JOIN users u ON m.sender_id = u.id
       WHERE m.ride_id = $1
       ORDER BY m.created_at ASC
       LIMIT $2`,
      [rideId, safeLimit]
    );
    return result.rows.map((row) => new RideMessage(row));
  }
}

module.exports = RideMessage;
