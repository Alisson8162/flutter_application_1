// Aplica o schema (scripts/init-postgres.sql) no banco configurado no .env.
// Uso: npm run db:init
//
// CORRIGIDO: o package.json original já referenciava este script
// (`db:init`), mas o arquivo nunca existia - `npm run db:init` falhava com
// "Cannot find module".

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../config/database');

async function main() {
  const sqlPath = path.join(__dirname, 'init-postgres.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');

  console.log('📦 Aplicando schema em', process.env.PG_DATABASE || '(connection string)');

  const client = await pool.connect();
  try {
    await client.query(sql);
    console.log('✅ Schema aplicado com sucesso');
  } finally {
    client.release();
  }

  await pool.end();
}

main().catch((err) => {
  console.error('❌ Erro ao aplicar schema:', err.message);
  process.exit(1);
});
