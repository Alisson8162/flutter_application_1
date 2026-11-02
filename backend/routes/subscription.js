const express = require('express');
const SubscriptionController = require('../controllers/subscriptionController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate, authorize(['profissional']));

router.post('/setup-intent', SubscriptionController.createSetupIntent);
router.post('/confirm', SubscriptionController.confirmSubscription);
router.get('/status', SubscriptionController.getStatus);
router.post('/cancel', SubscriptionController.cancelSubscription);

module.exports = router;
