const User = require('../models/User');
const Professional = require('../models/Professional');
const Client = require('../models/Client');
const Verification = require('../models/Verification');
const { generateToken, verifyToken } = require('../utils/helpers');
const { sendSMS } = require('../utils/smsService');
const { sendEmail } = require('../utils/emailService');

class AuthController {
  // Iniciar processo de login
  async startLogin(req, res) {
    try {
      const { identifier, role, preferSms } = req.body;

      // Verificar se é email ou telefone
      const isEmail = identifier.includes('@');
      const isPhone = /^\+?\d{8,15}$/.test(identifier);

      let user;
      if (isEmail) {
        user = await User.findByEmail(identifier);
      } else if (isPhone) {
        user = await User.findByPhone(identifier);
      }

      // Se usuário não existe e é telefone, criar verificação direta
      if (!user && isPhone) {
        const code = Math.floor(1000 + Math.random() * 9000).toString();
        await Verification.create({
          identifier,
          code,
          type: 'sms',
          expiresAt: new Date(Date.now() + 10 * 60 * 1000) // 10 minutos
        });

        // Enviar SMS (em produção)
        await sendSMS(identifier, `Seu código de verificação FalaComigo: ${code}`);

        return res.json({
          success: true,
          method: 'sms',
          message: 'Código enviado por SMS'
        });
      }

      // Se usuário existe
      if (user) {
        if (user.role !== role) {
          return res.status(400).json({
            success: false,
            message: 'Tipo de usuário incorreto'
          });
        }

        // Decidir método de autenticação
        if (preferSms || isPhone) {
          const code = Math.floor(1000 + Math.random() * 9000).toString();
          await Verification.create({
            userId: user.id,
            identifier,
            code,
            type: 'sms',
            expiresAt: new Date(Date.now() + 10 * 60 * 1000)
          });

          await sendSMS(identifier, `Seu código de verificação FalaComigo: ${code}`);

          return res.json({
            success: true,
            method: 'sms',
            message: 'Código enviado por SMS'
          });
        } else {
          return res.json({
            success: true,
            method: 'password',
            message: 'Proceed with password'
          });
        }
      } else {
        return res.status(404).json({
          success: false,
          message: 'Usuário não encontrado'
        });
      }
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Login com senha
  async loginWithPassword(req, res) {
    try {
      const { identifier, password, role } = req.body;

      let user;
      if (identifier.includes('@')) {
        user = await User.findByEmail(identifier);
      } else {
        user = await User.findByPhone(identifier);
      }

      if (!user || user.role !== role) {
        return res.status(401).json({
          success: false,
          message: 'Credenciais inválidas'
        });
      }

      const isValidPassword = await user.verifyPassword(password);
      if (!isValidPassword) {
        return res.status(401).json({
          success: false,
          message: 'Senha incorreta'
        });
      }

      const token = generateToken({
        userId: user.id,
        role: user.role,
        email: user.email
      });

      res.json({
        success: true,
        token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          foto_url: user.foto_url
        }
      });
    } catch (error) {
      console.error('Password login error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Verificar código SMS/Email
  async verifyCode(req, res) {
    try {
      const { identifier, code, role } = req.body;

      const verification = await Verification.findValidCode(identifier, code);
      if (!verification) {
        return res.status(400).json({
          success: false,
          message: 'Código inválido ou expirado'
        });
      }

      let user;
      if (identifier.includes('@')) {
        user = await User.findByEmail(identifier);
      } else {
        user = await User.findByPhone(identifier);
      }

      // Se usuário não existe (cadastro via SMS)
      if (!user) {
        // Criar usuário temporário (será completado no cadastro)
        const tempUserId = await User.create({
          role,
          name: 'Usuário Temporário',
          email: identifier.includes('@') ? identifier : null,
          phone: identifier.includes('@') ? null : identifier,
          password: 'temp' // Será atualizado depois
        });

        user = await User.findById(tempUserId);
      }

      // Marcar código como usado
      await verification.markAsUsed();

      // Gerar token
      const token = generateToken({
        userId: user.id,
        role: user.role,
        email: user.email
      });

      res.json({
        success: true,
        token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          needsCompleteRegistration: user.name === 'Usuário Temporário'
        }
      });
    } catch (error) {
      console.error('Verification error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Cadastro completo
  async completeRegistration(req, res) {
    try {
      const { userId } = req.user;
      const userData = req.body;

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'Usuário não encontrado'
        });
      }

      // Atualizar dados do usuário
      await user.update({
        name: userData.name,
        email: userData.email,
        phone: userData.phone,
        cpf: userData.cpf
      });

      // Se tiver senha, atualizar
      if (userData.password) {
        const password_hash = await bcrypt.hash(userData.password, 12);
        await user.update({ password_hash });
      }

      // Criar perfil específico
      if (user.role === 'profissional') {
        await Professional.create({
          user_id: userId,
          especialidade: userData.especialidade,
          tipo_veiculo_atendido: userData.tipo_veiculo_atendido
        });
      } else {
        await Client.create({
          user_id: userId
        });
      }

      // Gerar novo token com dados atualizados
      const token = generateToken({
        userId: user.id,
        role: user.role,
        email: user.email
      });

      res.json({
        success: true,
        token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          foto_url: user.foto_url
        }
      });
    } catch (error) {
      console.error('Registration error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }
}

module.exports = new AuthController();