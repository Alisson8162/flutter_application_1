-- Banco de dados principal
CREATE DATABASE IF NOT EXISTS falacomigo;
USE falacomigo;

-- Tabela de usuários
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    role ENUM('cliente', 'profissional') NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE,
    cpf VARCHAR(14) UNIQUE,
    password_hash VARCHAR(255),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    foto_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_phone (phone),
    INDEX idx_role (role)
);

-- Tabela de clientes
CREATE TABLE clients (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    tipo_veiculo_preferido VARCHAR(100),
    endereco_id VARCHAR(36),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
);

-- Tabela de profissionais
CREATE TABLE professionals (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    especialidade VARCHAR(100) NOT NULL,
    tipo_veiculo_atendido ENUM('Leve', 'Pesado', 'Ambos') NOT NULL,
    avaliacao_media DECIMAL(3,2) DEFAULT 0.0,
    total_avaliacoes INT DEFAULT 0,
    disponivel BOOLEAN DEFAULT TRUE,
    documentacao_aprovada BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_especialidade (especialidade),
    INDEX idx_disponivel (disponivel)
);

-- Tabela de endereços
CREATE TABLE addresses (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id VARCHAR(36) NOT NULL,
    estado VARCHAR(2) NOT NULL,
    cidade VARCHAR(100) NOT NULL,
    endereco_completo TEXT NOT NULL,
    bairro VARCHAR(100) NOT NULL,
    cep VARCHAR(9) NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_estado_cidade (estado, cidade)
);

-- Tabela de métodos de pagamento
CREATE TABLE payment_methods (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    client_id VARCHAR(36) NOT NULL,
    numero_cartao_hash VARCHAR(255) NOT NULL,
    ultimos_quatro VARCHAR(4) NOT NULL,
    nome_cartao VARCHAR(255) NOT NULL,
    validade VARCHAR(7) NOT NULL,
    cvv_hash VARCHAR(255) NOT NULL,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    INDEX idx_client_id (client_id)
);

-- Tabela de documentos
CREATE TABLE documents (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id VARCHAR(36) NOT NULL,
    tipo ENUM('foto_usuario', 'documento_frente', 'documento_verso', 'selfie', 'documento_profissional') NOT NULL,
    url VARCHAR(500) NOT NULL,
    public_id VARCHAR(255),
    aprovado BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_tipo (tipo)
);

-- Tabela de verificação
CREATE TABLE verifications (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id VARCHAR(36),
    identifier VARCHAR(255) NOT NULL,
    code VARCHAR(10) NOT NULL,
    type ENUM('sms', 'email') NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_identifier (identifier),
    INDEX idx_code (code),
    INDEX idx_expires (expires_at)
);

-- Tabela de sessões
CREATE TABLE sessions (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id VARCHAR(36) NOT NULL,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_expires (expires_at)
);


-- Tabela de corridas (adicione tanto no MySQL quanto PostgreSQL)
CREATE TABLE rides (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    client_id VARCHAR(36) NOT NULL,
    driver_id VARCHAR(36),
    pickup_location JSON NOT NULL,
    destination JSON NOT NULL,
    distance DECIMAL(8,2) NOT NULL,
    estimated_price DECIMAL(8,2) NOT NULL,
    final_price DECIMAL(8,2),
    status ENUM('pending', 'accepted', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    FOREIGN KEY (client_id) REFERENCES users(id),
    FOREIGN KEY (driver_id) REFERENCES users(id),
    INDEX idx_status (status),
    INDEX idx_driver_id (driver_id),
    INDEX idx_created_at (created_at)
);