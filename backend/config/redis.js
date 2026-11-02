// Redis - hoje usado para UMA coisa específica: o *store* do rate limiter
// (ver server.js e routes/auth.js). Sem Redis, cada instância do backend
// guarda os contadores de rate limit na própria memória - funciona bem com
// uma única instância, mas quebra a garantia assim que você roda mais de um
// processo/container atrás de um load balancer (cada instância teria seu
// próprio contador, multiplicando o limite real por N instâncias). Redis
// resolve isso: todas as instâncias compartilham o mesmo contador.
//
// Como Docker/Redis, roda como um serviço separado (ver docker-compose.yml)
// e este projeto não tem Redis disponível neste ambiente de
// desenvolvimento/sandbox, este arquivo segue o mesmo padrão de degradação
// graciosa já usado para Stripe/Firebase: sem REDIS_URL configurada, cai
// para os stores em memória (funcionalmente idêntico ao comportamento antes
// desta mudança) e loga um aviso, em vez de derrubar o servidor.
let Redis;
try {
  Redis = require('ioredis');
} catch {
  Redis = null; // pacote não instalado ainda (`npm install` não rodado)
}
require('dotenv').config();

const isConfigured = () => Boolean(Redis) && Boolean(process.env.REDIS_URL);

let _client = null;
let _connectionAttempted = false;

// Retorna um client Redis já conectado, ou `null` se Redis não estiver
// configurado/disponível. Nunca lança - quem chama trata o `null` caindo
// para o comportamento em memória.
function getClient() {
  if (!isConfigured()) return null;
  if (_client) return _client;
  if (_connectionAttempted) return null; // já tentou e falhou antes, não fica tentando de novo a cada request

  _connectionAttempted = true;
  try {
    _client = new Redis(process.env.REDIS_URL, {
      maxRetriesPerRequest: 2,
      retryStrategy: (times) => (times > 3 ? null : Math.min(times * 200, 1000)),
    });
    _client.on('error', (err) => {
      console.error('❌ Erro de conexão com o Redis:', err.message);
    });
    _client.on('connect', () => {
      console.log('✅ Redis conectado com sucesso');
    });
    return _client;
  } catch (error) {
    console.error('Falha ao inicializar cliente Redis:', error.message);
    _client = null;
    return null;
  }
}

module.exports = { isConfigured, getClient };
