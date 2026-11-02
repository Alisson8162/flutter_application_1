const User = require('../models/User');
const Client = require('../models/Client');
const Professional = require('../models/Professional');
const Address = require('../models/Address');
const Document = require('../models/Document');
const { uploadToCloudinary } = require('../config/cloudinary');

class UserController {
  // Obter perfil do usuário
  async getProfile(req, res) {
    try {
      const { userId } = req.user;
      const user = await User.findById(userId);

      if (!user) {
        return res.status(404).json({ success: false, message: 'Usuário não encontrado' });
      }

      const profileData = user.toJSON();

      if (user.role === 'profissional') {
        const professional = await Professional.findByUserId(userId);
        if (professional) {
          profileData.professional = {
            id: professional.id,
            especialidade: professional.especialidade,
            tipo_veiculo_atendido: professional.tipo_veiculo_atendido,
            valor_base: professional.valor_base,
            valor_km: professional.valor_km,
            conta_ativa: professional.conta_ativa,
            disponivel: professional.disponivel,
            documentacao_aprovada: professional.documentacao_aprovada,
            avaliacao_media: professional.avaliacao_media,
            total_avaliacoes: professional.total_avaliacoes,
          };
        }
      } else {
        const client = await Client.findByUserId(userId);
        if (client) {
          profileData.client = {
            id: client.id,
            tipo_veiculo_preferido: client.tipo_veiculo_preferido,
          };
        }
      }

      res.json({ success: true, data: profileData });
    } catch (error) {
      console.error('Get profile error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Atualizar perfil do usuário
  async updateProfile(req, res) {
    try {
      const { userId } = req.user;
      const { name, email, phone, cpf, tipo_veiculo_preferido } = req.body;

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({ success: false, message: 'Usuário não encontrado' });
      }

      const updates = {};
      if (name) updates.name = name;
      const normalizedEmail = email ? email.trim().toLowerCase() : email;
      if (normalizedEmail && normalizedEmail !== user.email) {
        updates.email = normalizedEmail;
        updates.email_verified = false;
      }
      if (phone && phone !== user.phone) {
        updates.phone = phone;
        updates.phone_verified = false;
      }
      if (cpf) updates.cpf = cpf;

      if (Object.keys(updates).length > 0) {
        await user.update(updates);
      }

      if (user.role === 'cliente' && tipo_veiculo_preferido) {
        const client = await Client.findByUserId(userId);
        if (client) {
          await client.update({ tipo_veiculo_preferido });
        }
      }

      res.json({ success: true, message: 'Perfil atualizado com sucesso' });
    } catch (error) {
      console.error('Update profile error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Upload de documentos (foto do usuário, documentos do veículo, selfie, etc.)
  async uploadDocuments(req, res) {
    try {
      const { userId } = req.user;
      const files = req.files;

      if (!files || Object.keys(files).length === 0) {
        return res.status(400).json({ success: false, message: 'Nenhum arquivo enviado' });
      }

      const validDocumentTypes = [
        'foto_usuario',
        'documento_frente',
        'documento_verso',
        'selfie',
        'documentos_profissionais',
      ];

      const uploadedDocuments = [];

      for (const [fieldName, fileArray] of Object.entries(files)) {
        if (!validDocumentTypes.includes(fieldName)) continue;

        for (const file of fileArray) {
          const result = await uploadToCloudinary(file.buffer, `users/${userId}/${fieldName}`);

          const documentId = await Document.create({
            user_id: userId,
            tipo: fieldName === 'documentos_profissionais' ? 'documento_profissional' : fieldName,
            url: result.secure_url,
            public_id: result.public_id,
          });

          if (fieldName === 'foto_usuario') {
            const user = await User.findById(userId);
            await user.update({ foto_url: result.secure_url });
          }

          uploadedDocuments.push({ id: documentId, tipo: fieldName, url: result.secure_url });
        }
      }

      res.json({
        success: true,
        message: 'Documentos enviados com sucesso',
        data: uploadedDocuments,
      });
    } catch (error) {
      console.error('Upload documents error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Adicionar endereço
  async addAddress(req, res) {
    try {
      const { userId } = req.user;
      const { estado, cidade, endereco_completo, bairro, cep, latitude, longitude } = req.body;

      const addressId = await Address.create({
        user_id: userId,
        estado,
        cidade,
        endereco_completo,
        bairro,
        cep,
        latitude,
        longitude,
      });

      res.status(201).json({
        success: true,
        message: 'Endereço adicionado com sucesso',
        data: { id: addressId },
      });
    } catch (error) {
      console.error('Add address error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Obter endereço
  async getAddress(req, res) {
    try {
      const { userId } = req.user;
      const address = await Address.findByUserId(userId);
      res.json({ success: true, data: address });
    } catch (error) {
      console.error('Get address error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Atualizar endereço
  async updateAddress(req, res) {
    try {
      const { userId } = req.user;
      const { id } = req.params;
      const updates = req.body;

      const address = await Address.findById(id);

      if (!address || address.user_id !== userId) {
        return res.status(404).json({ success: false, message: 'Endereço não encontrado' });
      }

      await address.update(updates);

      res.json({ success: true, message: 'Endereço atualizado com sucesso' });
    } catch (error) {
      console.error('Update address error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // Métodos de pagamento: MOVIDOS para controllers/paymentController.js
  // (rotas /api/payments/*), que usa a Stripe (flutter_stripe no app) em vez
  // de receber o número do cartão diretamente neste backend. Os três
  // métodos que existiam aqui (getPaymentMethods/addPaymentMethod/
  // removePaymentMethod, que recebiam `numero_cartao`/`cvv` em texto puro no
  // corpo da requisição) foram removidos por motivo de segurança - ver
  // PaymentMethod.js e paymentController.js para o fluxo correto.
}

module.exports = new UserController();
