// Sentry - monitoramento/alerta de erros em produção. Sem SENTRY_DSN
// configurada, `isConfigured()` retorna false e nada é inicializado - o
// backend continua logando erros no console normalmente (como sempre fez),
// só não manda nada para lugar nenhum.
let Sentry;
try {
  Sentry = require('@sentry/node');
} catch {
  Sentry = null; // pacote não instalado ainda (`npm install` não rodado)
}
require('dotenv').config();

const isConfigured = () => Boolean(Sentry) && Boolean(process.env.SENTRY_DSN);

function init() {
  if (!isConfigured()) return;

  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || 'development',
    tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE) || 0.1,
  });
}

// Middleware de erro do Express: captura a exceção no Sentry e repassa pro
// próximo error handler (o que já existia em server.js continua
// respondendo o JSON de erro normalmente pro cliente).
function errorHandler() {
  if (!isConfigured()) {
    // no-op transparente - não interfere na cadeia de middlewares
    return (err, req, res, next) => next(err);
  }
  return Sentry.expressErrorHandler();
}

function captureException(error, context) {
  if (!isConfigured()) return;
  Sentry.captureException(error, context ? { extra: context } : undefined);
}

module.exports = { isConfigured, init, errorHandler, captureException };
