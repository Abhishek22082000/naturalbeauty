const express = require('express');
const router = express.Router();


const { createPost, getPost, getUserPost, deletePost } = require('../controllers/postController');
const verifyToken = require('../middlewares/auth');
const upload = require('../middlewares/upload');

router.post('/create', verifyToken, upload.single('image'), createPost);

module.exports = router;