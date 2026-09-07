const connection = require('../config/connection');

/**
 * Turns the query params into a SQL fragment and its bind values.
 *
 * Filtering is on the POST date, not the like date: "top this month"
 * means posts made this month and how they did, which is simpler to
 * explain than a window that mixes old posts with new likes.
 *
 * Supported:
 *   ?period=all                    everything (default)
 *   ?period=month&year=&month=     one calendar month
 *   ?period=year&year=             one calendar year
 *   ?period=range&from=&to=        an explicit date range (YYYY-MM-DD)
 *   ?period=today                  posts made today
 *   ?period=week                   the last 7 days
 */
const buildPeriodFilter = (query) => {
    const period = (query.period || 'all').toLowerCase();
    const now = new Date();

    switch (period) {
        case 'today':
            return {
                sql: 'AND DATE(p.created_at) = CURDATE()',
                params: [],
                label: 'Today'
            };

        case 'week':
            return {
                sql: 'AND p.created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)',
                params: [],
                label: 'Last 7 days'
            };

        case 'month': {
            const year = parseInt(query.year, 10) || now.getFullYear();
            // getMonth() is zero-based; the API and SQL both use 1-12.
            const month = parseInt(query.month, 10) || now.getMonth() + 1;

            if (month < 1 || month > 12) {
                return { error: 'month must be between 1 and 12' };
            }

            return {
                sql: 'AND YEAR(p.created_at) = ? AND MONTH(p.created_at) = ?',
                params: [year, month],
                label: `${MONTHS[month - 1]} ${year}`
            };
        }

        case 'year': {
            const year = parseInt(query.year, 10) || now.getFullYear();
            return {
                sql: 'AND YEAR(p.created_at) = ?',
                params: [year],
                label: String(year)
            };
        }

        case 'range': {
            const { from, to } = query;

            if (!DATE_RE.test(from || '') || !DATE_RE.test(to || '')) {
                return { error: 'from and to must be dates in YYYY-MM-DD form' };
            }
            if (from > to) {
                return { error: 'from must not be after to' };
            }

            // `< to + 1 day` rather than `<= to`, so a post made at 14:30
            // on the end date is still inside the range — DATETIME
            // comparison against a bare date would treat it as 00:00.
            return {
                sql: 'AND p.created_at >= ? AND p.created_at < DATE_ADD(?, INTERVAL 1 DAY)',
                params: [from, to],
                label: `${from} to ${to}`
            };
        }

        case 'all':
            return { sql: '', params: [], label: 'All time' };

        default:
            return { error: `unknown period "${period}"` };
    }
};

const MONTHS = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
];

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

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
 * Query params: ?limit (default 5, max 50), ?minPosts (default 2),
 * plus the period params documented on buildPeriodFilter.
 */
const getLeaderboard = async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit, 10) || 5, 50);
        const minPosts = Math.max(parseInt(req.query.minPosts, 10) || 2, 1);

        const period = buildPeriodFilter(req.query);
        if (period.error) {
            return res.status(400).json({ message: period.error });
        }

        // Two JOINs doing different jobs:
        //   JOIN posts       — drops users with no posts entirely
        //   LEFT JOIN likes  — keeps posts that have no likes, so they
        //                      still count in the denominator
        //
        // COUNT(DISTINCT p.id) is required: the LEFT JOIN multiplies each
        // post row once per like, so a plain COUNT(p.id) would count a
        // post with 5 likes as 5 posts.
        //
        // The period filter sits in the WHERE, so it narrows which posts
        // count before the aggregate runs — a user with no posts in the
        // window drops off the board entirely rather than showing a zero.
        //
        // Private accounts are off the board completely, and a public
        // account's private posts do not count toward its average — the
        // board only ranks what everyone can actually see. No caller id is
        // needed: it is the same public view for everyone, including your
        // own private posts, which would otherwise let you infer a rival's
        // standing from a board only you can see.
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
                   AND u.is_private = 0
                   AND p.is_private = 0
                   ${period.sql}
             GROUP BY u.id, u.username, u.full_name, u.profile_picture,
                      u.is_verified
             HAVING post_count >= ?
             ORDER BY avg_likes DESC, total_likes DESC, post_count DESC
             LIMIT ${limit}`,
            [...period.params, minPosts]
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

        return res.status(200).json({
            leaderboard,
            period: {
                type: (req.query.period || 'all').toLowerCase(),
                label: period.label
            }
        });

    } catch (error) {
        console.error('Error loading leaderboard:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
};

module.exports = { getLeaderboard };
