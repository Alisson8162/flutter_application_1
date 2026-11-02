jest.mock('../config/database', () => ({
  query: jest.fn(),
}));

const { query } = require('../config/database');
const Coupon = require('../models/Coupon');
const CouponController = require('../controllers/couponController');

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

function makeCoupon(overrides = {}) {
  return new Coupon({
    id: 'coupon-1',
    code: 'PROMO10',
    discount_type: 'percentage',
    discount_value: 10,
    min_ride_value: 0,
    max_uses: null,
    uses_count: 0,
    max_uses_per_client: 1,
    valid_from: null,
    valid_until: null,
    active: true,
    ...overrides,
  });
}

describe('Coupon.validateFor', () => {
  beforeEach(() => query.mockReset());

  test('recusa cupom inativo', async () => {
    const coupon = makeCoupon({ active: false });
    const result = await coupon.validateFor('client-1', 100);
    expect(result.valid).toBe(false);
    expect(result.message).toMatch(/inativo/i);
  });

  test('recusa cupom expirado', async () => {
    const coupon = makeCoupon({ valid_until: new Date(Date.now() - 1000) });
    const result = await coupon.validateFor('client-1', 100);
    expect(result.valid).toBe(false);
    expect(result.message).toMatch(/expirado/i);
  });

  test('recusa cupom ainda não iniciado', async () => {
    const coupon = makeCoupon({ valid_from: new Date(Date.now() + 100000) });
    const result = await coupon.validateFor('client-1', 100);
    expect(result.valid).toBe(false);
    expect(result.message).toMatch(/ainda não/i);
  });

  test('recusa quando atingiu o limite global de usos', async () => {
    const coupon = makeCoupon({ max_uses: 5, uses_count: 5 });
    const result = await coupon.validateFor('client-1', 100);
    expect(result.valid).toBe(false);
    expect(result.message).toMatch(/limite/i);
  });

  test('recusa quando o valor da corrida é menor que o mínimo', async () => {
    const coupon = makeCoupon({ min_ride_value: 50 });
    const result = await coupon.validateFor('client-1', 30);
    expect(result.valid).toBe(false);
    expect(result.message).toMatch(/mínimo/i);
  });

  test('recusa quando o cliente já usou o máximo de vezes permitido', async () => {
    query.mockResolvedValueOnce({ rows: [{ count: 1 }] });
    const coupon = makeCoupon({ max_uses_per_client: 1 });
    const result = await coupon.validateFor('client-1', 100);
    expect(result.valid).toBe(false);
    expect(result.message).toMatch(/já utilizou/i);
  });

  test('aceita quando todas as condições são satisfeitas', async () => {
    query.mockResolvedValueOnce({ rows: [{ count: 0 }] });
    const coupon = makeCoupon();
    const result = await coupon.validateFor('client-1', 100);
    expect(result.valid).toBe(true);
  });
});

describe('Coupon.calculateDiscount', () => {
  test('percentual', () => {
    const coupon = makeCoupon({ discount_type: 'percentage', discount_value: 20 });
    expect(coupon.calculateDiscount(100)).toBe(20);
  });

  test('valor fixo', () => {
    const coupon = makeCoupon({ discount_type: 'fixed', discount_value: 15 });
    expect(coupon.calculateDiscount(100)).toBe(15);
  });

  test('nunca desconta mais que o valor da corrida', () => {
    const coupon = makeCoupon({ discount_type: 'fixed', discount_value: 999 });
    expect(coupon.calculateDiscount(50)).toBe(50);
  });
});

describe('CouponController.validateCoupon', () => {
  beforeEach(() => query.mockReset());

  test('recusa sem code ou ride_value', async () => {
    const req = { body: {}, user: { userId: 'u1' } };
    const res = mockRes();
    await CouponController.validateCoupon(req, res);
    expect(res.statusCode).toBe(400);
  });

  test('404 quando o cupom não existe', async () => {
    query.mockResolvedValueOnce({ rows: [] });
    const req = { body: { code: 'NAOEXISTE', ride_value: 100 }, user: { userId: 'u1' } };
    const res = mockRes();
    await CouponController.validateCoupon(req, res);
    expect(res.statusCode).toBe(404);
  });

  test('retorna o desconto calculado para um cupom válido', async () => {
    query
      .mockResolvedValueOnce({
        rows: [{
          id: 'coupon-1', code: 'PROMO10', discount_type: 'percentage', discount_value: 10,
          min_ride_value: 0, max_uses: null, uses_count: 0, max_uses_per_client: 1,
          valid_from: null, valid_until: null, active: true,
        }],
      })
      .mockResolvedValueOnce({ rows: [{ count: 0 }] });

    const req = { body: { code: 'promo10', ride_value: 100 }, user: { userId: 'u1' } };
    const res = mockRes();
    await CouponController.validateCoupon(req, res);

    expect(res.body.success).toBe(true);
    expect(res.body.data.discount).toBe(10);
    expect(res.body.data.finalPrice).toBe(90);
  });
});
