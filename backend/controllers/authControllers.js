const fs = require('fs/promises');
const path = require('path');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const connection = require('../config/connection');


const login = async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ message: 'Email and password required' });
        }

        const [rows] = await connection.query(
            'SELECT * FROM users WHERE email = ?', [email]
        );

        if (rows.length === 0) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        const user = rows[0];
        const match = await bcrypt.compare(password, user.password);
        if (!match) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        const token = jwt.sign(
            { id: user.id, email: user.email },
            process.env.JWT_SECRET,
            { expiresIn: '1h' }
        );

        return res.status(200).json({ message: 'Login successful', token });

    } catch (err) {
        console.error(err);
        return res.status(500).json({ message: 'Something went wrong' });
    }
};


const signup = async (req, res) => {
    try {
        const { username, name, email, password, phone, gender } = req.body;

        // 1. validate
        if (!username || !email || !password) {
            return res.status(400).json({ message: 'Username, email and password are required' });
        }

        if (password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters' });
        }

        // 2. hash
        const hashedPassword = await bcrypt.hash(password, 10);

        // 3. insert
        const [result] = await connection.query(
            'INSERT INTO users (username, full_name, email, password, phone, gender) VALUES (?, ?, ?, ?, ?, ?)',
            [username, name, email, hashedPassword, phone, gender]
        );

        // 4. respond
        return res.status(201).json({
            message: 'User created successfully',
            userId: result.insertId
        });

    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ message: 'Username, email or phone already registered' });
        }
        console.error(err);
        return res.status(500).json({ message: 'Something went wrong' });
    }
};


/**
 * GET /auth/me — the logged-in user's profile.
 *
 * The id comes from the verified token, never from the request, so a
 * client cannot ask for someone else's profile here.
 */
const me = async (req, res) => {
    try {
        const [rows] = await connection.query(
            `SELECT id, username, full_name, email, bio, website,
                    profile_picture, is_verified, is_private, created_at,
                    (SELECT COUNT(*) FROM posts WHERE user_id = users.id) AS post_count
             FROM users
             WHERE id = ? AND is_active = 1`,
            [req.user.id]
        );

        if (rows.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }

        return res.status(200).json({ user: rows[0] });

    } catch (error) {
        console.error('Error loading profile:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};


/**
 * PATCH /auth/privacy - makes the caller's whole account private or public.
 *
 * The account flag is the stricter of the two: while it is on, even a
 * post marked public stays hidden from everyone else.
 */
const setAccountPrivacy = async (req, res) => {
    try {
        const { is_private: raw } = req.body;

        if (raw === undefined || raw === null) {
            return res.status(400).json({ message: 'is_private is required' });
        }

        const isPrivate = ['1', 'true', 'yes', 'on']
            .includes(String(raw).toLowerCase()) ? 1 : 0;

        await connection.query(
            'UPDATE users SET is_private = ? WHERE id = ?',
            [isPrivate, req.user.id]
        );

        return res.status(200).json({
            message: isPrivate
                ? 'Account is now private'
                : 'Account is now public',
            is_private: isPrivate
        });

    } catch (error) {
        console.error('Error updating account privacy:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};


/**
 * Deletes a file previously saved under /uploads/avatars.
 *
 * The stored value is rebuilt from its basename rather than trusted as a
 * path, so a crafted value like "../../config/connection.js" cannot reach
 * outside the avatars folder.
 */
const removeUpload = async (storedUrl) => {
    if (!storedUrl || !storedUrl.startsWith('/uploads/avatars/')) return;

    const safeName = path.basename(storedUrl);
    const filePath = path.join(__dirname, '..', 'uploads', 'avatars', safeName);

    try {
        await fs.unlink(filePath);
    } catch (err) {
        // Already gone is fine; anything else is worth knowing about.
        if (err.code !== 'ENOENT') {
            console.error('Could not delete old avatar:', err.message);
        }
    }
};

/**
 * PATCH /auth/profile-picture - uploads or replaces the caller's avatar.
 *
 * The previous file is deleted afterwards, or every change would leave an
 * orphan on disk. Deletion failures are logged rather than thrown: the new
 * avatar is already saved, so a stale file is untidy, not broken.
 */
const setProfilePicture = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'Image is required' });
        }

        const newUrl = `/uploads/avatars/${req.file.filename}`;

        const [rows] = await connection.query(
            'SELECT profile_picture FROM users WHERE id = ?',
            [req.user.id]
        );
        const oldUrl = rows[0] ? rows[0].profile_picture : null;

        await connection.query(
            'UPDATE users SET profile_picture = ? WHERE id = ?',
            [newUrl, req.user.id]
        );

        await removeUpload(oldUrl);

        return res.status(200).json({
            message: 'Profile picture updated',
            profile_picture: newUrl
        });

    } catch (error) {
        console.error('Error updating profile picture:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};

/**
 * DELETE /auth/profile-picture - clears the avatar back to the initial.
 */
const removeProfilePicture = async (req, res) => {
    try {
        const [rows] = await connection.query(
            'SELECT profile_picture FROM users WHERE id = ?',
            [req.user.id]
        );

        if (!rows[0] || !rows[0].profile_picture) {
            return res.status(404).json({ message: 'No profile picture set' });
        }

        await connection.query(
            'UPDATE users SET profile_picture = NULL WHERE id = ?',
            [req.user.id]
        );

        await removeUpload(rows[0].profile_picture);

        return res.status(200).json({ message: 'Profile picture removed' });

    } catch (error) {
        console.error('Error removing profile picture:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};


module.exports = {
    login,
    signup,
    me,
    setAccountPrivacy,
    setProfilePicture,
    removeProfilePicture
}