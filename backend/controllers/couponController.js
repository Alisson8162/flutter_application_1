const Coupon = require('../models/Coupon');

class CouponController {
  // Cliente digita um código antes de confirmar a corrida - valida e
  // devolve o valor do desconto SEM consumir o cupom ainda (o consumo de
  // verdade só acontece se a corrida for criada - ver RideController).
  async validateCoupon(req, res) {
    try {
      const { code, ride_value } = req.body;
      const { userId } = req.user;

      if (!code || ride_value == null) {
        return res.status(400).json({ success: false, message: 'code e ride_value são obrigatórios' });
      }

      const coupon = await Coupon.findByCode(code);
      if (!coupon) {
        return res.status(404).json({ success: false, message: 'Cupom não encontrado' });
      }

      const check = await coupon.validateFor(userId, Number(ride_value));
      if (!check.valid) {
        return res.status(400).json({ success: false, message: check.message });
      }

      const discount = coupon.calculateDiscount(Number(ride_value));

      res.json({
        success: true,
        data: {
          code: coupon.code,
          description: coupon.description,
          discount,
          finalPrice: Number(ride_value) - discount,
        },
      });
    } catch (error) {
      console.error('Validate coupon error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  // --- Administração (painel admin) ---

  async createCoupon(req, res) {
    try {
      const { code, description, discount_type, discount_value, min_ride_value, max_uses, max_uses_per_client, valid_from, valid_until } = req.body;

      if (!code || !discount_type || discount_value == null) {
        return res.status(400).json({ success: false, message: 'code, discount_type e discount_value são obrigatórios' });
      }
      if (!['percentage', 'fixed'].includes(discount_type)) {
        return res.status(400).json({ success: false, message: "discount_type deve ser 'percentage' ou 'fixed'" });
      }

      const existing = await Coupon.findByCode(code);
      if (existing) {
        return res.status(400).json({ success: false, message: 'Já existe um cupom com este código' });
      }

      const coupon = await Coupon.create({
        code,
        description,
        discount_type,
        discount_value,
        min_ride_value,
        max_uses,
        max_uses_per_client,
        valid_from,
        valid_until,
      });

      res.status(201).json({ success: true, data: coupon });
    } catch (error) {
      console.error('Create coupon error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  async listCoupons(req, res) {
    try {
      const coupons = await Coupon.findAll();
      res.json({ success: true, data: coupons });
    } catch (error) {
      console.error('List coupons error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }

  async setCouponActive(req, res) {
    try {
      const { id } = req.params;
      const { active } = req.body;
      await Coupon.setActive(id, active !== false);
      res.json({ success: true });
    } catch (error) {
      console.error('Set coupon active error:', error);
      res.status(500).json({ success: false, message: 'Erro interno do servidor' });
    }
  }
}

module.exports = new CouponController();
