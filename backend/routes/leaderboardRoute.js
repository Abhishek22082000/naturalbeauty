const express = require('express');
const router = express.Router();

const { getLeaderboard } = require('../controllers/leaderboardController');
const verifyToken = require('../middlewares/auth');

router.get('/', verifyToken, getLeaderboard);

module.exports = router;
