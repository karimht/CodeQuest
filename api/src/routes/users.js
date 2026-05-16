import { Router } from 'express';
import { query } from '../db/pool.js';
import { asyncHandler, HttpError } from '../middleware/errors.js';

const router = Router();

/**
 * GET /api/users
 * Liste paginée des joueurs.
 * Query params : ?limit=20&offset=0&sort=elo|xp|recent
 */
router.get('/', asyncHandler(async (req, res) => {
  const limit  = Math.min(Number(req.query.limit) || 20, 100);
  const offset = Number(req.query.offset) || 0;
  const sort   = req.query.sort || 'elo';

  const sortColumn = {
    elo:    'elo_rating DESC',
    xp:     'total_xp DESC',
    recent: 'last_active_at DESC',
  }[sort] || 'elo_rating DESC';

  // ⚠️ ORDER BY ne peut pas être paramétré, donc on whitelist côté code
  const users = await query(
    `SELECT user_id, username, display_name, elo_rating, total_xp, country_code, last_active_at
     FROM users
     ORDER BY ${sortColumn}
     LIMIT $1 OFFSET $2`,
    [limit, offset]
  );

  const [{ count }] = await query('SELECT COUNT(*) FROM users');

  res.json({ data: users, total: Number(count), limit, offset });
}));

/**
 * GET /api/users/:id
 * Profil complet d'un joueur avec ses stats agrégées.
 * Utilise la VUE v_user_stats créée dans 02_views.sql.
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const userId = Number(req.params.id);
  if (!Number.isInteger(userId)) throw new HttpError(400, 'ID invalide');

  const [user] = await query('SELECT * FROM v_user_stats WHERE user_id = $1', [userId]);

  if (!user) throw new HttpError(404, 'Joueur introuvable');

  // En parallèle : badges, guildes
  const [badges, guilds] = await Promise.all([
    query(
      `SELECT b.code, b.name, b.icon, b.rarity, ub.unlocked_at
       FROM user_badges ub
       JOIN badges b ON b.badge_id = ub.badge_id
       WHERE ub.user_id = $1
       ORDER BY ub.unlocked_at DESC`,
      [userId]
    ),
    query(
      `SELECT g.guild_id, g.name, g.tag, gm.role, gm.joined_at
       FROM guild_members gm
       JOIN guilds g ON g.guild_id = gm.guild_id
       WHERE gm.user_id = $1`,
      [userId]
    ),
  ]);

  res.json({ ...user, badges, guilds });
}));

/**
 * GET /api/users/:id/attempts
 * Historique des tentatives d'un joueur.
 */
router.get('/:id/attempts', asyncHandler(async (req, res) => {
  const userId = Number(req.params.id);
  const limit  = Math.min(Number(req.query.limit) || 50, 200);

  const attempts = await query(
    `SELECT
        a.attempt_id, a.verdict, a.language, a.execution_ms,
        a.tests_passed, a.tests_total, a.submitted_at,
        c.title AS challenge_title, c.difficulty
     FROM attempts a
     JOIN challenges c ON c.challenge_id = a.challenge_id
     WHERE a.user_id = $1
     ORDER BY a.submitted_at DESC
     LIMIT $2`,
    [userId, limit]
  );

  res.json({ data: attempts });
}));

/**
 * GET /api/users/:id/friends
 * Liste des amis d'un joueur (graphe non orienté).
 */
router.get('/:id/friends', asyncHandler(async (req, res) => {
  const userId = Number(req.params.id);

  const friends = await query(
    `SELECT
        u.user_id, u.username, u.display_name, u.elo_rating,
        f.responded_at AS friends_since
     FROM friendships f
     JOIN users u ON u.user_id = (
         CASE WHEN f.requester_id = $1 THEN f.addressee_id
              ELSE f.requester_id
         END
     )
     WHERE (f.requester_id = $1 OR f.addressee_id = $1)
       AND f.state = 'accepted'
     ORDER BY u.elo_rating DESC`,
    [userId]
  );

  res.json({ data: friends });
}));

/**
 * POST /api/users
 * Crée un nouveau joueur.
 */
router.post('/', asyncHandler(async (req, res) => {
  const { username, email, password_hash, display_name, country_code } = req.body;

  if (!username || !email || !password_hash || !display_name) {
    throw new HttpError(400, 'Champs requis : username, email, password_hash, display_name');
  }

  const [user] = await query(
    `INSERT INTO users (username, email, password_hash, display_name, country_code)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING user_id, username, display_name, elo_rating, total_xp, created_at`,
    [username, email, password_hash, display_name, country_code || null]
  );

  res.status(201).json(user);
}));

export default router;
