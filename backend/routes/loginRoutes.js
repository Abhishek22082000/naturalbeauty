const express = require('express');
const router = express.Router();

const verifyToken = require('../middlewares/auth');
const {
    login,
    signup,
    me,
    setAccountPrivacy
} = require('../controllers/authControllers');

router.post('/login', login);
router.post('/signup', signup);
router.get('/me', verifyToken, me);
router.patch('/privacy', verifyToken, setAccountPrivacy);

module.exports = router;
