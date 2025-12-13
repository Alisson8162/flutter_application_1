const mysql = require('mysql2/promise');
const { Pool } = require('pg');
require('dotenv').config();

// Configuração MySQL
const mysqlConfig = {
  host: process.env.MYSQL_HOST || 'localhost',
  user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || '',
  database: process.env.MYSQL_DATABASE || 'falacomigo',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// Configuração PostgreSQL
const postgresConfig = {
  host: process.env.PG_HOST || 'localhost',
  user: process.env.PG_USER || 'postgres',
  password: process.env.PG_PASSWORD || '',
  database: process.env.PG_DATABASE || 'falacomigo',
  port: process.env.PG_PORT || 5432,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
};

const mysqlPool = mysql.createPool(mysqlConfig);
const postgresPool = new Pool(postgresConfig);

// Testar conexões
const testConnections = async () => {
  try {
    const mysqlConn = await mysqlPool.getConnection();
    console.log('✅ MySQL conectado com sucesso');
    mysqlConn.release();
    
    const pgConn = await postgresPool.connect();
    console.log('✅ PostgreSQL conectado com sucesso');
    pgConn.release();
  } catch (error) {
    console.error('❌ Erro na conexão com banco de dados:', error);
    process.exit(1);
  }
};

module.exports = {
  mysql: mysqlPool,
  postgres: postgresPool,
  testConnections
};