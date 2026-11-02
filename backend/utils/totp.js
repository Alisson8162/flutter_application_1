// TOTP (Time-based One-Time Password) - RFC 6238 / RFC 4226.
//
// Implementado com apenas o módulo `crypto` nativo do Node (sem depender de
// pacotes como `speakeasy`/`otplib`, que não estão no package.json e não há
// como instalar/testar neste ambiente). O algoritmo é padrão e o mesmo usado
// por Google Authenticator, Authy, etc. - qualquer um desses apps funciona
// para escanear o QR code gerado a partir de `buildOtpAuthUri`.

const crypto = require('crypto');

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const STEP_SECONDS = 30;
const DIGITS = 6;

// Gera um segredo aleatório em Base32 (formato padrão para apps TOTP)
function generateSecretBase32(byteLength = 20) {
  const bytes = crypto.randomBytes(byteLength);
  let bits = '';
  for (const byte of bytes) {
    bits += byte.toString(2).padStart(8, '0');
  }

  let secret = '';
  for (let i = 0; i + 5 <= bits.length; i += 5) {
    secret += BASE32_ALPHABET[parseInt(bits.substring(i, i + 5), 2)];
  }
  return secret;
}

function base32ToBuffer(base32) {
  const clean = base32.replace(/=+$/, '').toUpperCase();
  let bits = '';
  for (const char of clean) {
    const val = BASE32_ALPHABET.indexOf(char);
    if (val === -1) continue; // ignora caracteres inválidos (espaços, etc.)
    bits += val.toString(2).padStart(5, '0');
  }

  const bytes = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) {
    bytes.push(parseInt(bits.substring(i, i + 8), 2));
  }
  return Buffer.from(bytes);
}

// Gera o código TOTP de 6 dígitos para um determinado instante (contador de
// passos de 30s desde a epoch, como manda a RFC).
function generateTOTP(secretBase32, forTimeMs = Date.now(), step = STEP_SECONDS, digits = DIGITS) {
  const counter = Math.floor(forTimeMs / 1000 / step);

  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeUInt32BE(Math.floor(counter / 0x100000000), 0);
  counterBuffer.writeUInt32BE(counter % 0x100000000, 4);

  const key = base32ToBuffer(secretBase32);
  const hmac = crypto.createHmac('sha1', key).update(counterBuffer).digest();

  const offset = hmac[hmac.length - 1] & 0x0f;
  const binCode =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);

  const code = (binCode % 10 ** digits).toString().padStart(digits, '0');
  return code;
}

// Verifica um código informado pelo usuário, tolerando ±1 passo (30s) de
// diferença de relógio entre o celular e o servidor - prática padrão em
// implementações de TOTP.
function verifyTOTP(secretBase32, token, window = 1) {
  if (!secretBase32 || !token) return false;
  const cleanToken = String(token).trim();
  if (!/^\d{6}$/.test(cleanToken)) return false;

  const now = Date.now();
  for (let errorWindow = -window; errorWindow <= window; errorWindow++) {
    const expected = generateTOTP(secretBase32, now + errorWindow * STEP_SECONDS * 1000);
    if (crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(cleanToken))) {
      return true;
    }
  }
  return false;
}

// Monta a URI otpauth:// padrão, que qualquer app autenticador (Google
// Authenticator, Authy, 1Password...) reconhece ao escanear como QR code.
// O app Flutter pode gerar o QR a partir desta string com qualquer lib de
// QR code, ou mostrar `secret` para digitação manual.
function buildOtpAuthUri(secretBase32, accountLabel, issuer = 'FalaComigo') {
  const label = encodeURIComponent(`${issuer}:${accountLabel}`);
  const params = new URLSearchParams({
    secret: secretBase32,
    issuer,
    algorithm: 'SHA1',
    digits: String(DIGITS),
    period: String(STEP_SECONDS),
  });
  return `otpauth://totp/${label}?${params.toString()}`;
}

module.exports = {
  generateSecretBase32,
  generateTOTP,
  verifyTOTP,
  buildOtpAuthUri,
};
