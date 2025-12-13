const { mysql, postgres } = require('../config/database');
const bcrypt = require('bcryptjs');

class User {
  constructor(userData) {
    this.id = userData.id;
    this.role = userData.role;
    this.name = userData.name;
    this.email = userData.email;
    this.phone = userData.phone;
    this.cpf = userData.cpf;
    this.password_hash = userData.password_hash;
    this.email_verified = userData.email_verified;
    this.phone_verified = userData.phone_verified;
    this.foto_url = userData.foto_url;
    this.tipo = userData.tipo;
    this.created_at = userData.created_at;
    this.updated_at = userData.updated_at;
  }

  // Criar usuário
  static async create(userData, dbType = 'mysql') {
    const { role, name, email, phone, cpf, password } = userData;
    const password_hash = await bcrypt.hash(password, 12);

    if (dbType === 'mysql') {
      const [result] = await mysql.execute(
        `INSERT INTO users (role, name, email, phone, cpf, password_hash) 
         VALUES (?, ?, ?, ?, ?, ?)`,
        [role, name, email, phone, cpf, password_hash]
      );
      return result.insertId;
    } else {
      const result = await postgres.query(
        `INSERT INTO users (role, name, email, phone, cpf, password_hash) 
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
        [role, name, email, phone, cpf, password_hash]
      );
      return result.rows[0].id;
    }
  }

  // Buscar por email
  static async findByEmail(email, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM users WHERE email = ?',
        [email]
      );
      return rows[0] ? new User(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM users WHERE email = $1',
        [email]
      );
      return result.rows[0] ? new User(result.rows[0]) : null;
    }
  }

  // Buscar por telefone
  static async findByPhone(phone, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM users WHERE phone = ?',
        [phone]
      );
      return rows[0] ? new User(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM users WHERE phone = $1',
        [phone]
      );
      return result.rows[0] ? new User(result.rows[0]) : null;
    }
  }

  // Buscar por ID
  static async findById(id, dbType = 'mysql') {
    if (dbType === 'mysql') {
      const [rows] = await mysql.execute(
        'SELECT * FROM users WHERE id = ?',
        [id]
      );
      return rows[0] ? new User(rows[0]) : null;
    } else {
      const result = await postgres.query(
        'SELECT * FROM users WHERE id = $1',
        [id]
      );
      return result.rows[0] ? new User(result.rows[0]) : null;
    }
  }

  // Verificar senha
  async verifyPassword(password) {
    return await bcrypt.compare(password, this.password_hash);
  }

  // Atualizar usuário
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
          `UPDATE addresses SET ${fields.join(', ')} WHERE id = ?`,
          values
        );
      } else {
        // Corrigido: substituir cada ? por $1, $2, ... sequencialmente
        let fieldCount = 0;
        const setClause = fields.map(field => {
          fieldCount++;
          return field.replace('?', `$${fieldCount}`);
        }).join(', ');
        const whereClause = `WHERE id = $${fieldCount + 1}`;
        await postgres.query(
          `UPDATE addresses SET ${setClause} ${whereClause}`,
          values
        );
      }
    }
  }

module.exports = User;