-- ============================================================================
-- FalaComigo - Schema PostgreSQL único
--
-- O projeto original mantinha DOIS schemas (MySQL e PostgreSQL) que
-- precisavam ser mantidos manualmente em sincronia. Isso foi eliminado: o
-- backend agora usa exclusivamente PostgreSQL, então este é o ÚNICO schema.
-- Rode com: psql -U postgres -d falacomigo -f scripts/init-postgres.sql
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- necessário para gen_random_uuid()

-- Tipos ENUM
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('cliente', 'profissional');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE vehicle_type AS ENUM ('Leve', 'Pesado', 'Ambos');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE document_type AS ENUM ('foto_usuario', 'documento_frente', 'documento_verso', 'selfie', 'documento_profissional');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- NOVO: comprovação de que o profissional realmente atua na área que
-- declarou (mecânico, eletricista, etc.) - certificado/diploma de curso,
-- página da carteira de trabalho mostrando o registro na função, e foto do
-- veículo usado no atendimento. `ADD VALUE IF NOT EXISTS` é seguro aqui
-- (Postgres 12+) porque nenhuma linha é inserida usando esses valores dentro
-- desta mesma transação de schema.
ALTER TYPE document_type ADD VALUE IF NOT EXISTS 'certificado';
ALTER TYPE document_type ADD VALUE IF NOT EXISTS 'carteira_trabalho';
ALTER TYPE document_type ADD VALUE IF NOT EXISTS 'foto_veiculo';

DO $$ BEGIN
  CREATE TYPE verification_type AS ENUM ('sms', 'email');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE ride_status AS ENUM ('pending', 'accepted', 'in_progress', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Usuários
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role user_role NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    cpf VARCHAR(14) UNIQUE,
    password_hash VARCHAR(255),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    foto_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Clientes
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tipo_veiculo_preferido VARCHAR(100),
    endereco_id UUID,
    stripe_customer_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_clients_user_id ON clients(user_id);

-- Profissionais (inclui colunas de localização em tempo real - ausentes no
-- schema original, adicionadas para permitir busca por proximidade real)
CREATE TABLE IF NOT EXISTS professionals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    especialidade VARCHAR(100) NOT NULL,
    tipo_veiculo_atendido vehicle_type NOT NULL,
    -- NOVO MODELO DE NEGÓCIO: o cliente não paga mais pelo app - quem paga é
    -- o profissional (mensalidade). O valor cobrado do cliente é definido
    -- pelo próprio profissional, como taxa base + valor por km rodado.
    valor_base DECIMAL(8,2) NOT NULL DEFAULT 0,
    valor_km DECIMAL(8,2) NOT NULL DEFAULT 0,
    -- Conta só fica realmente operante (pode ficar `disponivel`) quando
    -- documentacao_aprovada = TRUE (admin) E conta_ativa = TRUE (mensalidade
    -- em dia). Começa FALSE: só vira TRUE quando a primeira cobrança da
    -- assinatura é confirmada pela Stripe (ver professional_subscriptions).
    conta_ativa BOOLEAN DEFAULT FALSE,
    avaliacao_media DECIMAL(3,2) DEFAULT 0.0,
    total_avaliacoes INTEGER DEFAULT 0,
    disponivel BOOLEAN DEFAULT FALSE,
    documentacao_aprovada BOOLEAN DEFAULT FALSE,
    current_latitude DECIMAL(10,8),
    current_longitude DECIMAL(11,8),
    location_updated_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_professionals_user_id ON professionals(user_id);
CREATE INDEX IF NOT EXISTS idx_professionals_especialidade ON professionals(especialidade);
CREATE INDEX IF NOT EXISTS idx_professionals_disponivel ON professionals(disponivel);

-- Assinatura mensal do profissional (é isso que mantém a conta ativa).
-- Um profissional tem no máximo uma assinatura "viva" por vez - por isso
-- professional_id é UNIQUE (a cada nova tentativa de assinatura, a linha é
-- atualizada, não duplicada).
CREATE TABLE IF NOT EXISTS professional_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL UNIQUE REFERENCES professionals(id) ON DELETE CASCADE,
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    stripe_payment_method_id VARCHAR(255),
    -- inactive | active | past_due | canceled
    status VARCHAR(30) NOT NULL DEFAULT 'inactive',
    current_period_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_prof_subscriptions_professional_id ON professional_subscriptions(professional_id);
CREATE INDEX IF NOT EXISTS idx_prof_subscriptions_stripe_sub_id ON professional_subscriptions(stripe_subscription_id);

-- Endereços
CREATE TABLE IF NOT EXISTS addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    estado VARCHAR(2) NOT NULL,
    cidade VARCHAR(100) NOT NULL,
    endereco_completo TEXT NOT NULL,
    bairro VARCHAR(100),
    cep VARCHAR(9),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_addresses_estado_cidade ON addresses(estado, cidade);

-- Métodos de pagamento via Stripe.
-- CORRIGIDO: a versão anterior gerava um hash do número do cartão e do CVV
-- DENTRO do nosso backend, o que exige que o número do cartão em texto puro
-- passe pelo nosso servidor antes de virar hash - problema sério de escopo
-- PCI-DSS. Agora o app confirma o cartão diretamente com a Stripe (SDK
-- flutter_stripe) e o backend armazena apenas o ID do payment method e
-- metadados não sensíveis (bandeira, últimos 4 dígitos, validade).
CREATE TABLE IF NOT EXISTS payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    stripe_payment_method_id VARCHAR(255) NOT NULL UNIQUE,
    brand VARCHAR(50),
    ultimos_quatro VARCHAR(4) NOT NULL,
    exp_month SMALLINT,
    exp_year SMALLINT,
    is_default BOOLEAN DEFAULT FALSE,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_payment_methods_client_id ON payment_methods(client_id);

-- Documentos
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tipo document_type NOT NULL,
    url VARCHAR(500) NOT NULL,
    public_id VARCHAR(255),
    aprovado BOOLEAN DEFAULT FALSE,
    rejeitado BOOLEAN DEFAULT FALSE,
    motivo_rejeicao TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_tipo ON documents(tipo);

-- Verificações (códigos OTP de SMS/e-mail)
CREATE TABLE IF NOT EXISTS verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    identifier VARCHAR(255) NOT NULL,
    code VARCHAR(10) NOT NULL,
    type verification_type NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_verifications_identifier ON verifications(identifier);
CREATE INDEX IF NOT EXISTS idx_verifications_code ON verifications(code);
CREATE INDEX IF NOT EXISTS idx_verifications_expires ON verifications(expires_at);

-- Corridas / atendimentos
CREATE TABLE IF NOT EXISTS rides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id),
    driver_id UUID REFERENCES users(id),
    pickup_location JSONB NOT NULL,
    destination JSONB NOT NULL,
    distance DECIMAL(8,2) NOT NULL,
    estimated_price DECIMAL(8,2) NOT NULL,
    final_price DECIMAL(8,2),
    status ride_status DEFAULT 'pending',
    payment_status VARCHAR(20) DEFAULT 'pending',
    stripe_payment_intent_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    cancelled_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_client_id ON rides(client_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_created_at ON rides(created_at);

-- Avaliações (novo - necessário para o fluxo de "avaliar corrida" do app)
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID NOT NULL UNIQUE REFERENCES rides(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    nota SMALLINT NOT NULL CHECK (nota BETWEEN 1 AND 5),
    comentario TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_reviews_professional_id ON reviews(professional_id);

-- Sessões (reservado para futura denylist/refresh de tokens)
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);

-- Chat da corrida: mensagens trocadas entre cliente e profissional durante
-- uma corrida ativa. Entregues em tempo real pelo mesmo WebSocket que já
-- existia para status/localização (ws/trip/:rideId, tipo "message").
CREATE TABLE IF NOT EXISTS ride_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ride_messages_ride_id ON ride_messages(ride_id, created_at);

-- Cupons de desconto: código, tipo (percentual ou valor fixo), limite de
-- usos totais e por cliente, validade e valor mínimo de corrida.
CREATE TABLE IF NOT EXISTS coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(30) UNIQUE NOT NULL,
    description VARCHAR(255),
    discount_type VARCHAR(10) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(8,2) NOT NULL,
    min_ride_value DECIMAL(8,2) DEFAULT 0,
    max_uses INTEGER,          -- NULL = ilimitado
    uses_count INTEGER DEFAULT 0,
    max_uses_per_client INTEGER DEFAULT 1,
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,     -- NULL = sem validade definida
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Histórico de resgates - permite checar quantas vezes CADA cliente já usou
-- um cupom (max_uses_per_client) além do limite global (max_uses).
CREATE TABLE IF NOT EXISTS coupon_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coupon_id UUID NOT NULL REFERENCES coupons(id),
    client_id UUID NOT NULL REFERENCES users(id),
    ride_id UUID REFERENCES rides(id),
    discount_applied DECIMAL(8,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_coupon ON coupon_redemptions(coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_client ON coupon_redemptions(client_id);

ALTER TABLE rides ADD COLUMN IF NOT EXISTS coupon_id UUID REFERENCES coupons(id);
ALTER TABLE rides ADD COLUMN IF NOT EXISTS discount_applied DECIMAL(8,2) DEFAULT 0;

-- Carteira digital: saldo do cliente, usável como forma de pagamento de
-- corridas (alternativa a cartão/PIX). Todo crédito/débito gera uma linha
-- em wallet_transactions - é o extrato que o app mostra.
CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    type VARCHAR(10) NOT NULL CHECK (type IN ('credit', 'debit')),
    amount DECIMAL(10,2) NOT NULL,
    description VARCHAR(255),
    ride_id UUID REFERENCES rides(id),
    stripe_payment_intent_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet ON wallet_transactions(wallet_id, created_at);

-- Push notifications (FCM): token do dispositivo de cada usuário. Um mesmo
-- usuário pode ter vários dispositivos (celular + tablet, reinstalação
-- gerando token novo, etc.) - por isso o token é a chave única, não o user.
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    platform VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);

-- Administradores (painel /admin de aprovação de documentação).
-- Ficam fora da tabela `users` de propósito: não são clientes nem
-- profissionais, apenas operam o back-office. Crie o primeiro admin com:
--   npm run create-admin -- "Nome" email@exemplo.com senha123
CREATE TABLE IF NOT EXISTS admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- Segurança (adicionado): refresh tokens, blacklist de JWT, 2FA (TOTP) e
-- bloqueio por tentativas de login. Tudo com ALTER/CREATE idempotentes, para
-- rodar com segurança em bancos que já existiam antes desta seção.
-- ============================================================================

-- Refresh tokens: a tabela `sessions` já existia reservada para isso, só
-- faltavam as colunas de controle (revogação, dispositivo, último uso).
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS revoked BOOLEAN DEFAULT FALSE;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS device_info VARCHAR(255);
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);

-- Blacklist de JWT: tokens de acesso revogados explicitamente (logout,
-- logout em todos os dispositivos) antes da sua expiração natural.
CREATE TABLE IF NOT EXISTS revoked_tokens (
    jti UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_revoked_tokens_expires ON revoked_tokens(expires_at);

-- 2FA (TOTP) e bloqueio por tentativas de login, para usuários do app
-- (clientes/profissionais) e para administradores.
ALTER TABLE users ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS two_factor_secret VARCHAR(64);
ALTER TABLE users ADD COLUMN IF NOT EXISTS failed_login_attempts SMALLINT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS locked_until TIMESTAMP;

ALTER TABLE admins ADD COLUMN IF NOT EXISTS failed_login_attempts SMALLINT DEFAULT 0;
ALTER TABLE admins ADD COLUMN IF NOT EXISTS locked_until TIMESTAMP;

-- ============================================================================
-- Pagamentos (adicionado): reembolso. A cobrança automática pós-corrida já
-- existia (payment_status/stripe_payment_intent_id em `rides`); faltava
-- qualquer forma de estornar - nem manual (painel admin) nem automática
-- (corrida cancelada depois de já ter sido cobrada).
-- ============================================================================
ALTER TABLE rides ADD COLUMN IF NOT EXISTS stripe_refund_id VARCHAR(255);
ALTER TABLE rides ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMP;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS refund_reason TEXT;

-- PIX: qual meio foi usado para pagar a corrida ('card' ou 'pix'), para o
-- admin conseguir diferenciar na listagem de corridas.
ALTER TABLE rides ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20);

-- ============================================================================
-- NOVO MODELO DE NEGÓCIO (adicionado): o cliente deixa de pagar pelo app -
-- cada profissional define seu próprio preço (taxa base + valor por km) e
-- paga uma mensalidade para manter a conta ativa. Colunas abaixo cobrem
-- bancos que já existiam antes desta mudança (CREATE TABLE IF NOT EXISTS não
-- adiciona coluna em tabela já existente).
-- ============================================================================
ALTER TABLE professionals ADD COLUMN IF NOT EXISTS valor_base DECIMAL(8,2) NOT NULL DEFAULT 0;
ALTER TABLE professionals ADD COLUMN IF NOT EXISTS valor_km DECIMAL(8,2) NOT NULL DEFAULT 0;
ALTER TABLE professionals ADD COLUMN IF NOT EXISTS conta_ativa BOOLEAN DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS professional_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL UNIQUE REFERENCES professionals(id) ON DELETE CASCADE,
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    stripe_payment_method_id VARCHAR(255),
    status VARCHAR(30) NOT NULL DEFAULT 'inactive',
    current_period_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_prof_subscriptions_professional_id ON professional_subscriptions(professional_id);
CREATE INDEX IF NOT EXISTS idx_prof_subscriptions_stripe_sub_id ON professional_subscriptions(stripe_subscription_id);

-- Anti-fraude: impede que alguém desativado por falta de pagamento crie uma
-- conta nova pra fugir da mensalidade. `users.cpf` já é UNIQUE, então na
-- prática isso já bloqueia reuso de CPF - o que faltava era o backend
-- checar e devolver uma mensagem clara em vez de deixar estourar um erro
-- de violação de constraint (ver authController.register / User.findByCpf).

