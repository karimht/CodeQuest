-- =============================================================================
-- CodeQuest — Vues et vues matérialisées
-- =============================================================================
SET search_path TO codequest, public;

-- -----------------------------------------------------------------------------
-- VUE : v_user_stats
-- Statistiques agrégées par joueur (calculées à la volée).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_user_stats AS
SELECT
    u.user_id,
    u.username,
    u.display_name,
    u.elo_rating,
    u.total_xp,
    -- Nombre de tentatives
    COUNT(DISTINCT a.attempt_id) AS total_attempts,
    -- Tentatives réussies
    COUNT(DISTINCT a.attempt_id) FILTER (WHERE a.verdict = 'passed') AS successful_attempts,
    -- Taux de réussite (en %)
    ROUND(
        100.0 * COUNT(DISTINCT a.attempt_id) FILTER (WHERE a.verdict = 'passed')
        / NULLIF(COUNT(DISTINCT a.attempt_id), 0),
        2
    ) AS success_rate_pct,
    -- Duels gagnés / joués
    COUNT(DISTINCT d.duel_id) FILTER (WHERE d.winner_id = u.user_id) AS duels_won,
    COUNT(DISTINCT d.duel_id) FILTER (WHERE d.status = 'completed')   AS duels_completed,
    -- Challenges uniques résolus
    COUNT(DISTINCT a.challenge_id) FILTER (WHERE a.verdict = 'passed') AS unique_challenges_solved
FROM users u
LEFT JOIN attempts a ON a.user_id = u.user_id
LEFT JOIN duels    d ON (d.challenger_id = u.user_id OR d.opponent_id = u.user_id)
                     AND d.status = 'completed'
GROUP BY u.user_id, u.username, u.display_name, u.elo_rating, u.total_xp;

COMMENT ON VIEW v_user_stats IS
'Stats live par joueur. À utiliser pour les pages de profil.';

-- -----------------------------------------------------------------------------
-- VUE : v_duel_details
-- Vue enrichie d'un duel avec les noms des joueurs et le challenge.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_duel_details AS
SELECT
    d.duel_id,
    d.status,
    d.xp_stake,
    d.created_at,
    d.started_at,
    d.ended_at,
    c.challenge_id,
    c.title         AS challenge_title,
    c.difficulty    AS challenge_difficulty,
    uc.user_id      AS challenger_id,
    uc.username     AS challenger_username,
    uc.elo_rating   AS challenger_elo,
    uo.user_id      AS opponent_id,
    uo.username     AS opponent_username,
    uo.elo_rating   AS opponent_elo,
    uw.user_id      AS winner_id,
    uw.username     AS winner_username,
    -- Durée du duel en secondes
    EXTRACT(EPOCH FROM (d.ended_at - d.started_at))::INTEGER AS duration_seconds
FROM duels d
JOIN users      uc ON uc.user_id = d.challenger_id
JOIN users      uo ON uo.user_id = d.opponent_id
JOIN challenges c  ON c.challenge_id = d.challenge_id
LEFT JOIN users uw ON uw.user_id = d.winner_id;

-- -----------------------------------------------------------------------------
-- VUE MATÉRIALISÉE : mv_global_leaderboard
-- Classement global. Rafraîchie périodiquement (cron) pour performance.
-- -----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_global_leaderboard;
CREATE MATERIALIZED VIEW mv_global_leaderboard AS
SELECT
    u.user_id,
    u.username,
    u.display_name,
    u.elo_rating,
    u.total_xp,
    -- Window functions : rangs sur plusieurs critères
    RANK()       OVER (ORDER BY u.elo_rating DESC) AS rank_elo,
    RANK()       OVER (ORDER BY u.total_xp   DESC) AS rank_xp,
    DENSE_RANK() OVER (ORDER BY u.elo_rating DESC) AS dense_rank_elo,
    -- Tier basé sur l'ELO
    CASE
        WHEN u.elo_rating >= 2200 THEN 'Grand Master'
        WHEN u.elo_rating >= 1800 THEN 'Master'
        WHEN u.elo_rating >= 1500 THEN 'Diamond'
        WHEN u.elo_rating >= 1200 THEN 'Gold'
        WHEN u.elo_rating >= 900  THEN 'Silver'
        ELSE 'Bronze'
    END AS tier,
    -- Compteurs
    (SELECT COUNT(*) FROM duels dd
     WHERE dd.winner_id = u.user_id AND dd.status = 'completed') AS duels_won,
    NOW() AS refreshed_at
FROM users u
ORDER BY u.elo_rating DESC;

CREATE UNIQUE INDEX idx_mv_leaderboard_user ON mv_global_leaderboard(user_id);
CREATE INDEX idx_mv_leaderboard_rank ON mv_global_leaderboard(rank_elo);

COMMENT ON MATERIALIZED VIEW mv_global_leaderboard IS
'Classement global. Rafraîchir avec : REFRESH MATERIALIZED VIEW CONCURRENTLY mv_global_leaderboard;';

-- -----------------------------------------------------------------------------
-- VUE : v_challenge_difficulty_real
-- Difficulté "réelle" d'un challenge basée sur le taux d'échec.
-- Utilise une window function pour comparer à la moyenne.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_challenge_difficulty_real AS
SELECT
    c.challenge_id,
    c.title,
    c.difficulty AS difficulty_declared,
    COUNT(a.attempt_id) AS total_attempts,
    COUNT(a.attempt_id) FILTER (WHERE a.verdict = 'passed') AS passed_attempts,
    ROUND(
        100.0 * COUNT(a.attempt_id) FILTER (WHERE a.verdict = 'passed')
        / NULLIF(COUNT(a.attempt_id), 0),
        2
    ) AS pass_rate_pct,
    -- Comparaison à la moyenne globale via window function
    ROUND(
        AVG(100.0 * (CASE WHEN a.verdict = 'passed' THEN 1 ELSE 0 END))
            OVER () ,
        2
    ) AS global_avg_pass_rate
FROM challenges c
LEFT JOIN attempts a ON a.challenge_id = c.challenge_id
GROUP BY c.challenge_id, c.title, c.difficulty;
