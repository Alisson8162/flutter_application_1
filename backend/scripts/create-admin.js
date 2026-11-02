// Cria uma conta de administrador (painel /admin).
// Uso: node scripts/create-admin.js "Nome Completo" email@exemplo.com senha123

require('dotenv').config();
const Admin = require('../models/Admin');
const { pool } = require('../config/database');

async function main() {
  const [, , name, email, password] = process.argv;

  if (!name || !email || !password) {
    console.log('Uso: node scripts/create-admin.js "Nome Completo" email@exemplo.com senha123');
    process.exit(1);
  }

  const existing = await Admin.findByEmail(email);
  if (existing) {
    console.log(`Já existe um admin com o email ${email}`);
    process.exit(1);
  }

  const id = await Admin.create({ name, email, password });
  console.log(`✅ Admin criado com sucesso: ${email} (id: ${id})`);
  await pool.end();
}

main().catch((err) => {
  console.error('Erro ao criar admin:', err);
  process.exit(1);
});
