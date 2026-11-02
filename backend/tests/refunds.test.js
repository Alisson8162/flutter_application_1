jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const refundsCreate = jest.fn();
const mockStripe = { refunds: { create: refundsCreate } };

jest.mock('../config/stripe', () => ({
  get stripe() {
    return mockStripe;
  },
  isConfigured: jest.fn(() => true),
}));

const { query } = require('../config/database');
const { isConfigured } = require('../config/stripe');
const Ride = require('../models/Ride');
const PaymentController = require('../controllers/paymentController');

describe('PaymentController.refundRideInternal', () => {
  beforeEach(() => {
    query.mockReset();
    refundsCreate.mockReset();
    isConfigured.mockReturnValue(true);
  });

  test('recusa reembolso quando a Stripe não está configurada', async () => {
    isConfigured.mockReturnValue(false);
    const result = await PaymentController.refundRideInternal('ride-1', 'motivo');
    expect(result.success).toBe(false);
    expect(result.message).toMatch(/não configurada/i);
  });

  test('recusa reembolso de corrida inexistente', async () => {
    query.mockResolvedValueOnce({ rows: [] }); // Ride.findById
    const result = await PaymentController.refundRideInternal('ride-x', null);
    expect(result.success).toBe(false);
    expect(result.message).toMatch(/não encontrada/i);
  });

  test('recusa reembolso quando payment_status não é "paid"', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', payment_status: 'pending', stripe_payment_intent_id: 'pi_123' }],
    });
    const result = await PaymentController.refundRideInternal('ride-1', null);
    expect(result.success).toBe(false);
    expect(result.message).toMatch(/pagamento confirmado/i);
    expect(refundsCreate).not.toHaveBeenCalled();
  });

  test('processa o reembolso e atualiza a corrida quando tudo é válido', async () => {
    query
      .mockResolvedValueOnce({
        rows: [{ id: 'ride-1', payment_status: 'paid', stripe_payment_intent_id: 'pi_123' }],
      })
      .mockResolvedValueOnce({
        rows: [{ id: 'ride-1', payment_status: 'refunded', stripe_refund_id: 're_123' }],
      });
    refundsCreate.mockResolvedValueOnce({ id: 're_123' });

    const result = await PaymentController.refundRideInternal('ride-1', 'cliente insatisfeito');

    expect(result.success).toBe(true);
    expect(result.refundId).toBe('re_123');
    expect(refundsCreate).toHaveBeenCalledWith(
      expect.objectContaining({ payment_intent: 'pi_123' })
    );

    // A segunda query deve ser o UPDATE feito por ride.update(...)
    const [updateSql, updateParams] = query.mock.calls[1];
    expect(updateSql).toMatch(/UPDATE rides SET/i);
    expect(updateSql).toContain('payment_status');
    expect(updateSql).toContain('stripe_refund_id');
    expect(updateParams).toContain('refunded');
    expect(updateParams).toContain('re_123');
  });

  test('marca a falha sem lançar exceção quando a Stripe recusa o estorno', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', payment_status: 'paid', stripe_payment_intent_id: 'pi_123' }],
    });
    refundsCreate.mockRejectedValueOnce(new Error('charge already refunded'));

    const result = await PaymentController.refundRideInternal('ride-1', null);

    expect(result.success).toBe(false);
    expect(result.message).toMatch(/charge already refunded/);
  });
});

describe('PaymentController.chargeRide', () => {
  beforeEach(() => {
    query.mockReset();
    isConfigured.mockReturnValue(true);
  });

  test('recusa quando o autenticado não é o cliente da corrida', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', client_id: 'outro-cliente', status: 'completed', payment_status: 'pending' }],
    });

    const req = { user: { userId: 'invasor' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.chargeRide(req, res);

    expect(res.statusCode).toBe(403);
    expect(refundsCreate).not.toHaveBeenCalled();
  });
});

describe('Ride - integração de campos de reembolso', () => {
  beforeEach(() => query.mockReset());

  test('update() aceita os novos campos de reembolso', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', payment_status: 'refunded', stripe_refund_id: 're_1', refunded_at: new Date() }],
    });

    const ride = new Ride({ id: 'ride-1', payment_status: 'paid' });
    await ride.update({
      payment_status: 'refunded',
      stripe_refund_id: 're_1',
      refunded_at: new Date(),
      refund_reason: 'teste',
    });

    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain('payment_status');
    expect(sql).toContain('stripe_refund_id');
    expect(sql).toContain('refunded_at');
    expect(sql).toContain('refund_reason');
    expect(params).toContain('refunded');
    expect(params).toContain('re_1');
    expect(params).toContain('teste');
  });
});
