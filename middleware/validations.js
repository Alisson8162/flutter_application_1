const { body, validationResult } = require('express-validator');

// Validar login
const validateLogin = [
  body('identifier')
    .notEmpty()
    .withMessage('Email ou telefone é obrigatório'),
  body('role')
    .isIn(['cliente', 'profissional'])
    .withMessage('Tipo de usuário inválido')
];

// Validar verificação
const validateVerification = [
  body('identifier')
    .notEmpty()
    .withMessage('Identificador é obrigatório'),
  body('code')
    .isLength({ min: 4, max: 6 })
    .withMessage('Código deve ter entre 4 e 6 dígitos')
    .isNumeric()
    .withMessage('Código deve conter apenas números')
];

// Validar cadastro
const validateRegistration = [
  body('name')
    .notEmpty()
    .withMessage('Nome é obrigatório')
    .isLength({ min: 2 })
    .withMessage('Nome deve ter pelo menos 2 caracteres'),
  body('email')
    .isEmail()
    .withMessage('Email inválido'),
  body('phone')
    .isMobilePhone('any')
    .withMessage('Telefone inválido'),
  body('cpf')
    .isLength({ min: 11, max: 14 })
    .withMessage('CPF inválido'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Senha deve ter pelo menos 6 caracteres')
];

// Middleware para verificar erros de validação
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Dados de entrada inválidos',
      errors: errors.array()
    });
  }
  next();
};

module.exports = {
  validateLogin,
  validateVerification, 
  validateRegistration,
  handleValidationErrors
};