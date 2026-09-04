const connection = require('../config/connection');

/**
 * GET /leaderboard — top users by average likes per post.
 *
 * Ranking by average rather than total rewards consistently good posts
 * over sheer volume: 5 posts averaging 10 likes beats 50 posts averaging 1.
 *
 * The `minPosts` floor exists because averages are meaningless on tiny
 * samples — one lucky post would otherwise top the board over someone
 * with a long record. Defaults to 2.
 *
 * Query params: ?limit (default 5, max 50), ?minPosts (default 2)
 */
const getLeaderboard = async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit, 10) || 5, 50);
        const minPosts = Math.max(parseInt(req.query.minPosts, 10) || 2, 1);

        // Two JOINs doing different jobs:
        //   JOIN posts       — drops users with no posts entirely
        //   LEFT JOIN likes  — keeps posts that have no likes, so they
        //                      still count in the denominator
        //
        // COUNT(DISTINCT p.id) is required: the LEFT JOIN multiplies each
        // post row once per like, so a plain COUNT(p.id) would count a
        // post with 5 likes as 5 posts.
        const [rows] = await connection.query(
            `SELECT u.id, u.username, u.full_name, u.profile_picture,
                    u.is_verified,
                    COUNT(DISTINCT p.id)  AS post_count,
                    COUNT(l.post_id)      AS total_likes,
                    ROUND(COUNT(l.post_id) / COUNT(DISTINCT p.id), 2) AS avg_likes
             FROM users u
             JOIN posts p ON p.user_id = u.id
             LEFT JOIN likes l ON l.post_id = p.id
             WHERE u.is_active = 1
             GROUP BY u.id, u.username, u.full_name, u.profile_picture,
                      u.is_verified
             HAVING post_count >= ?
             ORDER BY avg_likes DESC, total_likes DESC, post_count DESC
             LIMIT ${limit}`,
            [minPosts]
        );

        // Rank is assigned here rather than in SQL so it stays correct
        // regardless of MySQL version (window functions need 8.0+).
        const leaderboard = rows.map((row, index) => ({
            rank: index + 1,
            ...row,
            // MySQL returns ROUND() on a DECIMAL as a string; send a number
            // so clients do not have to parse it.
            avg_likes: Number(row.avg_likes)
        }));

        return res.status(200).json({ leaderboard });

    } catch (error) {
        console.error('Error loading leaderboard:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};

module.exports = { getLeaderboard };
