const { body, validationResult } = require('express-validator');

const validateLogin = [
  body('identifier').notEmpty().withMessage('Email ou telefone é obrigatório'),
  body('role').isIn(['cliente', 'profissional']).withMessage('Tipo de usuário inválido'),
];

const validateVerification = [
  body('identifier').notEmpty().withMessage('Identificador é obrigatório'),
  body('code')
    .isLength({ min: 4, max: 6 })
    .withMessage('Código deve ter entre 4 e 6 dígitos')
    .isNumeric()
    .withMessage('Código deve conter apenas números'),
];

const validateRegistration = [
  body('name')
    .notEmpty()
    .withMessage('Nome é obrigatório')
    .isLength({ min: 2 })
    .withMessage('Nome deve ter pelo menos 2 caracteres'),
  body('email').optional({ nullable: true, checkFalsy: true }).isEmail().withMessage('Email inválido'),
  body('phone')
    .optional({ nullable: true, checkFalsy: true })
    .isMobilePhone('any')
    .withMessage('Telefone inválido'),
  body('password')
    .optional({ nullable: true, checkFalsy: true })
    .isLength({ min: 6 })
    .withMessage('Senha deve ter pelo menos 6 caracteres'),
  body('role').isIn(['cliente', 'profissional']).withMessage('Tipo de usuário inválido'),
];

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Dados de entrada inválidos',
      errors: errors.array(),
    });
  }
  next();
};

module.exports = {
  validateLogin,
  validateVerification,
  validateRegistration,
  handleValidationErrors,
};
