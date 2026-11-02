const { verifyToken } = require('../utils/helpers');
const RevokedToken = require('../models/RevokedToken');

const authenticate = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ success: false, message: 'Token de acesso necessário' });
    }

    const decoded = verifyToken(token);

    // Token emitido durante um login com 2FA pendente não é um token de
    // acesso válido para o resto da API - só serve para o endpoint
    // /auth/2fa/verify-login completar o login.
    if (decoded.pending2fa) {
      return res.status(401).json({ success: false, message: 'Verificação em duas etapas pendente' });
    }

    // Blacklist: tokens explicitamente revogados (logout, logout em todos os
    // dispositivos, troca de senha) são rejeitados mesmo que ainda não
    // tenham expirado naturalmente.
    // Se a tabela revoked_tokens ainda não existe (banco criado antes desta
    // feature e `npm run db:init` não rodado), NÃO derruba a sessão: antes,
    // esse erro caía no catch abaixo e virava 401 - o painel admin fazia
    // login, a primeira chamada autenticada falhava e ele voltava sozinho
    // para a tela de login ("pisca a tela e nada acontece").
    let revoked = false;
    try {
      revoked = await RevokedToken.isRevoked(decoded.jti);
    } catch (err) {
      console.error('[auth] Falha ao consultar revoked_tokens (rode `npm run db:init`):', err.message);
    }
    if (revoked) {
      return res.status(401).json({ success: false, message: 'Sessão encerrada. Faça login novamente.' });
    }

    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Token inválido ou expirado' });
  }
};

const authorize = (roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Acesso não autorizado' });
    }
    next();
  };
};

module.exports = { authenticate, authorize };
