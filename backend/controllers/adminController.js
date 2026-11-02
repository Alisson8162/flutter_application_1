const Admin = require('../models/Admin');
const Professional = require('../models/Professional');
const Document = require('../models/Document');
const User = require('../models/User');
const Ride = require('../models/Ride');
const Wallet = require('../models/Wallet');
const PaymentController = require('./paymentController');
const { generateToken } = require('../utils/helpers');
const { sendEmail } = require('../utils/emailService');

class AdminController {
  async login(req, res) {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        return res.status(400).json({ success: false, message: 'Email e senha são obrigatórios' });
      }

      const admin = await Admin.findByEmail(email);
      if (!admin) {
        return res.status(401).json({ success: false, message: 'Credenciais inválidas' });
      }

      if (admin.isLocked()) {
        const minutesLeft = Math.ceil((new Date(admin.locked_until) - new Date()) / 60000);
        return res.status(423).json({
          success: false,
          message: `Conta temporariamente bloqueada por excesso de tentativas. Tente novamente em ${minutesLeft} min.`,
        });
      }

      if (!(await admin.verifyPassword(password))) {
        await admin.registerFailedLogin();
        return res.status(401).json({ success: false, message: 'Credenciais inválidas' });
      }

      await admin.resetFailedLogins();

      const token = generateToken({ userId: admin.id, role: 'admin', email: admin.email });

      res.json({ success: true, token, admin: admin.toJSON() });
    } catch (error) {
      console.error('Admin login error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Números gerais para o topo do painel
  async getStats(req, res) {
    try {
      const pendingProfessionals = await Professional.findPendingApproval();
      const pendingDocs = await Document.findPendingCount();

      res.json({
        success: true,
        data: {
          profissionais_pendentes: pendingProfessionals.length,
          documentos_pendentes: pendingDocs,
        },
      });
    } catch (error) {
      console.error('Admin stats error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Lista profissionais aguardando aprovação, com seus documentos
  async listPendingProfessionals(req, res) {
    try {
      const professionals = await Professional.findPendingApproval();

      const withDocuments = await Promise.all(
        professionals.map(async (prof) => {
          const documents = await Document.findByUserId(prof.user_id);
          return { ...prof, documents };
        })
      );

      res.json({ success: true, data: withDocuments });
    } catch (error) {
      console.error('List pending professionals error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Aprova um documento específico
  async approveDocument(req, res) {
    try {
      const { id } = req.params;
      const document = await Document.approve(id);

      if (!document) {
        return res.status(404).json({ success: false, message: 'Documento não encontrado' });
      }

      res.json({ success: true, message: 'Documento aprovado', data: document });
    } catch (error) {
      console.error('Approve document error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Rejeita um documento (o profissional precisará reenviar)
  async rejectDocument(req, res) {
    try {
      const { id } = req.params;
      const { motivo } = req.body;

      const document = await Document.reject(id, motivo);
      if (!document) {
        return res.status(404).json({ success: false, message: 'Documento não encontrado' });
      }

      res.json({ success: true, message: 'Documento rejeitado', data: document });
    } catch (error) {
      console.error('Reject document error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Aprova a documentação do profissional como um todo (libera para atender)
  async approveProfessional(req, res) {
    try {
      const { id } = req.params;

      const professional = await Professional.findById(id);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Profissional não encontrado' });
      }

      await professional.update({ documentacao_aprovada: true });

      const user = await User.findById(professional.user_id);
      if (user?.email) {
        sendEmail(
          user.email,
          'Documentação aprovada - FalaComigo',
          'Sua documentação foi aprovada! Você já pode ficar disponível para atender.'
        ).catch((e) => console.error('Falha ao notificar profissional:', e.message));
      }

      res.json({ success: true, message: 'Profissional aprovado com sucesso' });
    } catch (error) {
      console.error('Approve professional error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Bloqueia/reprova o profissional (ex.: documentação fraudulenta)
  async rejectProfessional(req, res) {
    try {
      const { id } = req.params;

      const professional = await Professional.findById(id);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Profissional não encontrado' });
      }

      await professional.update({ documentacao_aprovada: false, disponivel: false });

      res.json({ success: true, message: 'Profissional reprovado' });
    } catch (error) {
      console.error('Reject professional error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Visão geral de corridas recentes (útil para suporte/monitoramento)
  async listRecentRides(req, res) {
    try {
      const { limit = 50 } = req.query;
      const rides = await Ride.findRecent(Number(limit) || 50);
      res.json({ success: true, data: rides });
    } catch (error) {
      console.error('List recent rides error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Reembolsa uma corrida já cobrada - ação de suporte (cobrança duplicada,
  // serviço não prestado a contento, etc.). Reaproveita a mesma lógica usada
  // pela cobrança/reembolso automáticos, só que disparada manualmente por um
  // administrador.
  async refundRide(req, res) {
    try {
      const { id } = req.params;
      const { reason } = req.body;

      const result = await PaymentController.refundRideInternal(id, reason);
      if (!result.success) {
        return res.status(400).json(result);
      }

      res.json({ success: true, message: 'Reembolso processado com sucesso', data: { refundId: result.refundId } });
    } catch (error) {
      console.error('Admin refund ride error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Crédito manual na carteira digital de um cliente - ex.: compensação por
  // um problema no atendimento que não chegou a virar uma corrida
  // reembolsável, cortesia, etc.
  async creditWallet(req, res) {
    try {
      const { userId } = req.params;
      const { amount, reason } = req.body;
      const value = Number(amount);

      if (!value || value <= 0) {
        return res.status(400).json({ success: false, message: 'Informe um valor válido' });
      }

      const wallet = await Wallet.credit(userId, value, {
        description: reason || 'Crédito manual (suporte)',
      });

      res.json({ success: true, message: 'Saldo creditado com sucesso', data: { balance: wallet.balance } });
    } catch (error) {
      console.error('Admin credit wallet error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }
}

module.exports = new AdminController();
