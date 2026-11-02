const express = require('express');
const WalletController = require('../controllers/walletController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

router.get('/', authenticate, authorize(['cliente']), WalletController.getWallet);
router.post('/add-funds', authenticate, authorize(['cliente']), WalletController.addFunds);

module.exports = router;
