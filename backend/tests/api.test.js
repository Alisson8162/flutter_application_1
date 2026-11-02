jest.mock('../config/database', () => ({
  query: jest.fn(),
  pool: { connect: jest.fn(), on: jest.fn() },
  testConnection: jest.fn().mockRejectedValue(new Error('sem banco em teste')),
}));

const request = require('supertest');
const { app } = require('../server');

describe('GET /health', () => {
  test('responde com status 503 quando o banco não está disponível (mockado)', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('Service Unavailable');
  });
});

describe('POST /api/auth/register - validação', () => {
  test('rejeita cadastro sem nome', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'teste@example.com', password: '123456', role: 'cliente' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(Array.isArray(res.body.errors)).toBe(true);
  });

  test('rejeita cadastro com role inválido', async () => {
    const res = await request(app).post('/api/auth/register').send({
      name: 'Maria Silva',
      email: 'teste@example.com',
      password: '123456',
      role: 'admin',
    });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('rejeita senha curta', async () => {
    const res = await request(app).post('/api/auth/register').send({
      name: 'Maria Silva',
      email: 'teste@example.com',
      password: '123',
      role: 'cliente',
    });

    expect(res.status).toBe(400);
  });
});

describe('Rotas protegidas exigem autenticação', () => {
  test('GET /api/users/profile sem token retorna 401', async () => {
    const res = await request(app).get('/api/users/profile');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('GET /api/rides/pending sem token retorna 401', async () => {
    const res = await request(app).get('/api/rides/pending');
    expect(res.status).toBe(401);
  });

  test('token inválido retorna 401', async () => {
    const res = await request(app)
      .get('/api/users/profile')
      .set('Authorization', 'Bearer token-invalido');
    expect(res.status).toBe(401);
  });
});

describe('Rota não encontrada', () => {
  test('retorna 404 para rota inexistente', async () => {
    const res = await request(app).get('/api/rota/que/nao/existe');
    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
  });
});
