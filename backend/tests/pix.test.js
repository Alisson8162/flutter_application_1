jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const paymentIntentsCreate = jest.fn();
const customersCreate = jest.fn();
const mockStripe = {
  paymentIntents: { create: paymentIntentsCreate },
  customers: { create: customersCreate },
};

jest.mock('../config/stripe', () => ({
  get stripe() {
    return mockStripe;
  },
  isConfigured: jest.fn(() => true),
}));

const { query } = require('../config/database');
const { isConfigured } = require('../config/stripe');
const PaymentController = require('../controllers/paymentController');

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

describe('PaymentController.createPixCharge', () => {
  beforeEach(() => {
    query.mockReset();
    paymentIntentsCreate.mockReset();
    customersCreate.mockReset();
    isConfigured.mockReturnValue(true);
  });

  test('recusa quando a corrida não pertence ao cliente autenticado', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', client_id: 'outro-cliente', status: 'completed', payment_status: 'pending' }],
    });

    const req = { user: { userId: 'cliente-1' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.createPixCharge(req, res);

    expect(res.statusCode).toBe(403);
    expect(res.body.success).toBe(false);
    expect(paymentIntentsCreate).not.toHaveBeenCalled();
  });

  test('recusa quando a corrida ainda não foi concluída', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', client_id: 'cliente-1', status: 'in_progress', payment_status: 'pending' }],
    });

    const req = { user: { userId: 'cliente-1' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.createPixCharge(req, res);

    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/concluídas/i);
  });

  test('recusa quando a corrida já foi paga', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', client_id: 'cliente-1', status: 'completed', payment_status: 'paid' }],
    });

    const req = { user: { userId: 'cliente-1' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.createPixCharge(req, res);

    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/já foi paga/i);
  });

  test('gera o QR code e salva o payment_intent/payment_method na corrida', async () => {
    // 1) Ride.findById
    query.mockResolvedValueOnce({
      rows: [{
        id: 'ride-1',
        client_id: 'cliente-1',
        status: 'completed',
        payment_status: 'pending',
        final_price: 42.5,
        stripe_customer_id: null,
      }],
    });
    // 2) Client.findByUserId
    query.mockResolvedValueOnce({ rows: [{ id: 'client-row-1', user_id: 'cliente-1', stripe_customer_id: null }] });
    // 3) User.findById
    query.mockResolvedValueOnce({ rows: [{ id: 'cliente-1', name: 'Fulano', email: 'fulano@x.com' }] });
    // 4) UPDATE clients (salvar stripe_customer_id) dentro de _ensureStripeCustomer
    query.mockResolvedValueOnce({ rows: [{ id: 'client-row-1', stripe_customer_id: 'cus_123' }] });
    // 5) UPDATE rides (salvar stripe_payment_intent_id/payment_method)
    query.mockResolvedValueOnce({ rows: [{ id: 'ride-1', stripe_payment_intent_id: 'pi_789', payment_method: 'pix' }] });

    customersCreate.mockResolvedValueOnce({ id: 'cus_123' });
    paymentIntentsCreate.mockResolvedValueOnce({
      id: 'pi_789',
      next_action: {
        pix_display_qr_code: {
          data: '00020126...copia-e-cola...6304ABCD',
          image_url_png: 'https://stripe.com/pix-qr.png',
          expires_at: 1999999999,
        },
      },
    });

    const req = { user: { userId: 'cliente-1' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.createPixCharge(req, res);

    expect(res.body.success).toBe(true);
    expect(res.body.data.qrCodeText).toContain('6304ABCD');
    expect(res.body.data.qrCodeImageUrl).toBe('https://stripe.com/pix-qr.png');
    expect(res.body.data.paymentIntentId).toBe('pi_789');

    expect(paymentIntentsCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        amount: 4250,
        currency: 'brl',
        payment_method_types: ['pix'],
      })
    );
  });

  test('responde com erro claro se a Stripe não devolver os dados do QR code', async () => {
    query.mockResolvedValueOnce({
      rows: [{ id: 'ride-1', client_id: 'cliente-1', status: 'completed', payment_status: 'pending', final_price: 10, stripe_customer_id: 'cus_999' }],
    });
    query.mockResolvedValueOnce({ rows: [{ id: 'client-row-1', user_id: 'cliente-1', stripe_customer_id: 'cus_999' }] });
    query.mockResolvedValueOnce({ rows: [{ id: 'cliente-1', name: 'Fulano' }] });
    query.mockResolvedValueOnce({ rows: [{ id: 'ride-1' }] }); // update da corrida

    paymentIntentsCreate.mockResolvedValueOnce({ id: 'pi_no_qr', next_action: null });

    const req = { user: { userId: 'cliente-1' }, params: { id: 'ride-1' } };
    const res = mockRes();
    await PaymentController.createPixCharge(req, res);

    expect(res.statusCode).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
