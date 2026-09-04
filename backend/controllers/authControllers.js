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


module.exports = {login, signup, me}