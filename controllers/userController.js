const User = require('../models/User');
const Client = require('../models/Client');
const Address = require('../models/Address');
const Document = require('../models/Document');
const PaymentMethod = require('../models/PaymentMethod');
const { uploadToCloudinary } = require('../config/cloudinary');
const { sendWelcomeEmail } = require('../utils/emailService');

class UserController {
  // Obter perfil do usuário
  async getProfile(req, res) {
    try {
      const { userId } = req.user;

      const user = await User.findById(userId);
      
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'Usuário não encontrado'
        });
      }

      let profileData = {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        cpf: user.cpf,
        role: user.role,
        foto_url: user.foto_url,
        email_verified: user.email_verified,
        phone_verified: user.phone_verified,
        created_at: user.created_at
      };

      // Adicionar dados específicos do role
      if (user.role === 'profissional') {
        const Professional = require('../models/Professional');
        const professional = await Professional.findByUserId(userId);
        if (professional) {
          profileData.professional = {
            especialidade: professional.especialidade,
            tipo_veiculo_atendido: professional.tipo_veiculo_atendido,
            disponivel: professional.disponivel,
            documentacao_aprovada: professional.documentacao_aprovada
          };
        }
      } else {
        const client = await Client.findByUserId(userId);
        if (client) {
          profileData.client = {
            tipo_veiculo_preferido: client.tipo_veiculo_preferido
          };
        }
      }

      res.json({
        success: true,
        data: profileData
      });
    } catch (error) {
      console.error('Get profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Atualizar perfil do usuário
  async updateProfile(req, res) {
    try {
      const { userId } = req.user;
      const { name, email, phone, cpf, tipo_veiculo_preferido } = req.body;

      const user = await User.findById(userId);
      
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'Usuário não encontrado'
        });
      }

      // Atualizar dados básicos
      const updates = {};
      if (name) updates.name = name;
      if (email && email !== user.email) {
        updates.email = email;
        updates.email_verified = false; // Requer nova verificação
      }
      if (phone && phone !== user.phone) {
        updates.phone = phone;
        updates.phone_verified = false; // Requer nova verificação
      }
      if (cpf) updates.cpf = cpf;

      if (Object.keys(updates).length > 0) {
        await user.update(updates);
      }

      // Atualizar dados específicos do cliente
      if (user.role === 'cliente' && tipo_veiculo_preferido) {
        const client = await Client.findByUserId(userId);
        if (client) {
          await client.update({ tipo_veiculo_preferido });
        }
      }

      res.json({
        success: true,
        message: 'Perfil atualizado com sucesso'
      });
    } catch (error) {
      console.error('Update profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Upload de documentos
  async uploadDocuments(req, res) {
    try {
      const { userId } = req.user;
      const files = req.files;

      if (!files || Object.keys(files).length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Nenhum arquivo enviado'
        });
      }

      const uploadedDocuments = [];
      const documentTypes = {
        'foto_usuario': 'foto_usuario',
        'documento_frente': 'documento_frente', 
        'documento_verso': 'documento_verso',
        'selfie': 'selfie'
      };

      // Processar cada arquivo
      for (const [fieldName, fileArray] of Object.entries(files)) {
        const documentType = documentTypes[fieldName];
        if (!documentType) continue;

        for (const file of fileArray) {
          const result = await uploadToCloudinary(
            file.buffer, 
            `users/${userId}/${documentType}`
          );

          // Salvar no banco de dados
          const documentId = await Document.create({
            user_id: userId,
            tipo: documentType,
            url: result.secure_url,
            public_id: result.public_id
          });

          // Se for foto de usuário, atualizar no perfil
          if (documentType === 'foto_usuario') {
            const user = await User.findById(userId);
            await user.update({ foto_url: result.secure_url });
          }

          uploadedDocuments.push({
            id: documentId,
            tipo: documentType,
            url: result.secure_url
          });
        }
      }

      res.json({
        success: true,
        message: 'Documentos enviados com sucesso',
        data: uploadedDocuments
      });
    } catch (error) {
      console.error('Upload documents error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
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
        longitude
      });

      res.json({
        success: true,
        message: 'Endereço adicionado com sucesso',
        data: { id: addressId }
      });
    } catch (error) {
      console.error('Add address error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Obter endereço
  async getAddress(req, res) {
    try {
      const { userId } = req.user;

      const address = await Address.findByUserId(userId);

      res.json({
        success: true,
        data: address
      });
    } catch (error) {
      console.error('Get address error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
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
        return res.status(404).json({
          success: false,
          message: 'Endereço não encontrado'
        });
      }

      await address.update(updates);

      res.json({
        success: true,
        message: 'Endereço atualizado com sucesso'
      });
    } catch (error) {
      console.error('Update address error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Obter métodos de pagamento
  async getPaymentMethods(req, res) {
    try {
      const { userId } = req.user;

      // Verificar se é cliente
      const user = await User.findById(userId);
      if (user.role !== 'cliente') {
        return res.status(403).json({
          success: false,
          message: 'Apenas clientes podem ter métodos de pagamento'
        });
      }

      const client = await Client.findByUserId(userId);
      if (!client) {
        return res.status(404).json({
          success: false,
          message: 'Perfil de cliente não encontrado'
        });
      }

      const paymentMethods = await PaymentMethod.findByClientId(client.id);

      res.json({
        success: true,
        data: paymentMethods
      });
    } catch (error) {
      console.error('Get payment methods error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Adicionar método de pagamento
  async addPaymentMethod(req, res) {
    try {
      const { userId } = req.user;
      const { numero_cartao, nome_cartao, validade, cvv } = req.body;

      // Verificar se é cliente
      const user = await User.findById(userId);
      if (user.role !== 'cliente') {
        return res.status(403).json({
          success: false,
          message: 'Apenas clientes podem adicionar métodos de pagamento'
        });
      }

      const client = await Client.findByUserId(userId);
      if (!client) {
        return res.status(404).json({
          success: false,
          message: 'Perfil de cliente não encontrado'
        });
      }

      const paymentMethodId = await PaymentMethod.create({
        client_id: client.id,
        numero_cartao,
        nome_cartao,
        validade,
        cvv
      });

      res.json({
        success: true,
        message: 'Método de pagamento adicionado com sucesso',
        data: { id: paymentMethodId }
      });
    } catch (error) {
      console.error('Add payment method error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }

  // Remover método de pagamento
  async removePaymentMethod(req, res) {
    try {
      const { userId } = req.user;
      const { id } = req.params;

      // Verificar se é cliente
      const user = await User.findById(userId);
      if (user.role !== 'cliente') {
        return res.status(403).json({
          success: false,
          message: 'Apenas clientes podem remover métodos de pagamento'
        });
      }

      const client = await Client.findByUserId(userId);
      if (!client) {
        return res.status(404).json({
          success: false,
          message: 'Perfil de cliente não encontrado'
        });
      }

      const paymentMethod = await PaymentMethod.findById(id);
      if (!paymentMethod || paymentMethod.client_id !== client.id) {
        return res.status(404).json({
          success: false,
          message: 'Método de pagamento não encontrado'
        });
      }

      await PaymentMethod.delete(id);

      res.json({
        success: true,
        message: 'Método de pagamento removido com sucesso'
      });
    } catch (error) {
      console.error('Remove payment method error:', error);
      res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
      });
    }
  }
}

module.exports = new UserController();