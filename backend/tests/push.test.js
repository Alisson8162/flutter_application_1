jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const sendEachForMulticast = jest.fn();
const mockMessaging = { sendEachForMulticast };

jest.mock('../config/firebase', () => ({
  isConfigured: jest.fn(() => true),
  getMessaging: jest.fn(() => mockMessaging),
}));

const { query } = require('../config/database');
const { isConfigured, getMessaging } = require('../config/firebase');
const pushService = require('../utils/pushService');
const DeviceToken = require('../models/DeviceToken');
const NotificationController = require('../controllers/notificationController');

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

describe('pushService.sendToUser', () => {
  beforeEach(() => {
    query.mockReset();
    sendEachForMulticast.mockReset();
    isConfigured.mockReturnValue(true);
  });

  test('não faz nada quando o Firebase não está configurado', async () => {
    isConfigured.mockReturnValue(false);
    const result = await pushService.sendToUser('user-1', { title: 't', body: 'b' });
    expect(result.success).toBe(false);
    expect(query).not.toHaveBeenCalled();
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  test('não envia quando o usuário não tem tokens registrados', async () => {
    query.mockResolvedValueOnce({ rows: [] }); // findTokensForUser
    const result = await pushService.sendToUser('user-1', { title: 't', body: 'b' });
    expect(result.sent).toBe(0);
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  test('envia para todos os tokens do usuário', async () => {
    query.mockResolvedValueOnce({ rows: [{ token: 'tok-1' }, { token: 'tok-2' }] });
    sendEachForMulticast.mockResolvedValueOnce({
      successCount: 2,
      responses: [{ success: true }, { success: true }],
    });

    const result = await pushService.sendToUser('user-1', { title: 'Oi', body: 'Mensagem' });

    expect(result.success).toBe(true);
    expect(result.sent).toBe(2);
    expect(sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({ tokens: ['tok-1', 'tok-2'], notification: { title: 'Oi', body: 'Mensagem' } })
    );
  });

  test('remove tokens que a FCM reporta como inválidos', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ token: 'tok-valido' }, { token: 'tok-morto' }] }) // findTokensForUser
      .mockResolvedValueOnce({ rows: [] }); // DELETE dos tokens mortos

    sendEachForMulticast.mockResolvedValueOnce({
      successCount: 1,
      responses: [
        { success: true },
        { success: false, error: { code: 'messaging/registration-token-not-registered' } },
      ],
    });

    await pushService.sendToUser('user-1', { title: 't', body: 'b' });

    // dá um tick para a limpeza best-effort (não aguardada) rodar
    await new Promise((r) => setTimeout(r, 0));

    const deleteCall = query.mock.calls.find(([sql]) => sql.includes('DELETE FROM device_tokens'));
    expect(deleteCall).toBeTruthy();
    expect(deleteCall[1]).toEqual([['tok-morto']]);
  });

  test('não lança quando a FCM falha - devolve success:false', async () => {
    query.mockResolvedValueOnce({ rows: [{ token: 'tok-1' }] });
    sendEachForMulticast.mockRejectedValueOnce(new Error('fcm indisponível'));

    const result = await pushService.sendToUser('user-1', { title: 't', body: 'b' });
    expect(result.success).toBe(false);
  });
});

describe('pushService.sendToUsers', () => {
  beforeEach(() => {
    query.mockReset();
    sendEachForMulticast.mockReset();
    isConfigured.mockReturnValue(true);
  });

  test('busca tokens de vários usuários em uma query só', async () => {
    query.mockResolvedValueOnce({ rows: [{ token: 'a' }, { token: 'b' }] });
    sendEachForMulticast.mockResolvedValueOnce({ successCount: 2, responses: [{ success: true }, { success: true }] });

    await pushService.sendToUsers(['u1', 'u2'], { title: 'Nova corrida', body: 'perto de você' });

    const [sql, params] = query.mock.calls[0];
    expect(sql).toMatch(/token FROM device_tokens WHERE user_id = ANY/);
    expect(params).toEqual([['u1', 'u2']]);
  });

  test('não faz query quando a lista de usuários é vazia', async () => {
    const tokens = await DeviceToken.findTokensForUsers([]);
    expect(tokens).toEqual([]);
    expect(query).not.toHaveBeenCalled();
  });
});

describe('NotificationController', () => {
  beforeEach(() => query.mockReset());

  test('registerToken recusa sem token', async () => {
    const req = { body: {}, user: { userId: 'u1' } };
    const res = mockRes();
    await NotificationController.registerToken(req, res);
    expect(res.statusCode).toBe(400);
  });

  test('registerToken salva o token do usuário autenticado', async () => {
    query.mockResolvedValueOnce({ rows: [] });
    const req = { body: { token: 'fcm-tok', platform: 'android' }, user: { userId: 'u1' } };
    const res = mockRes();
    await NotificationController.registerToken(req, res);

    expect(res.body.success).toBe(true);
    const [sql, params] = query.mock.calls[0];
    expect(sql).toMatch(/INSERT INTO device_tokens/);
    expect(params).toEqual(['u1', 'fcm-tok', 'android']);
  });

  test('unregisterToken remove o token informado', async () => {
    query.mockResolvedValueOnce({ rows: [] });
    const req = { body: { token: 'fcm-tok' }, user: { userId: 'u1' } };
    const res = mockRes();
    await NotificationController.unregisterToken(req, res);

    expect(res.body.success).toBe(true);
    const [sql, params] = query.mock.calls[0];
    expect(sql).toMatch(/DELETE FROM device_tokens WHERE token/);
    expect(params).toEqual(['fcm-tok']);
  });
});
