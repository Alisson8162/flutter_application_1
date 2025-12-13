const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Client = require('../models/Client');
const Address = require('../models/Address');

// Rota para cadastro de cliente
router.post('/cadastro', async (req, res) => {
  try {
    const { nome, email, telefone, cpf, senha, foto_usuario, tipo_veiculo_preferido, 
            foto_documento_frente, foto_documento_verso, foto_selfie, 
            estado, cidade, endereco_completo, bairro, cep, latitude, longitude } = req.body;

    // Verificar se o usuário já existe
    const existingUser = await User.findByEmail(email);
    if (existingUser) {
      return res.status(400).json({ error: 'E-mail já cadastrado.' });
    }

    // Criar usuário
    const userId = await User.create({
      nome,
      email,
      telefone,
      cpf,
      senha, // Em produção, criptografe a senha!
      foto_usuario,
      tipo: 'cliente'
    });

    // Criar endereço
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

    // Criar perfil de cliente
    const clientId = await Client.create({
      user_id: userId,
      tipo_veiculo_preferido,
      foto_documento_frente,
      foto_documento_verso,
      foto_selfie,
      endereco_id: addressId
    });

    res.status(201).json({ 
      message: 'Cliente cadastrado com sucesso!',
      user_id: userId,
      client_id: clientId,
      address_id: addressId
    });
  } catch (error) {
    console.error('Erro no cadastro do cliente:', error);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});

// Rota para obter perfil do cliente
router.get('/perfil/:user_id', async (req, res) => {
  try {
    const { user_id } = req.params;

    const user = await User.findById(user_id);
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    const client = await Client.findByUserId(user_id);
    if (!client) {
      return res.status(404).json({ error: 'Perfil de cliente não encontrado.' });
    }

    const address = await Address.findByUserId(user_id);

    res.json({
      user: {
        id: user.id,
        nome: user.nome,
        email: user.email,
        telefone: user.telefone,
        cpf: user.cpf,
        foto_usuario: user.foto_usuario,
        tipo: user.tipo
      },
      client: {
        id: client.id,
        tipo_veiculo_preferido: client.tipo_veiculo_preferido,
        foto_documento_frente: client.foto_documento_frente,
        foto_documento_verso: client.foto_documento_verso,
        foto_selfie: client.foto_selfie
      },
      address: address ? {
        id: address.id,
        estado: address.estado,
        cidade: address.cidade,
        endereco_completo: address.endereco_completo,
        bairro: address.bairro,
        cep: address.cep,
        latitude: address.latitude,
        longitude: address.longitude
      } : null
    });
  } catch (error) {
    console.error('Erro ao buscar perfil do cliente:', error);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});

// Rota para atualizar perfil do cliente
router.put('/perfil/:user_id', async (req, res) => {
  try {
    const { user_id } = req.params;
    const { nome, email, telefone, cpf, foto_usuario, tipo_veiculo_preferido, 
            foto_documento_frente, foto_documento_verso, foto_selfie, 
            estado, cidade, endereco_completo, bairro, cep, latitude, longitude } = req.body;

    const user = await User.findById(user_id);
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    // Atualizar usuário
    await user.update({
      nome,
      email,
      telefone,
      cpf,
      foto_usuario
    });

    // Atualizar cliente
    const client = await Client.findByUserId(user_id);
    if (client) {
      await client.update({
        tipo_veiculo_preferido,
        foto_documento_frente,
        foto_documento_verso,
        foto_selfie
      });
    }

    // Atualizar endereço
    const address = await Address.findByUserId(user_id);
    if (address) {
      await address.update({
        estado,
        cidade,
        endereco_completo,
        bairro,
        cep,
        latitude,
        longitude
      });
    } else {
      // Se não tem endereço, criar um novo
      await Address.create({
        user_id: user_id,
        estado,
        cidade,
        endereco_completo,
        bairro,
        cep,
        latitude,
        longitude
      });
    }

    res.json({ message: 'Perfil atualizado com sucesso!' });
  } catch (error) {
    console.error('Erro ao atualizar perfil do cliente:', error);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});

module.exports = router;