const express = require('express');
const http = require('http');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { WebSocketServer } = require('ws');
require('dotenv').config();

const sentry = require('./config/sentry');
sentry.init();

// Captura erros que nenhum try/catch pegou - o processo teria derrubado o
// servidor silenciosamente sem isso. Loga localmente (como sempre) e manda
// pro Sentry quando configurado (ver config/sentry.js).
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason);
  sentry.captureException(reason instanceof Error ? reason : new Error(String(reason)));
});
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  sentry.captureException(error);
  // Não chamamos process.exit() aqui de propósito simples: em produção,
  // isso deveria idealmente derrubar o processo e deixar um orquestrador
  // (Docker/PM2 com restart automático - ver docker-compose.yml) subir uma
  // instância nova, já que o estado do processo após uma exceção não
  // tratada não é confiável. Optamos por só logar/capturar para não mudar
  // o comportamento de disponibilidade deste servidor sem um orquestrador
  // de restart garantidamente configurado na frente dele.
});

const { testConnection } = require('./config/database');
const { verifyToken } = require('./utils/helpers');
const { registerConnection } = require('./utils/realtime');
const { createRateLimitStore } = require('./utils/rateLimitStore');
const PaymentController = require('./controllers/paymentController');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const professionalRoutes = require('./routes/professionals');
const rideRoutes = require('./routes/rides');
const locationRoutes = require('./routes/location');
const clienteRoutes = require('./routes/clienteRoutes');
const paymentRoutes = require('./routes/payments');
const subscriptionRoutes = require('./routes/subscription');
const adminRoutes = require('./routes/admin');
const notificationRoutes = require('./routes/notifications');
const couponRoutes = require('./routes/coupons');
const walletRoutes = require('./routes/wallet');

// ---------------------------------------------------------------------------
// BUG CORRIGIDO: no server.js original, `app.use('/api/cliente', clienteRoutes)`
// era chamado ANTES de `const app = express()` existir, o que derrubava o
// processo assim que o arquivo era carregado (ReferenceError: Cannot access
// 'app' before initialization). O `app` agora é criado antes de qualquer uso,
// e todas as rotas (inclusive `rides` e `location`, que antes nunca eram
// montadas) são registradas na ordem correta.
// ---------------------------------------------------------------------------

const app = express();
const server = http.createServer(app);

// Middleware de segurança
app.use(helmet());
app.use(
  cors({
    origin: process.env.FRONTEND_URL || '*',
    credentials: true,
  })
);

// Rate limiting (usa Redis como store compartilhado entre instâncias quando
// configurado - ver utils/rateLimitStore.js; sem Redis, cai no store em
// memória padrão do express-rate-limit)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 300, // máximo de requisições por IP a cada 15 min
  standardHeaders: true,
  legacyHeaders: false,
  store: createRateLimitStore(),
});
app.use(limiter);

// Webhook da Stripe precisa do corpo BRUTO da requisição (para validar a
// assinatura), então é registrado ANTES do express.json() global, que
// converteria o corpo em JSON e quebraria a verificação de assinatura.
app.post(
  '/api/payments/webhook',
  express.raw({ type: 'application/json' }),
  (req, res) => PaymentController.webhook(req, res)
);

// Parsing de JSON / form
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Painel administrativo (HTML/JS estático, sem build step) - aprovação de
// documentação de profissionais. Servido em /admin.
app.use('/admin', express.static(path.join(__dirname, 'public/admin')));

// Rotas
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/professionals', professionalRoutes);
app.use('/api/rides', rideRoutes);
app.use('/api/location', locationRoutes);
app.use('/api/cliente', clienteRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/professionals/subscription', subscriptionRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/coupons', couponRoutes);
app.use('/api/wallet', walletRoutes);

// Health check
app.get('/health', async (req, res) => {
  try {
    await testConnection();
    res.json({
      status: 'OK',
      database: 'Connected',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(503).json({
      status: 'Service Unavailable',
      database: 'Error',
      error: error.message,
    });
  }
});

// Rota não encontrada
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Rota não encontrada' });
});

// Error handler central
// eslint-disable-next-line no-unused-vars
app.use((error, req, res, next) => {
  console.error('Error:', error);
  sentry.captureException(error, { url: req.originalUrl, method: req.method });
  if (error.message && error.message.includes('imagens são permitidas')) {
    return res.status(400).json({ success: false, message: error.message });
  }
  res.status(500).json({ success: false, message: 'Erro interno do servidor' });
});

// ---------------------------------------------------------------------------
// WebSocket - status de corrida e localização em tempo real.
// O app Flutter (lib/services/ws_service.dart) conecta em:
//   ws(s)://<host>/ws/trip/<rideId>?token=<jwt>
// e recebe mensagens { type: 'location' | 'status', ... } conforme o
// profissional atualiza sua posição (POST /api/location/update) ou o status
// da corrida muda (aceitar/iniciar/concluir/cancelar).
// ---------------------------------------------------------------------------
const wss = new WebSocketServer({ noServer: true });

server.on('upgrade', (request, socket, head) => {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const match = url.pathname.match(/^\/ws\/trip\/([^/]+)$/);

  if (!match) {
    socket.destroy();
    return;
  }

  const rideId = match[1];
  const token = url.searchParams.get('token');

  try {
    if (token) verifyToken(token); // apenas valida; não bloqueia se ausente em dev
  } catch (err) {
    socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
    socket.destroy();
    return;
  }

  wss.handleUpgrade(request, socket, head, (ws) => {
    registerConnection(rideId, ws);
    wss.emit('connection', ws, request);
  });
});

const PORT = process.env.PORT || 5000;

// CORRIGIDO/ADICIONADO: o servidor só sobe (`listen`) quando este arquivo é
// executado diretamente (`node server.js` / `npm start`). Quando importado
// por outro módulo - como os testes automatizados em `tests/`, via
// `require('../server').app` - nenhuma porta é aberta, permitindo testar a
// API com supertest sem conflito de portas nem necessidade de subir o
// processo inteiro.
if (require.main === module) {
  server.listen(PORT, '0.0.0.0', async () => {
    console.log(`🚀 Servidor rodando na porta ${PORT}`);
    console.log(`📊 Health check disponível em: http://localhost:${PORT}/health`);
    console.log(`🔌 WebSocket de corridas em: ws://localhost:${PORT}/ws/trip/:rideId`);
    console.log(`🛠️  Painel administrativo em: http://localhost:${PORT}/admin`);

    try {
      await testConnection();
    } catch (error) {
      console.error('❌ Erro na conexão com banco de dados:', error.message);
    }
  });
}

module.exports = { app, server };
