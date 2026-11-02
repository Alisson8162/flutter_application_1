const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Client = require('../models/Client');
const Address = require('../models/Address');
const { generateToken } = require('../utils/helpers');

// ---------------------------------------------------------------------------
// Rota alternativa de cadastro/perfil de cliente (mantida por compatibilidade;
// o fluxo recomendado e usado pelo app é POST /api/auth/register).
//
// BUGS CORRIGIDOS:
// - Os nomes de campo enviados aqui (`nome`, `telefone`, `senha`,
//   `foto_usuario`) não batiam com o que o model `User.create` esperava
//   (`name`, `phone`, `password`), então o cadastro gravava `undefined` no
//   banco. Corrigido para usar os mesmos nomes de coluna do banco (em
//   inglês), aceitando os dois formatos vindos do corpo da requisição.
// - A senha era gravada em texto puro. Agora passa por `User.create`, que
//   sempre faz o hash com bcrypt.
// ---------------------------------------------------------------------------

router.post('/cadastro', async (req, res) => {
  try {
    const body = req.body;
    const name = body.name || body.nome;
    const email = body.email;
    const phone = body.phone || body.telefone;
    const cpf = body.cpf;
    const password = body.password || body.senha;
    const tipo_veiculo_preferido = body.tipo_veiculo_preferido;
    const { estado, cidade, endereco_completo, bairro, cep, latitude, longitude } = body;

    if (!name || !password || (!email && !phone)) {
      return res.status(400).json({ error: 'Nome, senha e (e-mail ou telefone) são obrigatórios.' });
    }

    const existingUser = email ? await User.findByEmail(email) : await User.findByPhone(phone);
    if (existingUser) {
      return res.status(400).json({ error: 'E-mail ou telefone já cadastrado.' });
    }

    const userId = await User.create({ role: 'cliente', name, email, phone, cpf, password });

    let addressId = null;
    if (estado && cidade && endereco_completo) {
      addressId = await Address.create({
        user_id: userId,
        estado,
        cidade,
        endereco_completo,
        bairro,
        cep,
        latitude,
        longitude,
      });
    }

    const clientId = await Client.create({
      user_id: userId,
      tipo_veiculo_preferido,
      endereco_id: addressId,
    });

    const user = await User.findById(userId);
    const token = generateToken({ userId: user.id, role: user.role, email: user.email });

    res.status(201).json({
      message: 'Cliente cadastrado com sucesso!',
      token,
      user_id: userId,
      client_id: clientId,
      address_id: addressId,
    });
  } catch (error) {
    console.error('Erro no cadastro do cliente:', error);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});

// Perfil do cliente por ID (uso administrativo / suporte)
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
      user: user.toJSON(),
      client: {
        id: client.id,
        tipo_veiculo_preferido: client.tipo_veiculo_preferido,
      },
      address: address
        ? {
            id: address.id,
            estado: address.estado,
            cidade: address.cidade,
            endereco_completo: address.endereco_completo,
            bairro: address.bairro,
            cep: address.cep,
            latitude: address.latitude,
            longitude: address.longitude,
          }
        : null,
    });
  } catch (error) {
    console.error('Erro ao buscar perfil do cliente:', error);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});

// Atualizar perfil do cliente por ID (uso administrativo / suporte).
// Para o próprio usuário autenticado atualizar seu perfil, use
// PUT /api/users/profile (rota autenticada).
router.put('/perfil/:user_id', async (req, res) => {
  try {
    const { user_id } = req.params;
    const body = req.body;
    const name = body.name || body.nome;
    const email = body.email;
    const phone = body.phone || body.telefone;
    const cpf = body.cpf;
    const tipo_veiculo_preferido = body.tipo_veiculo_preferido;
    const { estado, cidade, endereco_completo, bairro, cep, latitude, longitude } = body;

    const user = await User.findById(user_id);
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    await user.update({ name, email, phone, cpf });

    const client = await Client.findByUserId(user_id);
    if (client && tipo_veiculo_preferido) {
      await client.update({ tipo_veiculo_preferido });
    }

    if (estado && cidade && endereco_completo) {
      const address = await Address.findByUserId(user_id);
      if (address) {
        await address.update({ estado, cidade, endereco_completo, bairro, cep, latitude, longitude });
      } else {
        await Address.create({
          user_id,
          estado,
          cidade,
          endereco_completo,
          bairro,
          cep,
          latitude,
          longitude,
        });
      }
    }

    res.json({ message: 'Perfil atualizado com sucesso!' });
  } catch (error) {
    console.error('Erro ao atualizar perfil do cliente:', error);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});

module.exports = router;
