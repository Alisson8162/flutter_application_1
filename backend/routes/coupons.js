const express = require('express');
const CouponController = require('../controllers/couponController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

router.post('/validate', authenticate, authorize(['cliente']), CouponController.validateCoupon);

module.exports = router;
