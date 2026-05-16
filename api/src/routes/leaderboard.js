import { Router } from 'express';
import { query } from '../db/pool.js';
import { asyncHandler } from '../middleware/errors.js';

const router = Router();

/**
 * GET /api/leaderboard
 * Classement global — utilise la VUE MATÉRIALISÉE mv_global_leaderboard.
 * Beaucoup plus rapide qu'un calcul à la volée car pré-agrégé.
 */
router.get('/', asyncHandler(async (req, res) => {
  const limit  = Math.min(Number(req.query.limit) || 50, 200);
  const tier   = req.query.tier;

  const params = [limit];
  let whereTier = '';
  if (tier) {
    params.push(tier);
    whereTier = `WHERE tier = $${params.length}`;
  }

  const data = await query(
    `SELECT * FROM mv_global_leaderboard ${whereTier} ORDER BY rank_elo LIMIT $1`,
    params
  );

  // On expose aussi la date du dernier refresh pour la transparence
  const [{ refreshed_at }] = await query(
    'SELECT MIN(refreshed_at) AS refreshed_at FROM mv_global_leaderboard'
  );

  res.json({ data, refreshed_at });
}));

/**
 * POST /api/leaderboard/refresh
 * Force le rafraîchissement de la vue matérialisée.
 * En prod, à protéger par un middleware admin.
 */
router.post('/refresh', asyncHandler(async (_req, res) => {
  await query('REFRESH MATERIALIZED VIEW CONCURRENTLY mv_global_leaderboard');
  res.json({ ok: true, refreshed_at: new Date().toISOString() });
}));

/**
 * GET /api/leaderboard/rivalries
 * Top 10 des plus grosses rivalités.
 * Démontre LEAST/GREATEST + GROUP BY composé.
 */
router.get('/rivalries', asyncHandler(async (_req, res) => {
  const data = await query(
    `WITH rivalries AS (
        SELECT
            LEAST(challenger_id, opponent_id)    AS player_a_id,
            GREATEST(challenger_id, opponent_id) AS player_b_id,
            COUNT(*) AS duels_count,
            SUM(CASE WHEN winner_id = LEAST(challenger_id, opponent_id)    THEN 1 ELSE 0 END) AS wins_a,
            SUM(CASE WHEN winner_id = GREATEST(challenger_id, opponent_id) THEN 1 ELSE 0 END) AS wins_b
        FROM duels
        WHERE status = 'completed'
        GROUP BY LEAST(challenger_id, opponent_id), GREATEST(challenger_id, opponent_id)
        HAVING COUNT(*) >= 2
     )
     SELECT
        ua.username AS player_a,
        ub.username AS player_b,
        r.duels_count, r.wins_a, r.wins_b
     FROM rivalries r
     JOIN users ua ON ua.user_id = r.player_a_id
     JOIN users ub ON ub.user_id = r.player_b_id
     ORDER BY r.duels_count DESC
     LIMIT 10`
  );
  res.json({ data });
}));

/**
 * GET /api/leaderboard/recommendations/:userId
 * Recommandations de challenges (collaborative filtering).
 */
router.get('/recommendations/:userId', asyncHandler(async (req, res) => {
  const userId = Number(req.params.userId);

  const data = await query(
    `WITH my_solved AS (
        SELECT DISTINCT challenge_id
        FROM attempts
        WHERE user_id = $1 AND verdict = 'passed'
     ),
     similar_users AS (
        SELECT user_id
        FROM users
        WHERE user_id <> $1
          AND ABS(elo_rating - (SELECT elo_rating FROM users WHERE user_id = $1)) < 200
     )
     SELECT
        c.challenge_id, c.title, c.slug, c.difficulty, c.xp_reward,
        COUNT(DISTINCT a.user_id) AS solved_by_peers
     FROM attempts a
     JOIN challenges c ON c.challenge_id = a.challenge_id
     WHERE a.user_id IN (SELECT user_id FROM similar_users)
       AND a.verdict = 'passed'
       AND a.challenge_id NOT IN (SELECT challenge_id FROM my_solved)
     GROUP BY c.challenge_id, c.title, c.slug, c.difficulty, c.xp_reward
     ORDER BY solved_by_peers DESC
     LIMIT 5`,
    [userId]
  );

  res.json({ data });
}));

export default router;
