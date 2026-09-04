const express = require('express');
const app = express();
const verifyToken = require('../middlewares/auth');
const router = express.Router();
app.use(express.json());


const {login, signup} = require('../controllers/authControllers');
router.post('/login', login);
router.post('/signup', signup);


module.exports = router;