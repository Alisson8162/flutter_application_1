const { query } = require('../config/database');
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
    this.two_factor_enabled = userData.two_factor_enabled;
    this.two_factor_secret = userData.two_factor_secret;
    this.failed_login_attempts = userData.failed_login_attempts;
    this.locked_until = userData.locked_until;
    this.created_at = userData.created_at;
    this.updated_at = userData.updated_at;
  }

  // Criar usuário
  static async create(userData) {
    const { role, name, email, phone, cpf, password } = userData;
    const password_hash = password ? await bcrypt.hash(password, 12) : null;
    // Mesmo bug do Admin.js corrigido aqui: e-mail salvo em minúsculo para
    // que o login nunca dependa de como a pessoa capitalizou o e-mail no
    // cadastro vs. no login.
    const normalizedEmail = email ? email.trim().toLowerCase() : null;
    // Mesmo motivo: CPF salvo só com dígitos, senão "529.982.247-25" e
    // "52998224725" seriam tratados como CPFs diferentes pela constraint
    // UNIQUE e pela verificação anti-fraude em findByCpf/authController.
    const normalizedCpf = cpf ? cpf.replace(/[^\d]/g, '') : null;

    const result = await query(
      `INSERT INTO users (role, name, email, phone, cpf, password_hash)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [role, name, normalizedEmail, phone || null, normalizedCpf, password_hash]
    );
    return result.rows[0].id;
  }

  static async findByEmail(email) {
    if (!email) return null;
    const result = await query('SELECT * FROM users WHERE lower(email) = $1', [email.trim().toLowerCase()]);
    return result.rows[0] ? new User(result.rows[0]) : null;
  }

  static async findByPhone(phone) {
    if (!phone) return null;
    const result = await query('SELECT * FROM users WHERE phone = $1', [phone]);
    return result.rows[0] ? new User(result.rows[0]) : null;
  }

  // Usado no cadastro para impedir que alguém desativado por falta de
  // pagamento da mensalidade (profissional) crie uma conta nova com o
  // mesmo CPF só trocando e-mail/telefone.
  static async findByCpf(cpf) {
    if (!cpf) return null;
    const cleaned = cpf.replace(/[^\d]/g, '');
    const result = await query('SELECT * FROM users WHERE cpf = $1', [cleaned]);
    return result.rows[0] ? new User(result.rows[0]) : null;
  }

  static async findById(id) {
    if (!id) return null;
    const result = await query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0] ? new User(result.rows[0]) : null;
  }

  // Verificar senha
  async verifyPassword(password) {
    if (!this.password_hash) return false;
    return bcrypt.compare(password, this.password_hash);
  }

  // Atualizar usuário
  // BUG CORRIGIDO: a versão original desta classe montava o UPDATE contra a
  // tabela `addresses` (copiado por engano do model Address) em vez de
  // `users`, então qualquer atualização de perfil de usuário corrompia
  // endereços em vez de atualizar o próprio usuário.
  async update(updates) {
    const allowedFields = [
      'name',
      'email',
      'phone',
      'cpf',
      'password_hash',
      'email_verified',
      'phone_verified',
      'foto_url',
      'two_factor_enabled',
      'two_factor_secret',
      'failed_login_attempts',
      'locked_until',
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
      `UPDATE users SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${i} RETURNING *`,
      values
    );

    if (result.rows[0]) {
      Object.assign(this, new User(result.rows[0]));
    }
  }

  // Atualizar senha diretamente (já em texto puro; faz o hash aqui)
  async updatePassword(newPassword) {
    const password_hash = await bcrypt.hash(newPassword, 12);
    await this.update({ password_hash });
  }

  // --- Bloqueio por tentativas de login (proteção contra força bruta) ---
  static LOCK_THRESHOLD = 5;
  static LOCK_DURATION_MS = 15 * 60 * 1000; // 15 minutos

  isLocked() {
    return !!this.locked_until && new Date(this.locked_until) > new Date();
  }

  async registerFailedLogin() {
    const attempts = (this.failed_login_attempts || 0) + 1;
    const updates = { failed_login_attempts: attempts };
    if (attempts >= User.LOCK_THRESHOLD) {
      updates.locked_until = new Date(Date.now() + User.LOCK_DURATION_MS);
    }
    await this.update(updates);
  }

  async resetFailedLogins() {
    if (this.failed_login_attempts || this.locked_until) {
      await this.update({ failed_login_attempts: 0, locked_until: null });
    }
  }

  // --- 2FA (TOTP) ---
  hasTwoFactorEnabled() {
    return !!this.two_factor_enabled;
  }

  toJSON() {
    return {
      id: this.id,
      role: this.role,
      name: this.name,
      email: this.email,
      phone: this.phone,
      cpf: this.cpf,
      foto_url: this.foto_url,
      email_verified: this.email_verified,
      phone_verified: this.phone_verified,
      two_factor_enabled: !!this.two_factor_enabled,
      created_at: this.created_at,
    };
  }
}

module.exports = User;
