// Firebase Admin SDK - usado SOMENTE para enviar push notifications (FCM)
// aos apps cliente/profissional. Não tem nenhuma relação com o antigo uso
// de Firebase/Firestore que existia no app Flutter como mock de tempo real
// (removido - ver lib/telas/cliente_home.dart) - aqui é o uso real e único
// que o projeto faz de Firebase: mensageria push.
//
// CONFIGURAÇÃO NECESSÁRIA (não incluída, feita pelo desenvolvedor):
//   1. Criar um projeto no Firebase Console (ou reaproveitar um existente).
//   2. Gerar uma chave de conta de serviço: Configurações do projeto >
//      Contas de serviço > Gerar nova chave privada (baixa um .json).
//   3. Definir UMA das duas variáveis de ambiente:
//      - FIREBASE_SERVICE_ACCOUNT_PATH=/caminho/para/serviceAccount.json
//      - FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
//        (o conteúdo inteiro do JSON, útil quando não dá pra ter um
//        arquivo no disco, ex.: variável de ambiente em produção)
//   4. No app Flutter, adicionar google-services.json (Android) e
//      GoogleService-Info.plist (iOS) do MESMO projeto Firebase - ver
//      lib/services/push_notification_service.dart.
//
// Sem nenhuma dessas variáveis configuradas, `isConfigured()` retorna false
// e todo envio de push é pulado silenciosamente (best-effort) - o resto do
// app funciona normalmente.
let admin;
try {
  admin = require('firebase-admin');
} catch {
  admin = null; // pacote não instalado ainda (`npm install` não rodado)
}
require('dotenv').config();

const isConfigured = () =>
  Boolean(admin) && Boolean(process.env.FIREBASE_SERVICE_ACCOUNT_JSON || process.env.FIREBASE_SERVICE_ACCOUNT_PATH);

let _app = null;

function getMessaging() {
  if (!isConfigured()) return null;

  if (!_app) {
    const credentialJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
      : require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);

    _app = admin.initializeApp({
      credential: admin.credential.cert(credentialJson),
    });
  }

  return admin.messaging(_app);
}

module.exports = { isConfigured, getMessaging };
