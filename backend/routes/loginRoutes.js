const express = require('express');
const router = express.Router();

const verifyToken = require('../middlewares/auth');
const { login, signup, me } = require('../controllers/authControllers');

router.post('/login', login);
router.post('/signup', signup);
router.get('/me', verifyToken, me);

module.exports = router;
