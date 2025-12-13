const multer = require('multer');
const path = require('path');

// Configuração do multer para upload na memória
const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  // Verificar se é imagem
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Apenas imagens são permitidas'), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  }
});

// Middleware para upload múltiplo de imagens
const uploadImages = upload.fields([
  { name: 'foto_usuario', maxCount: 1 },
  { name: 'documento_frente', maxCount: 1 },
  { name: 'documento_verso', maxCount: 1 },
  { name: 'selfie', maxCount: 1 },
  { name: 'documentos_profissionais', maxCount: 10 }
]);

module.exports = { uploadImages };