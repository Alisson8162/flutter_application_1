const { Pool } = require('pg');
require('dotenv').config();

// ---------------------------------------------------------------------------
// Banco de dados único: PostgreSQL.
//
// O projeto original mantinha MySQL e PostgreSQL simultaneamente, obrigando
// cada model a duplicar toda query em dois dialetos (com bugs de substituição
// de placeholders "?" -> "$n"). Isso foi removido: o backend agora usa
// exclusivamente PostgreSQL, o que elimina uma classe inteira de bugs.
// ---------------------------------------------------------------------------

const connectionString = process.env.PG_CONNECTION_STRING;

const poolConfig = connectionString
  ? {
      connectionString,
      ssl: process.env.PG_SSL === 'true' ? { rejectUnauthorized: false } : false,
    }
  : {
      host: process.env.PG_HOST || 'localhost',
      port: Number(process.env.PG_PORT) || 5432,
      user: process.env.PG_USER || 'postgres',
      password: process.env.PG_PASSWORD || '',
      database: process.env.PG_DATABASE || 'falacomigo',
      ssl: process.env.PG_SSL === 'true' ? { rejectUnauthorized: false } : false,
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    };

const pool = new Pool(poolConfig);

pool.on('error', (err) => {
  console.error('❌ Erro inesperado no pool do PostgreSQL:', err);
});

// Testar conexão com o banco
const testConnection = async () => {
  const client = await pool.connect();
  try {
    await client.query('SELECT 1');
    console.log('✅ PostgreSQL conectado com sucesso');
  } finally {
    client.release();
  }
};

// Helper simples para queries: query(text, params)
const query = (text, params) => pool.query(text, params);

module.exports = {
  pool,
  query,
  testConnection,
};
