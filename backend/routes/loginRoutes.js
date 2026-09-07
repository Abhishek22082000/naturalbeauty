const express = require('express');
const router = express.Router();

const verifyToken = require('../middlewares/auth');
const upload = require('../middlewares/upload');
const {
    login,
    signup,
    me,
    setAccountPrivacy,
    setProfilePicture,
    removeProfilePicture
} = require('../controllers/authControllers');

router.post('/login', login);
router.post('/signup', signup);

router.get('/me', verifyToken, me);
router.patch('/privacy', verifyToken, setAccountPrivacy);

// Auth runs before multer, so an unauthenticated request is rejected
// before any bytes are written to disk.
router.patch(
    '/profile-picture',
    verifyToken,
    upload.avatar.single('image'),
    setProfilePicture
);
router.delete('/profile-picture', verifyToken, removeProfilePicture);

module.exports = router;
