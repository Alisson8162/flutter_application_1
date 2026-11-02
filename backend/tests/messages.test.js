jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const broadcastToRide = jest.fn();
jest.mock('../utils/realtime', () => ({
  broadcastToRide: (...args) => broadcastToRide(...args),
  registerConnection: jest.fn(),
}));

const { query } = require('../config/database');
const MessageController = require('../controllers/messageController');

function mockRes() {
  return {
    statusCode: 200,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

describe('MessageController.sendMessage', () => {
  beforeEach(() => {
    query.mockReset();
    broadcastToRide.mockReset();
  });

  test('recusa mensagem vazia', async () => {
    const req = { params: { id: 'ride-1' }, body: { content: '   ' }, user: { userId: 'u1' } };
    const res = mockRes();
    await MessageController.sendMessage(req, res);
    expect(res.statusCode).toBe(400);
    expect(query).not.toHaveBeenCalled();
  });

  test('recusa mensagem muito longa', async () => {
    const req = { params: { id: 'ride-1' }, body: { content: 'x'.repeat(2001) }, user: { userId: 'u1' } };
    const res = mockRes();
    await MessageController.sendMessage(req, res);
    expect(res.statusCode).toBe(400);
  });

  test('recusa quando o usuário não participa da corrida', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', client_id: 'outro', driver_id: 'outro-2', status: 'accepted' }],
    });
    const req = { params: { id: 'ride-1' }, body: { content: 'oi' }, user: { userId: 'u1' } };
    const res = mockRes();
    await MessageController.sendMessage(req, res);
    expect(res.statusCode).toBe(403);
  });

  test('recusa quando a corrida não está em um status conversável', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', client_id: 'u1', driver_id: 'prof-1', status: 'pending' }],
    });
    const req = { params: { id: 'ride-1' }, body: { content: 'oi' }, user: { userId: 'u1' } };
    const res = mockRes();
    await MessageController.sendMessage(req, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/em andamento/i);
  });

  test('cria a mensagem, faz o broadcast e responde com sucesso', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ id: 'ride-1', client_id: 'u1', driver_id: 'prof-1', status: 'accepted' }] }) // Ride.findById
      .mockResolvedValueOnce({ rows: [{ id: 'msg-1', ride_id: 'ride-1', sender_id: 'u1', content: 'oi', created_at: '2026-01-01' }] }) // RideMessage.create
      .mockResolvedValueOnce({ rows: [{ id: 'u1', name: 'Fulano' }] }); // User.findById

    const req = { params: { id: 'ride-1' }, body: { content: 'oi' }, user: { userId: 'u1' } };
    const res = mockRes();
    await MessageController.sendMessage(req, res);

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.sender_name).toBe('Fulano');
    expect(broadcastToRide).toHaveBeenCalledWith('ride-1', expect.objectContaining({ type: 'message', content: 'oi' }));
  });
});

describe('MessageController.getMessages', () => {
  beforeEach(() => query.mockReset());

  test('recusa quando o usuário não participa da corrida', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', client_id: 'outro', driver_id: 'outro-2' }],
    });
    const req = { params: { id: 'ride-1' }, user: { userId: 'u1' }, query: {} };
    const res = mockRes();
    await MessageController.getMessages(req, res);
    expect(res.statusCode).toBe(403);
  });

  test('retorna o histórico para um participante', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ id: 'ride-1', client_id: 'u1', driver_id: 'prof-1' }] })
      .mockResolvedValueOnce({
        rows: [{ id: 'msg-1', ride_id: 'ride-1', sender_id: 'prof-1', sender_name: 'Carlos', content: 'oi', created_at: '2026-01-01' }],
      });

    const req = { params: { id: 'ride-1' }, user: { userId: 'u1' }, query: {} };
    const res = mockRes();
    await MessageController.getMessages(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].sender_name).toBe('Carlos');
  });
});
