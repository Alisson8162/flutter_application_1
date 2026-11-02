const User = require('../models/User');
const Professional = require('../models/Professional');
const Client = require('../models/Client');
const Verification = require('../models/Verification');
const Session = require('../models/Session');
const RevokedToken = require('../models/RevokedToken');
const {
  generateToken,
  generatePending2FAToken,
  generateNumericCode,
  verifyToken,
} = require('../utils/helpers');
const { generateSecretBase32, verifyTOTP, buildOtpAuthUri } = require('../utils/totp');
const { sendSMS } = require('../utils/smsService');
const { sendEmail, sendVerificationEmail, sendWelcomeEmail } = require('../utils/emailService');

const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutos

const isEmailIdentifier = (identifier) => identifier.includes('@');
const isPhoneIdentifier = (identifier) => /^\+?\d{8,15}$/.test(identifier);

// Emite o par de tokens (acesso + refresh) usado por todo login/cadastro
// bem-sucedido. O access token continua com a mesma validade de sempre
// (compatibilidade com o app já em produção); o refresh token é novo e
// opcional de usar - o app pode continuar como estava, ou passar a chamar
// POST /api/auth/refresh quando o access token expirar, em vez de forçar
// login novamente.
async function issueTokenPair(user, deviceInfo) {
  const token = generateToken({ userId: user.id, role: user.role, email: user.email });
  const { raw, hash } = Session.generate();
  await Session.create({ user_id: user.id, tokenHash: hash, device_info: deviceInfo || null });
  return { token, refreshToken: raw };
}

class AuthController {
  // Cadastro direto (nome, email, telefone, senha, cpf, role) - fluxo principal usado pelo app
  async register(req, res) {
    try {
      const { name, email, phone, cpf, password, role } = req.body;

      if (!['cliente', 'profissional'].includes(role)) {
        return res.status(400).json({ success: false, message: 'Tipo de usuário inválido' });
      }

      const existingByEmail = email ? await User.findByEmail(email) : null;
      const existingByPhone = phone ? await User.findByPhone(phone) : null;

      if (existingByEmail || existingByPhone) {
        return res.status(400).json({
          success: false,
          message: 'Já existe uma conta com este e-mail ou telefone',
        });
      }

      // Anti-fraude: impede recadastro com o mesmo CPF - principalmente
      // relevante para profissional, que agora paga mensalidade; sem essa
      // checagem, alguém desativado por falta de pagamento poderia criar
      // uma conta nova (com e-mail/telefone diferentes) só pra fugir da
      // cobrança. O CPF sozinho já identifica a pessoa.
      if (cpf) {
        const existingByCpf = await User.findByCpf(cpf);
        if (existingByCpf) {
          const message =
            existingByCpf.role === 'profissional'
              ? 'Este CPF já possui um cadastro de profissional. Se sua conta foi desativada por pendência de mensalidade, regularize o pagamento em vez de criar uma nova conta.'
              : 'Este CPF já possui um cadastro nesta plataforma.';
          return res.status(400).json({ success: false, message });
        }
      }

      if (role === 'profissional') {
        const valorBase = Number(req.body.valor_base);
        const valorKm = Number(req.body.valor_km);
        if (!cpf) {
          return res
            .status(400)
            .json({ success: false, message: 'CPF é obrigatório para cadastro de profissional' });
        }
        if (!Number.isFinite(valorBase) || valorBase < 0 || !Number.isFinite(valorKm) || valorKm < 0) {
          return res.status(400).json({
            success: false,
            message: 'Informe o valor da taxa base e do valor por km que você cobra',
          });
        }
      }

      const userId = await User.create({ role, name, email, phone, cpf, password });
      const user = await User.findById(userId);

      if (role === 'profissional') {
        await Professional.create({
          user_id: userId,
          especialidade: req.body.especialidade || 'Mecânico',
          tipo_veiculo_atendido: req.body.tipo_veiculo_atendido || 'Leve',
          valor_base: req.body.valor_base,
          valor_km: req.body.valor_km,
        });
      } else {
        await Client.create({
          user_id: userId,
          tipo_veiculo_preferido: req.body.tipo_veiculo_preferido || null,
        });
      }

      if (email) {
        sendWelcomeEmail(email, name, role).catch((e) =>
          console.error('Falha ao enviar email de boas-vindas:', e.message)
        );
      }

      const { token, refreshToken } = await issueTokenPair(user, req.headers['user-agent']);

      res.status(201).json({
        success: true,
        token,
        refreshToken,
        user: user.toJSON(),
      });
    } catch (error) {
      console.error('Register error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Iniciar processo de login (decide entre senha ou código OTP)
  async startLogin(req, res) {
    try {
      const { identifier, role, preferSms } = req.body;

      const isEmail = isEmailIdentifier(identifier);
      const isPhone = isPhoneIdentifier(identifier);

      let user;
      if (isEmail) user = await User.findByEmail(identifier);
      else if (isPhone) user = await User.findByPhone(identifier);

      if (!user) {
        return res.status(404).json({ success: false, message: 'Usuário não encontrado' });
      }

      if (user.role !== role) {
        return res.status(400).json({ success: false, message: 'Tipo de usuário incorreto' });
      }

      if (preferSms || isPhone) {
        const code = generateNumericCode(4);
        await Verification.create({
          user_id: user.id,
          identifier,
          code,
          type: isPhone ? 'sms' : 'email',
          expiresAt: new Date(Date.now() + OTP_TTL_MS),
        });

        if (isPhone) {
          await sendSMS(identifier, `Seu código de verificação FalaComigo: ${code}`);
        } else {
          await sendVerificationEmail(identifier, code);
        }

        return res.json({ success: true, method: 'sms', message: 'Código enviado' });
      }

      return res.json({ success: true, method: 'password', message: 'Prossiga com a senha' });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Login com senha
  async loginWithPassword(req, res) {
    try {
      const { identifier, password, role } = req.body;

      const user = isEmailIdentifier(identifier)
        ? await User.findByEmail(identifier)
        : await User.findByPhone(identifier);

      if (!user || user.role !== role) {
        return res.status(401).json({ success: false, message: 'Credenciais inválidas' });
      }

      // Proteção contra força bruta: conta temporariamente bloqueada após
      // muitas tentativas erradas seguidas.
      if (user.isLocked()) {
        const minutesLeft = Math.ceil((new Date(user.locked_until) - new Date()) / 60000);
        return res.status(423).json({
          success: false,
          message: `Conta temporariamente bloqueada por excesso de tentativas. Tente novamente em ${minutesLeft} min.`,
        });
      }

      const isValidPassword = await user.verifyPassword(password);
      if (!isValidPassword) {
        await user.registerFailedLogin();
        return res.status(401).json({ success: false, message: 'Senha incorreta' });
      }

      await user.resetFailedLogins();

      // 2FA ativado: não emite o token final ainda. Emite um token
      // temporário (5 min) que só serve para confirmar o código TOTP em
      // /api/auth/2fa/verify-login.
      if (user.hasTwoFactorEnabled()) {
        const pendingToken = generatePending2FAToken({ userId: user.id, role: user.role });
        return res.json({ success: true, requires2FA: true, pendingToken });
      }

      const { token, refreshToken } = await issueTokenPair(user, req.headers['user-agent']);
      res.json({ success: true, token, refreshToken, user: user.toJSON() });
    } catch (error) {
      console.error('Password login error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Verificar código SMS/Email
  async verifyCode(req, res) {
    try {
      const { identifier, code, role } = req.body;

      const verification = await Verification.findValidCode(identifier, code);
      if (!verification) {
        return res.status(400).json({ success: false, message: 'Código inválido ou expirado' });
      }

      let user = isEmailIdentifier(identifier)
        ? await User.findByEmail(identifier)
        : await User.findByPhone(identifier);

      let needsCompleteRegistration = false;

      if (!user) {
        const tempUserId = await User.create({
          role: role || 'cliente',
          name: 'Novo Usuário',
          email: isEmailIdentifier(identifier) ? identifier : null,
          phone: isEmailIdentifier(identifier) ? null : identifier,
          password: null,
        });
        user = await User.findById(tempUserId);
        needsCompleteRegistration = true;

        if (user.role === 'profissional') {
          await Professional.create({
            user_id: user.id,
            especialidade: 'Mecânico',
            tipo_veiculo_atendido: 'Leve',
          });
        } else {
          await Client.create({ user_id: user.id });
        }
      }

      await verification.markAsUsed();

      if (isEmailIdentifier(identifier)) {
        await user.update({ email_verified: true });
      } else {
        await user.update({ phone_verified: true });
      }

      // Login por OTP também respeita 2FA, se o usuário já tiver ativado
      // (ex.: usuário existente que perdeu a senha mas tem 2FA ligado).
      if (!needsCompleteRegistration && user.hasTwoFactorEnabled()) {
        const pendingToken = generatePending2FAToken({ userId: user.id, role: user.role });
        return res.json({ success: true, requires2FA: true, pendingToken });
      }

      const { token, refreshToken } = await issueTokenPair(user, req.headers['user-agent']);

      res.json({
        success: true,
        token,
        refreshToken,
        user: { ...user.toJSON(), needsCompleteRegistration },
      });
    } catch (error) {
      console.error('Verification error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Reenviar código
  async resendCode(req, res) {
    try {
      const { identifier } = req.body;
      if (!identifier) {
        return res.status(400).json({ success: false, message: 'Identificador é obrigatório' });
      }

      const isPhone = isPhoneIdentifier(identifier);
      const code = generateNumericCode(4);

      const user = isEmailIdentifier(identifier)
        ? await User.findByEmail(identifier)
        : await User.findByPhone(identifier);

      await Verification.create({
        user_id: user ? user.id : null,
        identifier,
        code,
        type: isPhone ? 'sms' : 'email',
        expiresAt: new Date(Date.now() + OTP_TTL_MS),
      });

      if (isPhone) {
        await sendSMS(identifier, `Seu código de verificação FalaComigo: ${code}`);
      } else {
        await sendVerificationEmail(identifier, code);
      }

      res.json({ success: true, message: 'Código reenviado' });
    } catch (error) {
      console.error('Resend code error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Troca um refresh token válido por um novo access token (e rotaciona o
  // próprio refresh token, por segurança - cada refresh token só pode ser
  // usado uma vez).
  async refreshAccessToken(req, res) {
    try {
      const { refreshToken } = req.body;
      if (!refreshToken) {
        return res.status(400).json({ success: false, message: 'refreshToken é obrigatório' });
      }

      const session = await Session.findValidByRawToken(refreshToken);
      if (!session) {
        return res.status(401).json({ success: false, message: 'Sessão inválida ou expirada. Faça login novamente.' });
      }

      const user = await User.findById(session.user_id);
      if (!user) {
        return res.status(401).json({ success: false, message: 'Usuário não encontrado' });
      }

      // Rotação: o refresh token usado é revogado e um novo é emitido junto
      // com o novo access token. Se o mesmo refresh token for reaproveitado
      // depois (ex.: token roubado), a tentativa falhará aqui.
      await session.revoke();
      const { token, refreshToken: newRefreshToken } = await issueTokenPair(user, req.headers['user-agent']);

      res.json({ success: true, token, refreshToken: newRefreshToken });
    } catch (error) {
      console.error('Refresh token error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Logout: revoga o refresh token (se enviado) e coloca o access token
  // atual na blacklist, para que pare de funcionar imediatamente em vez de
  // continuar válido até a expiração natural (7 dias).
  async logout(req, res) {
    try {
      const { refreshToken } = req.body;

      if (refreshToken) {
        const session = await Session.findValidByRawToken(refreshToken);
        if (session) await session.revoke();
      }

      if (req.user?.jti) {
        const expiresAt = req.user.exp ? new Date(req.user.exp * 1000) : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        await RevokedToken.revoke(req.user.jti, req.user.userId, expiresAt);
      }

      res.json({ success: true, message: 'Sessão encerrada' });
    } catch (error) {
      console.error('Logout error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Logout em todos os dispositivos: revoga todos os refresh tokens do
  // usuário. Sessões com access token ainda válido em outros aparelhos só
  // param na próxima tentativa de refresh (limitação normal de JWT
  // stateless) - a sessão atual (deste request) é revogada imediatamente.
  async logoutAllDevices(req, res) {
    try {
      await Session.revokeAllForUser(req.user.userId);

      if (req.user?.jti) {
        const expiresAt = req.user.exp ? new Date(req.user.exp * 1000) : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        await RevokedToken.revoke(req.user.jti, req.user.userId, expiresAt);
      }

      res.json({ success: true, message: 'Todas as sessões foram encerradas' });
    } catch (error) {
      console.error('Logout all error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // --- 2FA (TOTP) ---

  // Passo 1: gera um novo segredo e devolve a URI otpauth:// (o app monta o
  // QR code a partir dela) - ainda NÃO ativa o 2FA, só quando o usuário
  // confirmar um código válido em /2fa/enable.
  async setupTwoFactor(req, res) {
    try {
      const user = await User.findById(req.user.userId);
      if (!user) return res.status(404).json({ success: false, message: 'Usuário não encontrado' });

      const secret = generateSecretBase32();
      await user.update({ two_factor_secret: secret });

      const otpauthUrl = buildOtpAuthUri(secret, user.email || user.phone || user.id);

      res.json({ success: true, secret, otpauthUrl });
    } catch (error) {
      console.error('2FA setup error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Passo 2: usuário digita o código gerado pelo app autenticador para
  // provar que configurou certo; só então o 2FA passa a ser exigido no login.
  async enableTwoFactor(req, res) {
    try {
      const { code } = req.body;
      const user = await User.findById(req.user.userId);
      if (!user) return res.status(404).json({ success: false, message: 'Usuário não encontrado' });

      if (!user.two_factor_secret) {
        return res.status(400).json({ success: false, message: 'Execute /2fa/setup antes de ativar' });
      }

      if (!verifyTOTP(user.two_factor_secret, code)) {
        return res.status(400).json({ success: false, message: 'Código inválido' });
      }

      await user.update({ two_factor_enabled: true });
      res.json({ success: true, message: 'Autenticação em duas etapas ativada' });
    } catch (error) {
      console.error('2FA enable error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Desativar 2FA - exige o código TOTP atual (evita que alguém com o
  // celular desbloqueado, mas sem acesso ao app autenticador, desative a
  // proteção).
  async disableTwoFactor(req, res) {
    try {
      const { code } = req.body;
      const user = await User.findById(req.user.userId);
      if (!user) return res.status(404).json({ success: false, message: 'Usuário não encontrado' });

      if (!user.hasTwoFactorEnabled()) {
        return res.json({ success: true, message: '2FA já estava desativado' });
      }

      if (!verifyTOTP(user.two_factor_secret, code)) {
        return res.status(400).json({ success: false, message: 'Código inválido' });
      }

      await user.update({ two_factor_enabled: false, two_factor_secret: null });
      res.json({ success: true, message: 'Autenticação em duas etapas desativada' });
    } catch (error) {
      console.error('2FA disable error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Completa o login quando a conta tem 2FA: recebe o pendingToken emitido
  // por loginWithPassword/verifyCode + o código do app autenticador, e só
  // então emite o par de tokens de acesso definitivo.
  async verifyTwoFactorLogin(req, res) {
    try {
      const { pendingToken, code } = req.body;
      if (!pendingToken || !code) {
        return res.status(400).json({ success: false, message: 'pendingToken e code são obrigatórios' });
      }

      let decoded;
      try {
        decoded = verifyToken(pendingToken);
      } catch {
        return res.status(401).json({ success: false, message: 'Sessão de verificação expirada. Faça login novamente.' });
      }

      if (!decoded.pending2fa) {
        return res.status(400).json({ success: false, message: 'Token inválido para esta operação' });
      }

      const user = await User.findById(decoded.userId);
      if (!user || !user.hasTwoFactorEnabled()) {
        return res.status(400).json({ success: false, message: 'Usuário não encontrado ou 2FA não ativado' });
      }

      if (!verifyTOTP(user.two_factor_secret, code)) {
        return res.status(400).json({ success: false, message: 'Código inválido' });
      }

      const { token, refreshToken } = await issueTokenPair(user, req.headers['user-agent']);
      res.json({ success: true, token, refreshToken, user: user.toJSON() });
    } catch (error) {
      console.error('2FA verify-login error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Cadastro completo (após verificação por OTP, quando o usuário ainda não
  // tinha nome/senha definitivos)
  async completeRegistration(req, res) {
    try {
      const { userId } = req.user;
      const userData = req.body;

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({ success: false, message: 'Usuário não encontrado' });
      }

      await user.update({
        name: userData.name,
        email: userData.email,
        phone: userData.phone,
        cpf: userData.cpf,
      });

      if (userData.password) {
        await user.updatePassword(userData.password);
      }

      if (
        user.role === 'profissional' &&
        (userData.especialidade || userData.tipo_veiculo_atendido || userData.valor_base !== undefined || userData.valor_km !== undefined)
      ) {
        const professional = await Professional.findByUserId(userId);
        if (professional) {
          await professional.update({
            especialidade: userData.especialidade,
            tipo_veiculo_atendido: userData.tipo_veiculo_atendido,
            valor_base: userData.valor_base,
            valor_km: userData.valor_km,
          });
        }
      } else if (user.role === 'cliente' && userData.tipo_veiculo_preferido) {
        const client = await Client.findByUserId(userId);
        if (client) {
          await client.update({ tipo_veiculo_preferido: userData.tipo_veiculo_preferido });
        }
      }

      const { token, refreshToken } = await issueTokenPair(user, req.headers['user-agent']);
      res.json({ success: true, token, refreshToken, user: user.toJSON() });
    } catch (error) {
      console.error('Registration error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }
}

module.exports = new AuthController();
