/**
 * The single rule deciding whether one user may see another's post.
 *
 * A post is visible to someone other than its author only when both the
 * post and the author's account are public. The account setting is the
 * stricter of the two and wins: marking one post public does not expose
 * it while the whole account is private.
 *
 * Everyone always sees their own posts regardless of either flag, which
 * is why the caller's id is bound rather than compared in SQL text.
 *
 * There is no follows table yet, so "private" means "only me". When
 * follows arrive, this is the one place that changes — the feed,
 * profile and leaderboard all read it.
 */
const VISIBLE_TO_CALLER = `
    (p.user_id = ? OR (p.is_private = 0 AND u.is_private = 0))
`;

module.exports = { VISIBLE_TO_CALLER };
