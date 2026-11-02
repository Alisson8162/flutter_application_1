# FalaComigo — Backend

API em Node.js + Express + PostgreSQL para o app de socorro veicular
("Uber para mecânico/guincho"). Este backend foi reescrito a partir do
projeto original para corrigir bugs que impediam o servidor de sequer subir.

## Principais correções feitas nesta revisão

1. **`server.js` usava `app` antes de declará-lo** → corrigido (crash na inicialização).
2. **Backend dependia de dois bancos (MySQL + PostgreSQL) ao mesmo tempo**,
   com cada model duplicando SQL para os dois dialetos → consolidado em
   **PostgreSQL único**, eliminando toda a complexidade e os bugs de
   conversão de placeholders (`?` → `$1, $2...`).
3. **`User.update()` alterava a tabela errada** (`addresses` em vez de
   `users`, copiado por engano de outro model) → corrigido.
4. **`nodemailer.createTransporter` não existe** (é `createTransport`) →
   corrigido; e-mails agora são enviados (ou simulados no console se as
   credenciais SMTP não estiverem configuradas).
5. **`require()` apontando para arquivos/classes com nomes errados**
   (`professionalController` vs. `profissionalController.js`,
   `rideController` vs. `rideContoller.js`, `middleware/validation` vs.
   `validations.js`) → nomes de arquivo padronizados e imports corrigidos.
6. **Rotas de `rides` e `location` nunca eram registradas** no servidor →
   corrigido; todas as rotas agora são montadas em `server.js`.
7. **Localização do profissional nunca era persistida** (só um
   `console.log`) → agora é gravada em `professionals.current_latitude/
   current_longitude` e usada de fato na busca por proximidade.
8. **Métodos chamados pelas rotas que não existiam nos controllers**
   (`resendCode`, `logout`, `uploadProfessionalDocuments`,
   `getDocumentStatus`, `getReviews`, `earnings`) → implementados.
9. Adicionado um **model e tabela de avaliações (`reviews`)**, ausente no
   projeto original mas necessário para o fluxo "avaliar corrida".
10. Adicionado um **servidor WebSocket** (`/ws/trip/:rideId`) para status de
    corrida e localização em tempo real — o app Flutter já tinha um cliente
    WebSocket (`ws_service.dart`) apontando para um domínio de exemplo, mas
    o backend não tinha nenhum servidor correspondente.

## Setup

```bash
cp .env.example .env
# edite o .env com as credenciais do seu PostgreSQL, JWT_SECRET, Stripe, etc.

npm install
psql -U postgres -c "CREATE DATABASE falacomigo;"
npm run db:init          # aplica scripts/init-postgres.sql

npm run create-admin -- "Seu Nome" admin@falacomigo.com senha-forte
# cria a conta usada para logar em /admin

npm run dev   # desenvolvimento (nodemon)
npm start     # produção
npm test      # roda a suíte de testes automatizados (Jest + Supertest)
```

Teste rápido: `GET http://localhost:5000/health`
Painel administrativo: `http://localhost:5000/admin`

## Pagamentos (Stripe)

O fluxo de cartão nunca passa pelo nosso backend: o app usa o SDK da Stripe
(`flutter_stripe`) para coletar o cartão e confirmar diretamente com a
Stripe. O backend só recebe de volta um `payment_method_id`.

1. Crie uma conta em https://dashboard.stripe.com e pegue as chaves de teste
   em *Developers → API keys*.
2. Preencha `STRIPE_SECRET_KEY` e `STRIPE_PUBLISHABLE_KEY` no `.env` do
   backend (a publishable key também vai no app Flutter, ver seu README).
3. Para testar o webhook localmente, use o Stripe CLI:
   ```bash
   stripe listen --forward-to localhost:5000/api/payments/webhook
   ```
   Isso imprime um `whsec_...` — coloque em `STRIPE_WEBHOOK_SECRET`.
4. Sem `STRIPE_SECRET_KEY` configurada, os endpoints de pagamento respondem
   `503` de forma controlada (não derrubam o servidor).

## Painel administrativo (aprovação de documentação)

Servido estaticamente em `/admin` (HTML/JS puro, sem build). Permite:
- Ver profissionais com documentação pendente e visualizar cada documento
  enviado (fotos/CNH/documento do veículo).
- Aprovar ou rejeitar documento por documento, com motivo opcional.
- Aprovar ou reprovar o profissional como um todo (libera/bloqueia
  `disponivel`/`documentacao_aprovada`).
- Ver as corridas mais recentes (monitoramento/suporte).

Administradores ficam em uma tabela própria (`admins`), separada de
`users` — crie a primeira conta com `npm run create-admin`.

## Testes automatizados

```bash
npm test
```

Usa Jest + Supertest. Os testes de API mockam `config/database` (nenhum
Postgres real é necessário para rodar a suíte) e cobrem:
- `tests/helpers.test.js`: validação de CPF, cálculo de distância, geração
  de código OTP (funções puras).
- `tests/models.User.test.js`: garante que `User.update()` grava na tabela
  `users` — teste de regressão direto para o bug original que gravava em
  `addresses`.
- `tests/api.test.js`: validação de entrada, autenticação obrigatória em
  rotas protegidas, e rota 404.

O projeto original não tinha nenhum teste automatizado.

## Infraestrutura (Docker, Redis, CI/CD, Sentry)

**Nada disto foi testado em execução** neste ambiente (sem Docker, sem
acesso à rede) — a sintaxe foi revisada à mão, mas rode localmente antes de
confiar em produção.

### Docker

```bash
cp .env.example .env    # preencha JWT_SECRET e o que mais for usar
docker compose up --build
docker compose exec backend npm run db:init
docker compose exec backend npm run create-admin -- "Nome" email@x.com senha123
```

Sobe o backend + PostgreSQL + Redis. `Dockerfile` é multi-stage, roda como
usuário não-root e expõe um healthcheck em `/health`.

### Redis

Usado hoje só para uma coisa: o *store* do rate limiter (`config/redis.js`,
`utils/rateLimitStore.js`). Sem `REDIS_URL` definida, cada instância do
backend guarda seus próprios contadores em memória — funciona normalmente
com uma única instância, mas os limites deixam de valer "de verdade" se
você rodar mais de uma instância atrás de um load balancer sem Redis.

### CI/CD

`.github/workflows/ci.yml` roda `npm test` a cada push/PR que toque em
`backend/`, e depois valida que a imagem Docker builda (sem publicar). Para
publicar automaticamente em um registry, veja os passos comentados no fim
do arquivo.

### Sentry (monitoramento de erros)

Sem `SENTRY_DSN` definida, nada é inicializado — erros continuam só sendo
logados no console, como sempre foi. Com a DSN configurada
(`config/sentry.js`), o error handler central do Express (fim de
`server.js`) e exceções não tratadas (`uncaughtException`/
`unhandledRejection`) passam a ser reportados.

**Limitação importante:** a maioria dos controllers deste projeto captura
e responde seus próprios erros (`try/catch` com `res.status(500).json(...)`
direto), sem chamar `next(error)` — então esses erros específicos não
passam pelo error handler central e não chegam ao Sentry automaticamente.
Cobertura completa exigiria adicionar `sentry.captureException(error)` em
cada bloco `catch` (dezenas de arquivos) ou refatorar para um padrão
`asyncHandler` que sempre propaga pro middleware central — nenhuma das
duas foi feita aqui por ser uma mudança grande demais para incluir de
passagem.

## Estrutura

```
config/        conexão com PostgreSQL, Cloudinary e Stripe
controllers/    lógica de negócio de cada recurso
middleware/     autenticação (JWT), upload (multer), validação de entrada
models/         acesso a dados (uma classe por tabela)
routes/         definição dos endpoints REST
utils/          helpers (JWT, CPF, e-mail, SMS, distância, realtime/WS)
scripts/        schema SQL, criação de admin, migração
public/admin/   painel administrativo estático (HTML/CSS/JS puro)
tests/          testes automatizados (Jest + Supertest)
```

## Principais endpoints

| Método | Rota                                   | Descrição                                    |
|--------|-----------------------------------------|-----------------------------------------------|
| POST   | /api/auth/register                     | Cadastro (cliente ou profissional)            |
| POST   | /api/auth/login/start                  | Inicia login (decide senha ou OTP)            |
| POST   | /api/auth/login/password                | Login com senha                               |
| POST   | /api/auth/verify                       | Verifica código OTP                           |
| POST   | /api/auth/resend-code                  | Reenvia código OTP                            |
| POST   | /api/auth/logout                       | Logout                                        |
| GET/PUT| /api/users/profile                     | Perfil do usuário autenticado                 |
| POST   | /api/users/documents                   | Upload de documentos (cliente)                |
| GET/POST/PUT | /api/users/address               | Endereço do usuário                           |
| GET    | /api/professionals/search              | Buscar profissionais                          |
| GET/PUT| /api/professionals/profile             | Perfil profissional                           |
| PUT    | /api/professionals/availability        | Ficar online/offline                          |
| GET    | /api/professionals/earnings            | Resumo de ganhos                              |
| GET    | /api/professionals/:id/reviews         | Avaliações recebidas                          |
| POST   | /api/rides                             | Cliente solicita corrida                      |
| GET    | /api/rides/pending                     | Profissional lista corridas pendentes         |
| GET    | /api/rides/active                      | Corrida ativa do usuário logado               |
| POST   | /api/rides/:id/accept                  | Profissional aceita                           |
| POST   | /api/rides/:id/start                   | Profissional inicia atendimento               |
| POST   | /api/rides/:id/complete                | Profissional finaliza (dispara cobrança automática) |
| POST   | /api/rides/:id/cancel                  | Cliente ou profissional cancela               |
| POST   | /api/rides/:id/review                  | Cliente avalia a corrida concluída            |
| POST   | /api/location/update                   | Profissional atualiza localização             |
| GET    | /api/location/nearby                   | Cliente busca profissionais próximos          |
| POST   | /api/payments/setup-intent             | Inicia cadastro de cartão (Stripe SetupIntent) |
| POST   | /api/payments/confirm-method           | Confirma/salva o cartão após o SDK da Stripe   |
| GET    | /api/payments/methods                  | Lista cartões salvos do cliente               |
| PUT    | /api/payments/methods/:id/default      | Define cartão padrão                          |
| DELETE | /api/payments/methods/:id              | Remove cartão                                 |
| POST   | /api/payments/rides/:id/charge         | Cobra manualmente uma corrida concluída       |
| POST   | /api/payments/webhook                  | Webhook da Stripe                             |
| POST   | /api/admin/login                       | Login do painel administrativo                |
| GET    | /api/admin/professionals/pending       | Lista profissionais pendentes de aprovação    |
| POST   | /api/admin/professionals/:id/approve   | Aprova profissional                           |
| POST   | /api/admin/professionals/:id/reject    | Reprova profissional                          |
| POST   | /api/admin/documents/:id/approve       | Aprova documento individual                   |
| POST   | /api/admin/documents/:id/reject        | Rejeita documento individual                  |
| GET    | /api/admin/rides/recent                | Corridas recentes (monitoramento)             |

## Limitações conhecidas / próximos passos recomendados

- **SMS real**: sem `TWILIO_*` configurado, o envio é apenas simulado
  (log no console). Configure o `.env` para envio real.
- **Rate limiting / segurança**: revisar limites de requisição por rota
  sensível (login, verify) antes de produção, para mitigar força bruta.
- **Cobrança automática**: hoje é "best-effort" (não bloqueia a resposta ao
  profissional se falhar); vale adicionar uma fila/retry (ex.: BullMQ) para
  tentar novamente cobranças que falharam por instabilidade temporária.
