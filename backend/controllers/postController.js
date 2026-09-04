const connection = require('../config/connection');

const createPost = async (req, res) => {
    try {
        const { caption, location } = req.body;
        const userId = req.user.id;
       
        // image comes from multer, not the body
        if (!req.file) {
            return res.status(400).json({ message: 'Image is required' });
        }

        const imageUrl = `/uploads/posts/${req.file.filename}`;

        const [result] = await connection.query(
            'INSERT INTO posts (user_id, image_url, caption, location) VALUES (?, ?, ?, ?)',
            [userId, imageUrl, caption || null, location || null]
        );

        return res.status(201).json({
            message: 'Post created successfully',
            post: {
                id: result.insertId,
                image_url: imageUrl,
                caption: caption || null,
                location: location || null
            }
        });

    } catch (error) {
        console.error('Error creating post:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};



// The columns every post response returns. Never SELECT u.* — that would
// ship the password hash to the client.
const POST_COLUMNS = `
    p.id, p.user_id, p.image_url, p.caption, p.location, p.created_at,
    u.username, u.full_name, u.profile_picture, u.is_verified,
    (SELECT COUNT(*) FROM likes WHERE post_id = p.id) AS like_count,
    EXISTS(SELECT 1 FROM likes WHERE post_id = p.id AND user_id = ?) AS is_liked
`;

/**
 * GET /posts/feed — every post, newest first.
 *
 * JOINs users so each post carries its author, and uses two subqueries for
 * the like data: a count for everyone, and whether the caller liked it.
 * `?limit` and `?offset` paginate (defaults 20 / 0).
 */
const getFeed = async (req, res) => {
    try {
        const userId = req.user.id;

        // LIMIT/OFFSET cannot be bound as strings, so parse them to ints and
        // clamp — this both prevents injection and stops a client asking for
        // a million rows.
        const limit = Math.min(parseInt(req.query.limit, 10) || 20, 50);
        const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

        // Other people's posts only — your own live on your profile.
        const [rows] = await connection.query(
            `SELECT ${POST_COLUMNS}
             FROM posts p
             JOIN users u ON p.user_id = u.id
             WHERE u.is_active = 1 AND p.user_id != ?
             ORDER BY p.created_at DESC
             LIMIT ${limit} OFFSET ${offset}`,
            [userId, userId]
        );

        return res.status(200).json({ posts: rows });

    } catch (error) {
        console.error('Error loading feed:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};

/** GET /posts/:id — one post with its author and like data. */
const getPost = async (req, res) => {
    try {
        const [rows] = await connection.query(
            `SELECT ${POST_COLUMNS}
             FROM posts p
             JOIN users u ON p.user_id = u.id
             WHERE p.id = ?`,
            [req.user.id, req.params.id]
        );

        if (rows.length === 0) {
            return res.status(404).json({ message: 'Post not found' });
        }

        return res.status(200).json({ post: rows[0] });

    } catch (error) {
        console.error('Error loading post:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};

/** GET /posts/user/:userId — one user's posts, for a profile grid. */
const getUserPost = async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit, 10) || 20, 50);
        const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

        const [rows] = await connection.query(
            `SELECT ${POST_COLUMNS}
             FROM posts p
             JOIN users u ON p.user_id = u.id
             WHERE p.user_id = ?
             ORDER BY p.created_at DESC
             LIMIT ${limit} OFFSET ${offset}`,
            [req.user.id, req.params.userId]
        );

        return res.status(200).json({ posts: rows });

    } catch (error) {
        console.error('Error loading user posts:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};

/**
 * DELETE /posts/:id — deletes only the caller's own post.
 *
 * Both conditions go in one query: without `AND user_id = ?` anyone could
 * delete anyone's post by guessing an id. affectedRows === 0 covers both
 * "no such post" and "not yours" — deliberately indistinguishable, so the
 * response cannot be used to probe which post ids exist.
 */
const deletePost = async (req, res) => {
    try {
        const [result] = await connection.query(
            'DELETE FROM posts WHERE id = ? AND user_id = ?',
            [req.params.id, req.user.id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Post not found' });
        }

        return res.status(200).json({ message: 'Post deleted' });

    } catch (error) {
        console.error('Error deleting post:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};


module.exports = {
    createPost,
    getFeed,
    getPost,
    getUserPost,
    deletePost
}