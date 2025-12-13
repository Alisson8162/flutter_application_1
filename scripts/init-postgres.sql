-- Criar tipos ENUM
CREATE TYPE user_role AS ENUM ('cliente', 'profissional');
CREATE TYPE vehicle_type AS ENUM ('Leve', 'Pesado', 'Ambos');
CREATE TYPE document_type AS ENUM ('foto_usuario', 'documento_frente', 'documento_verso', 'selfie', 'documento_profissional');
CREATE TYPE verification_type AS ENUM ('sms', 'email');

-- Tabela de usuários
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role user_role NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE,
    cpf VARCHAR(14) UNIQUE,
    password_hash VARCHAR(255),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    foto_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de clientes
CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tipo_veiculo_preferido VARCHAR(100),
    endereco_id UUID
);

-- Tabela de profissionais
CREATE TABLE professionals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    especialidade VARCHAR(100) NOT NULL,
    tipo_veiculo_atendido vehicle_type NOT NULL,
    avaliacao_media DECIMAL(3,2) DEFAULT 0.0,
    total_avaliacoes INTEGER DEFAULT 0,
    disponivel BOOLEAN DEFAULT TRUE,
    documentacao_aprovada BOOLEAN DEFAULT FALSE
);

-- Tabela de endereços
CREATE TABLE addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    estado VARCHAR(2) NOT NULL,
    cidade VARCHAR(100) NOT NULL,
    endereco_completo TEXT NOT NULL,
    bairro VARCHAR(100) NOT NULL,
    cep VARCHAR(9) NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de métodos de pagamento
CREATE TABLE payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    numero_cartao_hash VARCHAR(255) NOT NULL,
    ultimos_quatro VARCHAR(4) NOT NULL,
    nome_cartao VARCHAR(255) NOT NULL,
    validade VARCHAR(7) NOT NULL,
    cvv_hash VARCHAR(255) NOT NULL,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de documentos
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tipo document_type NOT NULL,
    url VARCHAR(500) NOT NULL,
    public_id VARCHAR(255),
    aprovado BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de verificação
CREATE TABLE verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    identifier VARCHAR(255) NOT NULL,
    code VARCHAR(10) NOT NULL,
    type verification_type NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de sessões
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Criar índices
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_professionals_especialidade ON professionals(especialidade);
CREATE INDEX idx_professionals_disponivel ON professionals(disponivel);
CREATE INDEX idx_verifications_identifier ON verifications(identifier);
CREATE INDEX idx_verifications_code ON verifications(code);
CREATE INDEX idx_verifications_expires ON verifications(expires_at);