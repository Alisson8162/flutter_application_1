jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const { query } = require('../config/database');
const Wallet = require('../models/Wallet');

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

describe('Wallet.findOrCreateForUser', () => {
  beforeEach(() => query.mockReset());

  test('retorna a carteira existente sem criar uma nova', async () => {
    query.mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '50.00' }] });
    const wallet = await Wallet.findOrCreateForUser('u1');
    expect(wallet.balance).toBe(50);
    expect(query).toHaveBeenCalledTimes(1);
  });

  test('cria a carteira quando ainda não existe', async () => {
    query
      .mockResolvedValueOnce({ rows: [] }) // SELECT não encontra
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '0.00' }] }); // INSERT
    const wallet = await Wallet.findOrCreateForUser('u1');
    expect(wallet.balance).toBe(0);
    expect(query).toHaveBeenCalledTimes(2);
  });
});

describe('Wallet.debit', () => {
  beforeEach(() => query.mockReset());

  test('recusa quando o saldo é insuficiente (checagem otimista)', async () => {
    query.mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '10.00' }] });
    const result = await Wallet.debit('u1', 50);
    expect(result.success).toBe(false);
    expect(result.message).toMatch(/insuficiente/i);
    // Nem chega a tentar o UPDATE
    expect(query).toHaveBeenCalledTimes(1);
  });

  test('recusa quando o UPDATE atômico não encontra saldo suficiente (concorrência)', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '50.00' }] }) // findOrCreate
      .mockResolvedValueOnce({ rows: [] }); // UPDATE ... AND balance >= $1 não bateu (outra req debitou antes)

    const result = await Wallet.debit('u1', 50);
    expect(result.success).toBe(false);
  });

  test('debita com sucesso e registra a transação', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '100.00' }] })
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '60.00' }] })
      .mockResolvedValueOnce({ rows: [] }); // INSERT wallet_transactions

    const result = await Wallet.debit('u1', 40, { description: 'Pagamento da corrida', rideId: 'ride-1' });

    expect(result.success).toBe(true);
    expect(result.wallet.balance).toBe(60);

    const [sql, params] = query.mock.calls[2];
    expect(sql).toMatch(/INSERT INTO wallet_transactions/);
    expect(params).toEqual(['w1', 40, 'Pagamento da corrida', 'ride-1']);
  });
});

describe('Wallet.credit', () => {
  beforeEach(() => query.mockReset());

  test('credita e registra a transação', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '10.00' }] })
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '30.00' }] })
      .mockResolvedValueOnce({ rows: [] });

    const wallet = await Wallet.credit('u1', 20, { description: 'Recarga via cartão' });
    expect(wallet.balance).toBe(30);

    const [sql, params] = query.mock.calls[2];
    expect(sql).toMatch(/INSERT INTO wallet_transactions/);
    expect(params[1]).toBe(20);
  });
});

const PaymentController = require('../controllers/paymentController');

describe('PaymentController.chargeRideWithWallet', () => {
  beforeEach(() => query.mockReset());

  test('recusa quando a corrida não pertence ao cliente', async () => {
    query.mockResolvedValueOnce({ rows: [{ id: 'ride-1', client_id: 'outro', status: 'completed', payment_status: 'pending' }] });
    const req = { user: { userId: 'u1' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.chargeRideWithWallet(req, res);
    expect(res.statusCode).toBe(403);
  });

  test('recusa com saldo insuficiente (402)', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ id: 'ride-1', client_id: 'u1', status: 'completed', payment_status: 'pending', final_price: 100 }] })
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '10.00' }] });

    const req = { user: { userId: 'u1' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.chargeRideWithWallet(req, res);

    expect(res.statusCode).toBe(402);
    expect(res.body.success).toBe(false);
  });

  test('debita a carteira e marca a corrida como paga via wallet', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ id: 'ride-1', client_id: 'u1', status: 'completed', payment_status: 'pending', final_price: 40 }] })
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '100.00' }] })
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '60.00' }] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ id: 'ride-1', payment_status: 'paid', payment_method: 'wallet' }] }); // ride.update

    const req = { user: { userId: 'u1' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.chargeRideWithWallet(req, res);

    expect(res.body.success).toBe(true);
    expect(res.body.data.balance).toBe(60);
  });
});

describe('PaymentController.refundRideInternal (pago via wallet)', () => {
  beforeEach(() => query.mockReset());

  test('devolve o valor para o saldo em vez de chamar a Stripe', async () => {
    query
      .mockResolvedValueOnce({ rows: [{ id: 'ride-1', client_id: 'u1', payment_status: 'paid', payment_method: 'wallet', final_price: 30 }] }) // Ride.findById
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '10.00' }] }) // findOrCreate (credit)
      .mockResolvedValueOnce({ rows: [{ id: 'w1', user_id: 'u1', balance: '40.00' }] }) // UPDATE balance
      .mockResolvedValueOnce({ rows: [] }) // INSERT wallet_transactions
      .mockResolvedValueOnce({ rows: [{ id: 'ride-1', payment_status: 'refunded' }] }); // ride.update

    const result = await PaymentController.refundRideInternal('ride-1', 'teste');

    expect(result.success).toBe(true);
    expect(result.refundId).toBeNull();

    const creditCall = query.mock.calls.find(([sql]) => sql.includes('balance + $1'));
    expect(creditCall).toBeTruthy();
  });
});
