const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const JWT_SECRET = process.env.JWT_SECRET || 'falacomigo_secret';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

// Gerar token JWT de acesso. Todo token emitido a partir de agora carrega um
// `jti` (JWT ID) único - é o que permite revogar um token específico antes
// da sua expiração natural (ver models/RevokedToken.js e middleware/auth.js).
// Mantido com o mesmo nome/assinatura de antes por compatibilidade: todo
// código existente que chama generateToken(payload) continua funcionando
// sem mudanças, só passa a ganhar um jti "de graça".
const generateToken = (payload, expiresIn = JWT_EXPIRES_IN) => {
  return jwt.sign({ ...payload, jti: uuidv4() }, JWT_SECRET, { expiresIn });
};

// Verificar token JWT
const verifyToken = (token) => {
  return jwt.verify(token, JWT_SECRET);
};

// Token de acesso "pendente de 2FA": emitido logo após senha/OTP corretos
// quando o usuário tem 2FA ativado, mas ANTES de confirmar o código TOTP.
// Vida curta (5 min) e um claim próprio (`pending2fa`) que o middleware de
// autenticação normal nunca aceita - só o endpoint /2fa/verify-login sabe
// interpretá-lo.
const generatePending2FAToken = (payload) => {
  return jwt.sign({ ...payload, pending2fa: true, jti: uuidv4() }, JWT_SECRET, { expiresIn: '5m' });
};

// Gerar código numérico (ex: OTP de verificação)
const generateNumericCode = (length = 4) => {
  const min = Math.pow(10, length - 1);
  const max = Math.pow(10, length) - 1;
  return Math.floor(min + Math.random() * (max - min + 1)).toString();
};

// Validar CPF (algoritmo padrão de dígitos verificadores)
const validateCPF = (cpf) => {
  if (!cpf) return false;
  cpf = cpf.replace(/[^\d]/g, '');

  if (cpf.length !== 11) return false;
  if (/^(\d)\1{10}$/.test(cpf)) return false; // todos os dígitos iguais

  let sum = 0;
  let remainder;

  for (let i = 1; i <= 9; i++) {
    sum += parseInt(cpf.substring(i - 1, i), 10) * (11 - i);
  }
  remainder = (sum * 10) % 11;
  if (remainder === 10 || remainder === 11) remainder = 0;
  if (remainder !== parseInt(cpf.substring(9, 10), 10)) return false;

  sum = 0;
  for (let i = 1; i <= 10; i++) {
    sum += parseInt(cpf.substring(i - 1, i), 10) * (12 - i);
  }
  remainder = (sum * 10) % 11;
  if (remainder === 10 || remainder === 11) remainder = 0;
  if (remainder !== parseInt(cpf.substring(10, 11), 10)) return false;

  return true;
};

// Distância (haversine) entre duas coordenadas, em km
const calculateDistanceKm = (lat1, lon1, lat2, lon2) => {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

module.exports = {
  generateToken,
  generatePending2FAToken,
  verifyToken,
  generateNumericCode,
  validateCPF,
  calculateDistanceKm,
};
