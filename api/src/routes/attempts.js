import { Router } from 'express';
import { query } from '../db/pool.js';
import { asyncHandler, HttpError } from '../middleware/errors.js';

const router = Router();

/**
 * POST /api/attempts
 * Enregistre une tentative.
 * Les TRIGGERS attribuent automatiquement l'XP et les badges si verdict = 'passed'.
 */
router.post('/', asyncHandler(async (req, res) => {
  const {
    user_id, challenge_id, duel_id = null,
    language, source_code, verdict, execution_ms,
    tests_passed, tests_total,
  } = req.body;

  if (!user_id || !challenge_id || !language || !source_code || !verdict) {
    throw new HttpError(400, 'Champs requis manquants');
  }

  const [attempt] = await query(
    `INSERT INTO attempts
       (user_id, challenge_id, duel_id, language, source_code,
        verdict, execution_ms, tests_passed, tests_total)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     RETURNING *`,
    [user_id, challenge_id, duel_id, language, source_code,
     verdict, execution_ms, tests_passed, tests_total]
  );

  // Si succès, on retourne aussi le nouvel XP du joueur (qui a été MAJ par le trigger)
  let userUpdated = null;
  if (verdict === 'passed') {
    const [u] = await query(
      'SELECT user_id, username, total_xp, elo_rating FROM users WHERE user_id = $1',
      [user_id]
    );
    userUpdated = u;
  }

  res.status(201).json({ attempt, user: userUpdated });
}));

/**
 * GET /api/attempts/recent
 * Dernières tentatives de la plateforme (activity feed).
 */
router.get('/recent', asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 30, 100);

  const data = await query(
    `SELECT
        a.attempt_id, a.verdict, a.language, a.submitted_at,
        u.username, u.user_id,
        c.title AS challenge_title, c.slug, c.difficulty
     FROM attempts a
     JOIN users u      ON u.user_id = a.user_id
     JOIN challenges c ON c.challenge_id = a.challenge_id
     ORDER BY a.submitted_at DESC
     LIMIT $1`,
    [limit]
  );

  res.json({ data });
}));

export default router;
