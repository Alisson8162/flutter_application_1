# Build de produção do backend FalaComigo (Node.js + Express + PostgreSQL).
#
# Multi-stage: o estágio `deps` instala as dependências (cacheável
# separadamente do resto do código - só reinstala quando package.json muda,
# não a cada alteração de código), e o estágio final copia só o necessário
# para rodar, sem devDependencies nem arquivos de desenvolvimento.
#
# NÃO TESTADO EM EXECUÇÃO: este ambiente de sandbox não tem Docker
# disponível, então este Dockerfile foi escrito seguindo práticas padrão
# (multi-stage, usuário não-root, healthcheck) mas nunca foi de fato
# construído/rodado. Rode `docker build .` e `docker run` no seu ambiente
# antes de usar em produção.

FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
# --omit=dev: só as dependências de produção (sem jest/nodemon/supertest)
RUN npm install --omit=dev --no-audit --no-fund

FROM node:20-alpine AS production
WORKDIR /app

# Usuário não-root - rodar como root dentro do container é desnecessário e
# amplia o impacto de qualquer vulnerabilidade de execução remota.
RUN addgroup -g 1001 -S nodejs && adduser -S falacomigo -u 1001

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# A pasta de uploads temporários (multer) precisa existir e ser gravável
# pelo usuário não-root.
RUN mkdir -p uploads && chown -R falacomigo:nodejs /app

USER falacomigo

ENV NODE_ENV=production
EXPOSE 5000

# O endpoint /health já existe em server.js e não exige autenticação -
# usado aqui e no docker-compose.yml para o orquestrador saber se o
# container está realmente pronto para receber tráfego.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
