const multer = require('multer');

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Apenas imagens são permitidas'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

// Upload múltiplo de imagens (documentos de cliente)
const uploadImages = upload.fields([
  { name: 'foto_usuario', maxCount: 1 },
  { name: 'documento_frente', maxCount: 1 },
  { name: 'documento_verso', maxCount: 1 },
  { name: 'selfie', maxCount: 1 },
]);

// Upload de documentos profissionais: comprovação de que a pessoa realmente
// atua na especialidade declarada (certificado/diploma do curso e página da
// carteira de trabalho mostrando o registro na função), selfie para a foto
// de perfil, e foto do veículo usado no atendimento.
//
// CORRIGIDO: antes só existia um campo genérico `documentos_profissionais`
// (até 10 arquivos), e o controller gravava todos com o mesmo tipo
// "documento_profissional" - o admin não tinha como saber qual arquivo era
// o quê. Agora cada campo tem nome próprio e vira o `tipo` certo na tabela
// `documents`.
const uploadProfessionalDocs = upload.fields([
  { name: 'selfie', maxCount: 1 },
  { name: 'certificado', maxCount: 1 },
  { name: 'carteira_trabalho', maxCount: 1 },
  { name: 'foto_veiculo', maxCount: 1 },
  // Mantido por compatibilidade com uploads antigos/genéricos.
  { name: 'documentos_profissionais', maxCount: 10 },
]);

module.exports = { uploadImages, uploadProfessionalDocs };
