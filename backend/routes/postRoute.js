const express = require('express');
const router = express.Router();


const {
    createPost,
    getFeed,
    getPost,
    getUserPost,
    deletePost
} = require('../controllers/postController');
const verifyToken = require('../middlewares/auth');
const upload = require('../middlewares/upload');

router.post('/create', verifyToken, upload.single('image'), createPost);

// '/feed' must be registered before '/:id', or Express matches "feed"
// as an id and getPost runs instead.
router.get('/feed', verifyToken, getFeed);
router.get('/user/:userId', verifyToken, getUserPost);
router.get('/:id', verifyToken, getPost);
router.delete('/:id', verifyToken, deletePost);

module.exports = router;
