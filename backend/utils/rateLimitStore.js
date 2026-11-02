// Store compartilhado para os rate limiters (server.js, routes/auth.js,
// routes/admin.js). Usa Redis quando disponível - necessário para os
// limites serem respeitados de verdade quando o backend roda com mais de
// uma instância (ver config/redis.js). Sem Redis configurado, retorna
// `undefined`, e o express-rate-limit usa seu store padrão em memória -
// mesmo comportamento de antes desta mudança, então nada quebra em quem
// ainda não configurou Redis.
let RedisStore;
try {
  RedisStore = require('rate-limit-redis').default || require('rate-limit-redis');
} catch {
  RedisStore = null; // pacote não instalado ainda (`npm install` não rodado)
}

const { isConfigured, getClient } = require('../config/redis');

function createRateLimitStore() {
  if (!RedisStore || !isConfigured()) return undefined;

  const client = getClient();
  if (!client) return undefined;

  return new RedisStore({
    sendCommand: (...args) => client.call(...args),
  });
}

module.exports = { createRateLimitStore };
