const { query } = require('../config/database');
const bcrypt = require('bcryptjs');

// BUG CORRIGIDO: nem o cadastro (create-admin.js) nem a busca (findByEmail)
// normalizavam o e-mail. Como a comparação `WHERE email = $1` do Postgres é
// sensível a maiúsculas/minúsculas por padrão, um admin criado como
// "Admin@Empresa.com" NUNCA seria encontrado se alguém digitasse
// "admin@empresa.com" no login (ou vice-versa) - o resultado prático é
// "digitei o email e a senha certos e mesmo assim não entra". Agora o
// e-mail é normalizado (minúsculo + sem espaços nas pontas) tanto ao criar
// quanto ao buscar, então a comparação deixa de depender de como cada
// pessoa capitalizou o e-mail em cada momento.
const normalizeEmail = (email) => (email || '').trim().toLowerCase();

// Administradores ficam em uma tabela própria (não em `users`), já que não
// são nem clientes nem profissionais - apenas operam o painel de aprovação
// de documentação. Isso evita ter que sobrecarregar o enum `user_role` e
// misturar permissões administrativas com contas de uso do app.
class Admin {
  static LOCK_THRESHOLD = 5;
  static LOCK_DURATION_MS = 15 * 60 * 1000; // 15 minutos

  constructor(data) {
    this.id = data.id;
    this.name = data.name;
    this.email = data.email;
    this.password_hash = data.password_hash;
    this.failed_login_attempts = data.failed_login_attempts;
    this.locked_until = data.locked_until;
    this.created_at = data.created_at;
  }

  static async create({ name, email, password }) {
    const password_hash = await bcrypt.hash(password, 12);
    const result = await query(
      'INSERT INTO admins (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id',
      [name, normalizeEmail(email), password_hash]
    );
    return result.rows[0].id;
  }

  static async findByEmail(email) {
    if (!email) return null;
    const result = await query('SELECT * FROM admins WHERE lower(email) = $1', [normalizeEmail(email)]);
    return result.rows[0] ? new Admin(result.rows[0]) : null;
  }

  static async findById(id) {
    const result = await query('SELECT * FROM admins WHERE id = $1', [id]);
    return result.rows[0] ? new Admin(result.rows[0]) : null;
  }

  async verifyPassword(password) {
    return bcrypt.compare(password, this.password_hash);
  }

  isLocked() {
    return !!this.locked_until && new Date(this.locked_until) > new Date();
  }

  async registerFailedLogin() {
    const attempts = (this.failed_login_attempts || 0) + 1;
    const fields = ['failed_login_attempts = $1'];
    const values = [attempts];
    let lockedUntil = this.locked_until;

    if (attempts >= Admin.LOCK_THRESHOLD) {
      lockedUntil = new Date(Date.now() + Admin.LOCK_DURATION_MS);
      fields.push('locked_until = $2');
      values.push(lockedUntil);
    }

    values.push(this.id);
    await query(`UPDATE admins SET ${fields.join(', ')} WHERE id = $${values.length}`, values);
    this.failed_login_attempts = attempts;
    this.locked_until = lockedUntil;
  }

  async resetFailedLogins() {
    if (this.failed_login_attempts || this.locked_until) {
      await query('UPDATE admins SET failed_login_attempts = 0, locked_until = NULL WHERE id = $1', [this.id]);
      this.failed_login_attempts = 0;
      this.locked_until = null;
    }
  }

  toJSON() {
    return { id: this.id, name: this.name, email: this.email };
  }
}

module.exports = Admin;
