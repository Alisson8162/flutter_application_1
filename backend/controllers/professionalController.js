const Professional = require('../models/Professional');
const User = require('../models/User');
const Document = require('../models/Document');
const Review = require('../models/Review');
const { uploadToCloudinary } = require('../config/cloudinary');

class ProfessionalController {
  // Buscar profissionais (público, usado pelo cliente para escolher tipo de serviço)
  async searchProfessionals(req, res) {
    try {
      const { especialidade, estado, cidade } = req.query;
      const professionals = await Professional.findBySpecialtyAndLocation(especialidade, estado, cidade);
      res.json({ success: true, data: professionals });
    } catch (error) {
      console.error('Search professionals error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Perfil do profissional autenticado
  async getProfile(req, res) {
    try {
      const { userId } = req.user;

      const professional = await Professional.findByUserId(userId);
      const user = await User.findById(userId);

      if (!professional || !user) {
        return res.status(404).json({ success: false, message: 'Perfil profissional não encontrado' });
      }

      res.json({
        success: true,
        data: {
          ...user.toJSON(),
          professional: {
            id: professional.id,
            especialidade: professional.especialidade,
            tipo_veiculo_atendido: professional.tipo_veiculo_atendido,
            disponivel: professional.disponivel,
            documentacao_aprovada: professional.documentacao_aprovada,
            avaliacao_media: professional.avaliacao_media,
            total_avaliacoes: professional.total_avaliacoes,
          },
        },
      });
    } catch (error) {
      console.error('Get professional profile error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Atualizar dados profissionais (especialidade, tipo de veículo atendido)
  async updateProfile(req, res) {
    try {
      const { userId } = req.user;
      const { especialidade, tipo_veiculo_atendido, valor_base, valor_km } = req.body;

      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Perfil profissional não encontrado' });
      }

      await professional.update({ especialidade, tipo_veiculo_atendido, valor_base, valor_km });

      res.json({ success: true, message: 'Perfil atualizado com sucesso' });
    } catch (error) {
      console.error('Update professional profile error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Atualizar disponibilidade (online/offline para receber corridas)
  async updateAvailability(req, res) {
    try {
      const { userId } = req.user;
      const { disponivel } = req.body;

      const professional = await Professional.findByUserId(userId);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Perfil profissional não encontrado' });
      }

      // Ficar online (disponivel = true) exige documentação aprovada pelo
      // admin E mensalidade em dia. Ficar offline (disponivel = false)
      // nunca é bloqueado - a pessoa sempre pode se desconectar.
      if (Boolean(disponivel)) {
        if (!professional.documentacao_aprovada) {
          return res.status(403).json({
            success: false,
            message: 'Sua documentação ainda está em análise. Você poderá ficar online assim que for aprovada.',
            code: 'DOCUMENTACAO_PENDENTE',
          });
        }
        if (!professional.conta_ativa) {
          return res.status(403).json({
            success: false,
            message: 'Sua assinatura mensal não está ativa. Regularize o pagamento para ficar disponível.',
            code: 'ASSINATURA_INATIVA',
          });
        }
      }

      await professional.update({ disponivel: Boolean(disponivel) });

      res.json({ success: true, message: 'Disponibilidade atualizada com sucesso', data: { disponivel: professional.disponivel } });
    } catch (error) {
      console.error('Update availability error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Upload de documentos profissionais (CNH, documento do veículo, etc.)
  async uploadProfessionalDocuments(req, res) {
    try {
      const { userId } = req.user;
      const files = req.files;

      if (!files || Object.keys(files).length === 0) {
        return res.status(400).json({ success: false, message: 'Nenhum arquivo enviado' });
      }

      // Campos com nome próprio viram o `tipo` real do documento; qualquer
      // outro campo (ex.: o antigo `documentos_profissionais` genérico) cai
      // em 'documento_profissional' por compatibilidade.
      const knownTypes = ['selfie', 'certificado', 'carteira_trabalho', 'foto_veiculo'];

      const uploaded = [];

      for (const [fieldName, fileArray] of Object.entries(files)) {
        const tipo = knownTypes.includes(fieldName) ? fieldName : 'documento_profissional';

        for (const file of fileArray) {
          const result = await uploadToCloudinary(file.buffer, `professionals/${userId}/${fieldName}`);
          const documentId = await Document.create({
            user_id: userId,
            tipo,
            url: result.secure_url,
            public_id: result.public_id,
          });

          if (fieldName === 'selfie') {
            const user = await User.findById(userId);
            if (user) await user.update({ foto_url: result.secure_url });
          }

          uploaded.push({ id: documentId, tipo, url: result.secure_url });
        }
      }

      res.json({ success: true, message: 'Documentos enviados com sucesso', data: uploaded });
    } catch (error) {
      console.error('Upload professional documents error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Status da análise de documentação
  async getDocumentStatus(req, res) {
    try {
      const { userId } = req.user;

      const documents = await Document.findByUserId(userId);
      const professional = await Professional.findByUserId(userId);

      res.json({
        success: true,
        data: {
          documentacao_aprovada: professional ? professional.documentacao_aprovada : false,
          documentos: documents.map((d) => ({
            id: d.id,
            tipo: d.tipo,
            aprovado: d.aprovado,
            created_at: d.created_at,
          })),
        },
      });
    } catch (error) {
      console.error('Get document status error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Avaliações recebidas por um profissional
  async getReviews(req, res) {
    try {
      const { id } = req.params;
      const { page = 1, limit = 10 } = req.query;

      const reviews = await Review.findByProfessionalId(id, page, limit);

      res.json({ success: true, data: reviews });
    } catch (error) {
      console.error('Get reviews error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Resumo de ganhos do profissional autenticado
  async getEarnings(req, res) {
    try {
      const { userId } = req.user;
      const summary = await Professional.getEarningsSummary(userId);
      res.json({ success: true, data: summary });
    } catch (error) {
      console.error('Get earnings error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }
}

module.exports = new ProfessionalController();
