const { query } = require('../config/database');

// Blacklist de tokens de acesso (JWT). Um JWT é stateless por natureza - uma
// vez emitido, continua "válido" para o middleware até expirar sozinho,
// mesmo que o usuário faça logout. Esta tabela resolve isso: guardamos o
// `jti` (identificador único, um por token emitido - ver utils/helpers.js)
// dos tokens explicitamente revogados, e o middleware de autenticação
// consulta essa lista a cada request autenticado.
class RevokedToken {
  // expiresAt = quando o JWT original expiraria de qualquer forma; depois
  // disso a entrada na blacklist não faz mais diferença e pode ser limpa.
  static async revoke(jti, userId, expiresAt) {
    if (!jti) return; // tokens antigos emitidos antes desta feature não têm jti
    await query(
      `INSERT INTO revoked_tokens (jti, user_id, expires_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (jti) DO NOTHING`,
      [jti, userId, expiresAt]
    );
  }

  static async isRevoked(jti) {
    if (!jti) return false;
    const result = await query('SELECT 1 FROM revoked_tokens WHERE jti = $1', [jti]);
    return result.rows.length > 0;
  }

  // Remove entradas cujo token original já teria expirado de qualquer
  // forma - mantém a tabela pequena. Pode ser chamado periodicamente (ex.:
  // um cron simples) ou sob demanda; não é chamado automaticamente a cada
  // request para não adicionar uma query extra no caminho quente.
  static async purgeExpired() {
    await query('DELETE FROM revoked_tokens WHERE expires_at < NOW()');
  }
}

module.exports = RevokedToken;
