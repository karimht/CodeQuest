import { Router } from 'express';
import { query } from '../db/pool.js';
import { asyncHandler, HttpError } from '../middleware/errors.js';

const router = Router();

/**
 * GET /api/challenges
 * Liste des challenges avec filtres optionnels.
 * Query params : ?difficulty=easy&tag=recursion&search=fibonacci
 */
router.get('/', asyncHandler(async (req, res) => {
  const { difficulty, tag, search } = req.query;

  // Construction dynamique de la WHERE clause (paramétrée pour rester safe)
  const conditions = ['is_published = TRUE'];
  const params = [];

  if (difficulty) {
    params.push(difficulty);
    conditions.push(`difficulty = $${params.length}`);
  }
  if (tag) {
    params.push(tag);
    conditions.push(`$${params.length} = ANY(tags)`);
  }
  if (search) {
    params.push(`%${search}%`);
    conditions.push(`title ILIKE $${params.length}`);
  }

  const challenges = await query(
    `SELECT challenge_id, title, slug, difficulty, xp_reward, tags, created_at
     FROM challenges
     WHERE ${conditions.join(' AND ')}
     ORDER BY
       CASE difficulty
         WHEN 'easy' THEN 1 WHEN 'medium' THEN 2
         WHEN 'hard' THEN 3 WHEN 'expert' THEN 4
       END,
       title`,
    params
  );

  res.json({ data: challenges });
}));

/**
 * GET /api/challenges/:slug
 * Détail d'un challenge par son slug.
 */
router.get('/:slug', asyncHandler(async (req, res) => {
  const [challenge] = await query(
    `SELECT c.*, u.username AS author_username
     FROM challenges c
     LEFT JOIN users u ON u.user_id = c.author_id
     WHERE c.slug = $1`,
    [req.params.slug]
  );

  if (!challenge) throw new HttpError(404, 'Challenge introuvable');

  // Stats publiques du challenge (utilise la vue v_challenge_difficulty_real)
  const [stats] = await query(
    'SELECT * FROM v_challenge_difficulty_real WHERE challenge_id = $1',
    [challenge.challenge_id]
  );

  res.json({ ...challenge, stats });
}));

/**
 * GET /api/challenges/:slug/leaderboard
 * Meilleurs temps sur un challenge donné.
 * Démontre l'usage de window functions (RANK + DISTINCT ON).
 */
router.get('/:slug/leaderboard', asyncHandler(async (req, res) => {
  const leaderboard = await query(
    `WITH best_attempts AS (
        SELECT DISTINCT ON (a.user_id)
            a.user_id, a.execution_ms, a.language, a.submitted_at
        FROM attempts a
        JOIN challenges c ON c.challenge_id = a.challenge_id
        WHERE c.slug = $1 AND a.verdict = 'passed'
        ORDER BY a.user_id, a.execution_ms ASC
     )
     SELECT
        u.username,
        u.display_name,
        ba.execution_ms,
        ba.language,
        ba.submitted_at,
        RANK() OVER (ORDER BY ba.execution_ms ASC) AS rank
     FROM best_attempts ba
     JOIN users u ON u.user_id = ba.user_id
     ORDER BY ba.execution_ms ASC
     LIMIT 20`,
    [req.params.slug]
  );

  res.json({ data: leaderboard });
}));

/**
 * GET /api/challenges/stats/by-tag
 * Statistiques agrégées par tag (démontre unnest).
 */
router.get('/stats/by-tag', asyncHandler(async (_req, res) => {
  const stats = await query(
    `SELECT
        tag,
        COUNT(*) AS nb_challenges,
        AVG(xp_reward)::INTEGER AS avg_xp,
        ARRAY_AGG(DISTINCT difficulty::TEXT) AS difficulties
     FROM challenges, unnest(tags) AS tag
     GROUP BY tag
     ORDER BY nb_challenges DESC`
  );
  res.json({ data: stats });
}));

export default router;
