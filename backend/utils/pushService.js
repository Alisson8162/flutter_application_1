const { isConfigured, getMessaging } = require('../config/firebase');
const DeviceToken = require('../models/DeviceToken');

// Códigos de erro da FCM que significam "esse token nunca mais vai
// funcionar" (app desinstalado, token trocado, etc.) - removidos do banco
// para não tentar de novo.
const DEAD_TOKEN_ERRORS = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

async function _send(tokens, { title, body, data }) {
  if (!isConfigured() || tokens.length === 0) {
    return { success: false, sent: 0 };
  }

  const messaging = getMessaging();
  const stringData = data
    ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]))
    : undefined;

  try {
    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: stringData,
    });

    const deadTokens = [];
    response.responses.forEach((r, i) => {
      if (!r.success && DEAD_TOKEN_ERRORS.has(r.error?.code)) {
        deadTokens.push(tokens[i]);
      }
    });
    if (deadTokens.length) {
      DeviceToken.removeTokens(deadTokens).catch((e) =>
        console.error('Falha ao limpar tokens inválidos:', e.message)
      );
    }

    return { success: true, sent: response.successCount };
  } catch (error) {
    console.error('Push send error:', error.message);
    return { success: false, sent: 0, message: error.message };
  }
}

// Notifica um único usuário (todos os dispositivos dele).
// Best-effort por natureza: nunca lança - quem chama não precisa de
// try/catch nem de aguardar (`.catch(console.error)` já cobre erros).
async function sendToUser(userId, { title, body, data } = {}) {
  if (!isConfigured()) return { success: false, sent: 0 };
  const tokens = await DeviceToken.findTokensForUser(userId);
  return _send(tokens, { title, body, data });
}

// Notifica vários usuários de uma vez (ex.: todos os profissionais
// compatíveis com uma nova corrida).
async function sendToUsers(userIds, { title, body, data } = {}) {
  if (!isConfigured()) return { success: false, sent: 0 };
  const tokens = await DeviceToken.findTokensForUsers(userIds);
  return _send(tokens, { title, body, data });
}

module.exports = { sendToUser, sendToUsers };
