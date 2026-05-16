import { Router } from 'express';
import { query, transaction } from '../db/pool.js';
import { asyncHandler, HttpError } from '../middleware/errors.js';

const router = Router();

/**
 * GET /api/duels
 * Liste des duels avec filtres.
 * Utilise la VUE v_duel_details qui pré-joint users + challenges.
 */
router.get('/', asyncHandler(async (req, res) => {
  const { status, user_id } = req.query;

  const conditions = [];
  const params = [];

  if (status) {
    params.push(status);
    conditions.push(`status = $${params.length}`);
  }
  if (user_id) {
    params.push(Number(user_id));
    conditions.push(`(challenger_id = $${params.length} OR opponent_id = $${params.length})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const duels = await query(
    `SELECT * FROM v_duel_details ${where} ORDER BY created_at DESC LIMIT 50`,
    params
  );

  res.json({ data: duels });
}));

/**
 * GET /api/duels/:id
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const [duel] = await query('SELECT * FROM v_duel_details WHERE duel_id = $1', [id]);

  if (!duel) throw new HttpError(404, 'Duel introuvable');

  // Attempts liées à ce duel
  const attempts = await query(
    `SELECT a.*, u.username
     FROM attempts a
     JOIN users u ON u.user_id = a.user_id
     WHERE a.duel_id = $1
     ORDER BY a.submitted_at ASC`,
    [id]
  );

  res.json({ ...duel, attempts });
}));

/**
 * POST /api/duels
 * Crée un duel via la PROCÉDURE STOCKÉE create_duel.
 * Démontre l'usage de CALL avec un paramètre OUT.
 */
router.post('/', asyncHandler(async (req, res) => {
  const { challenger_id, opponent_id, challenge_id, xp_stake = 50 } = req.body;

  if (!challenger_id || !opponent_id || !challenge_id) {
    throw new HttpError(400, 'Champs requis : challenger_id, opponent_id, challenge_id');
  }

  // On utilise la procédure stockée (qui contient les vérifications métier)
  const result = await transaction(async (client) => {
    const { rows } = await client.query(
      'CALL create_duel($1, $2, $3, $4, NULL)',
      [challenger_id, opponent_id, challenge_id, xp_stake]
    );
    const duelId = rows[0].p_duel_id;

    const { rows: duelRows } = await client.query(
      'SELECT * FROM v_duel_details WHERE duel_id = $1', [duelId]
    );
    return duelRows[0];
  });

  res.status(201).json(result);
}));

/**
 * PATCH /api/duels/:id/complete
 * Marque un duel comme terminé. Le TRIGGER trg_duel_completed
 * va automatiquement mettre à jour les ELO et XP des deux joueurs.
 */
router.patch('/:id/complete', asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const { winner_id } = req.body;

  if (!winner_id) throw new HttpError(400, 'winner_id requis');

  const [updated] = await query(
    `UPDATE duels
        SET status = 'completed',
            winner_id = $2,
            ended_at = NOW()
      WHERE duel_id = $1 AND status = 'active'
      RETURNING duel_id, winner_id, status`,
    [id, winner_id]
  );

  if (!updated) {
    throw new HttpError(400, 'Duel introuvable ou pas en cours');
  }

  // Récupérer le nouvel ELO du gagnant pour la réponse
  const [winner] = await query(
    'SELECT username, elo_rating FROM users WHERE user_id = $1',
    [winner_id]
  );

  res.json({ ...updated, winner });
}));

/**
 * PATCH /api/duels/:id/start
 * Passe un duel de 'pending' à 'active'.
 */
router.patch('/:id/start', asyncHandler(async (req, res) => {
  const id = Number(req.params.id);

  const [updated] = await query(
    `UPDATE duels
        SET status = 'active', started_at = NOW()
      WHERE duel_id = $1 AND status = 'pending'
      RETURNING *`,
    [id]
  );

  if (!updated) throw new HttpError(400, 'Duel introuvable ou pas en attente');

  res.json(updated);
}));

export default router;
