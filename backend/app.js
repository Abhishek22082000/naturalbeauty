require('dotenv').config()
const express = require('express');
const path = require('path');
const app  = express();

app.use(express.json());

// Serve uploaded images. Without this, every image_url returns 404 and
// the app shows broken-image placeholders.
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));


const loginRoute = require('./routes/loginRoutes');
const postRoute = require('./routes/postRoute');
const likeRoute = require('./routes/likeRoute');
const leaderboardRoute = require('./routes/leaderboardRoute');

app.use('/auth', loginRoute);
app.use('/posts', postRoute);
app.use('/likes', likeRoute);
app.use('/leaderboard', leaderboardRoute);

app.get('/', (req, res) => {
    res.json({ message: 'API is running' });
});

// Catch-all error handler. Four parameters starting with `err` is what
// marks this as an error handler — miss that and it silently never runs.
// It must be registered last, after every route.
app.use((err, req, res, next) => {
    console.error(err);
    // Multer rejections (file too large, wrong type) are client errors.
    if (err.name === 'MulterError' || err.message) {
        return res.status(400).json({ message: err.message });
    }
    return res.status(500).json({ message: 'Internal server error' });
});

app.listen(3000, '0.0.0.0', () => {
    console.log('Server running on http://0.0.0.0:3000 (reachable on your LAN IP)');
});
