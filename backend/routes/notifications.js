const express = require('express');
const NotificationController = require('../controllers/notificationController');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

router.post('/register-token', authenticate, NotificationController.registerToken);
router.post('/unregister-token', authenticate, NotificationController.unregisterToken);

module.exports = router;
