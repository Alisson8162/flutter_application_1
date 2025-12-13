const { mysql, postgres } = require('../config/database');

class Ride {
  constructor(rideData) {
    this.id = rideData.id;
    this.client_id = rideData.client_id;
    this.driver_id = rideData.driver_id;
    this.pickup_location = rideData.pickup_location;
    this.destination = rideData.destination;
    this.distance = rideData.distance;
    this.estimated_price = rideData.estimated_price;
    this.final_price = rideData.final_price;
    this.status = rideData.status;
    this.created_at = rideData.created_at;
    this.accepted_at = rideData.accepted_at;
    this.completed_at = rideData.completed_at;
  }

  // Criar corrida
  static async create(rideData, dbType = 'mysql') {
    const { client_id, pickup_location, destination, distance, estimated_price } = rideData;

    if (dbType === 'mysql') {
      const [result] = await mysql.execute(
        `INSERT INTO rides (client_id, pickup_location, destination, distance, estimated_price) 
         VALUES (?, ?, ?, ?, ?)`,
        [client_id, JSON.stringify(pickup_location), JSON.stringify(destination), distance, estimated_price]
      );
      return result.insertId;
    } else {
      const result = await postgres.query(
        `INSERT INTO rides (client_id, pickup_location, destination, distance, estimated_price) 
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [client_id, pickup_location, destination, distance, estimated_price]
      );
      return result.rows[0].id;
    }
  }

  // Buscar por ID
  static async findById(id, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM rides WHERE id = ?',
        [id]
      );
      return rows[0] ? new Ride(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM rides WHERE id = $1',
        [id]
      );
      return result.rows[0] ? new Ride(result.rows[0]) : null;
    }
  }

  // Buscar corridas pendentes
  static async findPending(dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM rides WHERE status = "pending" ORDER BY created_at DESC'
      );
      return rows.map(row => new Ride(row));
    } else {
      const result = await postgres.query(
        'SELECT * FROM rides WHERE status = $1 ORDER BY created_at DESC',
        ['pending']
      );
      return result.rows.map(row => new Ride(row));
    }
  }

  // Buscar corridas por motorista
  static async findByDriverId(driverId, page = 1, limit = 10, dbType = 'mysql') {
    const offset = (page - 1) * limit;

    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM rides WHERE driver_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [driverId, limit, offset]
      );
      return rows.map(row => new Ride(row));
    } else {
      const result = await postgres.query(
        'SELECT * FROM rides WHERE driver_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
        [driverId, limit, offset]
      );
      return result.rows.map(row => new Ride(row));
    }
  }

  // Atualizar corrida
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
        `UPDATE rides SET ${fields.join(', ')} WHERE id = ?`,
        values
      );
    } else {
      await postgres.query(
        `UPDATE rides SET ${fields.join(', ').replace(/\?/g, (_, index) => `$${index + 1}`)} WHERE id = $${values.length}`,
        values
      );
    }
  }
}

module.exports = Ride;