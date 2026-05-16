-- =============================================================================
-- CodeQuest — Requêtes SQL classées par concept
-- =============================================================================
-- Ce fichier sert à la fois de DÉMO pour ton cours et d'EXEMPLES pour l'API.
-- Chaque section illustre un concept précis du programme de BDD.
-- À lire de haut en bas : la difficulté augmente progressivement.
-- =============================================================================
SET search_path TO codequest, public;

-- =============================================================================
-- NIVEAU 1 — SELECT, WHERE, ORDER BY, LIMIT (les bases)
-- =============================================================================

-- 1.1 Tous les joueurs, du meilleur au pire ELO
SELECT username, display_name, elo_rating, total_xp
FROM users
ORDER BY elo_rating DESC
LIMIT 10;

-- 1.2 Challenges difficiles ou expert
SELECT title, difficulty, xp_reward
FROM challenges
WHERE difficulty IN ('hard', 'expert')
ORDER BY xp_reward DESC;

-- 1.3 Joueurs actifs récemment (LIKE / pattern)
SELECT username, last_active_at
FROM users
WHERE username LIKE 'a%'
  AND last_active_at > NOW() - INTERVAL '30 days';

-- =============================================================================
-- NIVEAU 2 — JOINTURES (INNER, LEFT, multiples)
-- =============================================================================

-- 2.1 Liste des duels avec noms des joueurs (INNER JOIN multiple)
SELECT
    d.duel_id,
    uc.username AS challenger,
    uo.username AS opponent,
    c.title     AS challenge,
    d.status
FROM duels d
JOIN users      uc ON uc.user_id = d.challenger_id
JOIN users      uo ON uo.user_id = d.opponent_id
JOIN challenges c  ON c.challenge_id = d.challenge_id
ORDER BY d.created_at DESC;

-- 2.2 Tous les joueurs et leur guilde principale (LEFT JOIN car certains n'en ont pas)
SELECT
    u.username,
    g.name AS guild_name,
    gm.role
FROM users u
LEFT JOIN guild_members gm ON gm.user_id = u.user_id
LEFT JOIN guilds g         ON g.guild_id = gm.guild_id
ORDER BY u.username;

-- 2.3 Joueurs sans aucune guilde (anti-jointure : LEFT JOIN + IS NULL)
SELECT u.username, u.elo_rating
FROM users u
LEFT JOIN guild_members gm ON gm.user_id = u.user_id
WHERE gm.user_id IS NULL;

-- =============================================================================
-- NIVEAU 3 — AGRÉGATIONS, GROUP BY, HAVING
-- =============================================================================

-- 3.1 Nombre de tentatives par langage
SELECT
    language,
    COUNT(*) AS total_attempts,
    COUNT(*) FILTER (WHERE verdict = 'passed') AS passed,
    ROUND(100.0 * COUNT(*) FILTER (WHERE verdict = 'passed') / COUNT(*), 2) AS pass_rate_pct
FROM attempts
GROUP BY language
ORDER BY pass_rate_pct DESC;

-- 3.2 Challenges les plus tentés (HAVING pour filtrer après agrégation)
SELECT
    c.title,
    COUNT(a.attempt_id) AS attempts_count
FROM challenges c
JOIN attempts a ON a.challenge_id = c.challenge_id
GROUP BY c.challenge_id, c.title
HAVING COUNT(a.attempt_id) > 5
ORDER BY attempts_count DESC;

-- 3.3 Stats agrégées par difficulté
SELECT
    c.difficulty,
    COUNT(DISTINCT c.challenge_id)              AS nb_challenges,
    COUNT(a.attempt_id)                          AS total_attempts,
    AVG(a.execution_ms)::INTEGER                 AS avg_exec_ms,
    MIN(a.execution_ms)                          AS min_exec_ms,
    MAX(a.execution_ms)                          AS max_exec_ms
FROM challenges c
LEFT JOIN attempts a ON a.challenge_id = c.challenge_id
GROUP BY c.difficulty
ORDER BY
    CASE c.difficulty
        WHEN 'easy' THEN 1 WHEN 'medium' THEN 2
        WHEN 'hard' THEN 3 WHEN 'expert' THEN 4
    END;

-- =============================================================================
-- NIVEAU 4 — SOUS-REQUÊTES, EXISTS, IN
-- =============================================================================

-- 4.1 Joueurs ayant résolu AU MOINS un challenge "expert" (EXISTS)
SELECT u.username, u.elo_rating
FROM users u
WHERE EXISTS (
    SELECT 1 FROM attempts a
    JOIN challenges c ON c.challenge_id = a.challenge_id
    WHERE a.user_id = u.user_id
      AND a.verdict = 'passed'
      AND c.difficulty = 'expert'
);

-- 4.2 Joueurs au-dessus de la moyenne ELO globale (sous-requête scalaire)
SELECT username, elo_rating
FROM users
WHERE elo_rating > (SELECT AVG(elo_rating) FROM users)
ORDER BY elo_rating DESC;

-- 4.3 Challenges JAMAIS résolus (NOT EXISTS)
SELECT c.title, c.difficulty
FROM challenges c
WHERE NOT EXISTS (
    SELECT 1 FROM attempts a
    WHERE a.challenge_id = c.challenge_id AND a.verdict = 'passed'
);

-- =============================================================================
-- NIVEAU 5 — WINDOW FUNCTIONS (la pépite du SQL moderne)
-- =============================================================================

-- 5.1 Classement avec RANK et DENSE_RANK
SELECT
    username,
    elo_rating,
    RANK()       OVER (ORDER BY elo_rating DESC) AS rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY elo_rating DESC) AS dense_rank,
    ROW_NUMBER() OVER (ORDER BY elo_rating DESC) AS row_num,
    -- Différence avec le joueur juste au-dessus (LAG)
    LAG(elo_rating, 1) OVER (ORDER BY elo_rating DESC) - elo_rating AS gap_above
FROM users
LIMIT 20;

-- 5.2 Top 3 par difficulté avec PARTITION BY
WITH ranked_solvers AS (
    SELECT
        c.difficulty,
        u.username,
        COUNT(*) AS solved_count,
        ROW_NUMBER() OVER (PARTITION BY c.difficulty ORDER BY COUNT(*) DESC) AS rn
    FROM attempts a
    JOIN users u      ON u.user_id = a.user_id
    JOIN challenges c ON c.challenge_id = a.challenge_id
    WHERE a.verdict = 'passed'
    GROUP BY c.difficulty, u.username
)
SELECT difficulty, username, solved_count
FROM ranked_solvers
WHERE rn <= 3
ORDER BY difficulty, solved_count DESC;

-- 5.3 Moyenne glissante du temps d'exécution (par joueur, sur 5 dernières tentatives)
SELECT
    user_id,
    submitted_at,
    execution_ms,
    AVG(execution_ms) OVER (
        PARTITION BY user_id
        ORDER BY submitted_at
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    )::INTEGER AS moving_avg_5
FROM attempts
WHERE user_id = 1
ORDER BY submitted_at;

-- =============================================================================
-- NIVEAU 6 — CTE (COMMON TABLE EXPRESSIONS), récursivité
-- =============================================================================

-- 6.1 CTE simple : top 5 joueurs et leurs stats
WITH top_players AS (
    SELECT user_id, username, elo_rating
    FROM users
    ORDER BY elo_rating DESC
    LIMIT 5
)
SELECT
    tp.username,
    tp.elo_rating,
    COUNT(a.attempt_id) AS attempts,
    COUNT(DISTINCT a.challenge_id) AS unique_challenges
FROM top_players tp
LEFT JOIN attempts a ON a.user_id = tp.user_id AND a.verdict = 'passed'
GROUP BY tp.user_id, tp.username, tp.elo_rating
ORDER BY tp.elo_rating DESC;

-- 6.2 CTE récursive : amis d'amis (degré 2 du graphe social)
-- Note : les amitiés sont stockées normalisées (requester_id < addressee_id),
-- mais elles sont non-orientées sémantiquement.
WITH RECURSIVE friend_graph AS (
    -- Niveau 1 : amis directs de l'utilisateur 1
    SELECT
        CASE WHEN requester_id = 1 THEN addressee_id ELSE requester_id END AS friend_id,
        1 AS depth
    FROM friendships
    WHERE (requester_id = 1 OR addressee_id = 1)
      AND state = 'accepted'

    UNION

    -- Niveau N+1 : amis des amis (max profondeur 2)
    SELECT
        CASE WHEN f.requester_id = fg.friend_id THEN f.addressee_id ELSE f.requester_id END,
        fg.depth + 1
    FROM friend_graph fg
    JOIN friendships f
        ON (f.requester_id = fg.friend_id OR f.addressee_id = fg.friend_id)
    WHERE fg.depth < 2
      AND f.state = 'accepted'
)
SELECT DISTINCT u.username, MIN(fg.depth) AS connection_degree
FROM friend_graph fg
JOIN users u ON u.user_id = fg.friend_id
WHERE fg.friend_id <> 1
GROUP BY u.username
ORDER BY connection_degree, u.username;

-- 6.3 CTE multi-niveaux pour un rapport complexe
WITH
    user_perf AS (
        SELECT
            a.user_id,
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE a.verdict = 'passed') AS passed
        FROM attempts a
        GROUP BY a.user_id
    ),
    user_ranking AS (
        SELECT
            user_id,
            ROUND(100.0 * passed / NULLIF(total, 0), 2) AS success_rate,
            NTILE(4) OVER (ORDER BY 100.0 * passed / NULLIF(total, 0)) AS quartile
        FROM user_perf
        WHERE total >= 5
    )
SELECT
    u.username,
    u.elo_rating,
    ur.success_rate,
    CASE ur.quartile
        WHEN 1 THEN 'Bottom 25%'
        WHEN 2 THEN '25-50%'
        WHEN 3 THEN '50-75%'
        WHEN 4 THEN 'Top 25%'
    END AS performance_tier
FROM user_ranking ur
JOIN users u ON u.user_id = ur.user_id
ORDER BY ur.success_rate DESC;

-- =============================================================================
-- NIVEAU 7 — JSONB (spécifique PostgreSQL, mais super utile)
-- =============================================================================

-- 7.1 Challenges avec leur premier test case extrait
SELECT
    title,
    test_cases->0->>'input'    AS first_input,
    test_cases->0->>'expected' AS first_expected,
    jsonb_array_length(test_cases) AS nb_tests
FROM challenges
LIMIT 5;

-- 7.2 Recherche dans les tags (tableau Postgres)
SELECT title, tags
FROM challenges
WHERE 'recursion' = ANY(tags)
   OR 'dp' = ANY(tags);

-- 7.3 Statistiques par tag (unnest pour exploser le tableau)
SELECT
    tag,
    COUNT(*) AS nb_challenges,
    AVG(xp_reward)::INTEGER AS avg_xp
FROM challenges, unnest(tags) AS tag
GROUP BY tag
ORDER BY nb_challenges DESC;

-- =============================================================================
-- NIVEAU 8 — REQUÊTES MÉTIER COMPLEXES
-- =============================================================================

-- 8.1 Rivalités : paires de joueurs qui se sont défiés le plus souvent
SELECT
    LEAST(challenger_id, opponent_id)    AS player_a,
    GREATEST(challenger_id, opponent_id) AS player_b,
    COUNT(*) AS duels_count,
    SUM(CASE WHEN winner_id = LEAST(challenger_id, opponent_id) THEN 1 ELSE 0 END) AS wins_a,
    SUM(CASE WHEN winner_id = GREATEST(challenger_id, opponent_id) THEN 1 ELSE 0 END) AS wins_b
FROM duels
WHERE status = 'completed'
GROUP BY LEAST(challenger_id, opponent_id), GREATEST(challenger_id, opponent_id)
HAVING COUNT(*) >= 2
ORDER BY duels_count DESC;

-- 8.2 Détection de "smurfs" : nouveaux comptes avec un taux de réussite anormalement élevé
SELECT
    u.username,
    u.created_at,
    COUNT(a.attempt_id) AS attempts,
    ROUND(100.0 * COUNT(*) FILTER (WHERE a.verdict = 'passed') / COUNT(*), 2) AS pass_rate
FROM users u
JOIN attempts a ON a.user_id = u.user_id
WHERE u.created_at > NOW() - INTERVAL '30 days'
GROUP BY u.user_id, u.username, u.created_at
HAVING COUNT(a.attempt_id) >= 10
   AND 100.0 * COUNT(*) FILTER (WHERE a.verdict = 'passed') / COUNT(*) > 90
ORDER BY pass_rate DESC;

-- 8.3 Recommandation de challenges : ce que les joueurs comme moi ont résolu mais pas moi
-- (collaborative filtering basique)
WITH my_solved AS (
    SELECT DISTINCT challenge_id
    FROM attempts WHERE user_id = 1 AND verdict = 'passed'
),
similar_users AS (
    SELECT user_id
    FROM users
    WHERE user_id <> 1
      AND ABS(elo_rating - (SELECT elo_rating FROM users WHERE user_id = 1)) < 200
)
SELECT
    c.title,
    c.difficulty,
    c.xp_reward,
    COUNT(DISTINCT a.user_id) AS solved_by_similar_users
FROM attempts a
JOIN challenges c ON c.challenge_id = a.challenge_id
WHERE a.user_id IN (SELECT user_id FROM similar_users)
  AND a.verdict = 'passed'
  AND a.challenge_id NOT IN (SELECT challenge_id FROM my_solved)
GROUP BY c.challenge_id, c.title, c.difficulty, c.xp_reward
ORDER BY solved_by_similar_users DESC
LIMIT 5;

-- =============================================================================
-- NIVEAU 9 — TRANSACTIONS (illustration)
-- =============================================================================
-- En vrai, à exécuter une instruction à la fois.

-- BEGIN;
--   INSERT INTO duels (challenger_id, opponent_id, challenge_id, xp_stake, status)
--   VALUES (1, 2, 5, 100, 'pending')
--   RETURNING duel_id;
--
--   -- Si tout va bien :
-- COMMIT;
--   -- Sinon :
-- -- ROLLBACK;

-- =============================================================================
-- NIVEAU 10 — EXPLAIN (analyse de performance)
-- =============================================================================
-- EXPLAIN ANALYZE
-- SELECT u.username, COUNT(a.attempt_id)
-- FROM users u
-- JOIN attempts a ON a.user_id = u.user_id
-- WHERE a.verdict = 'passed'
-- GROUP BY u.username
-- ORDER BY COUNT(*) DESC
-- LIMIT 10;

-- Compare avec et sans l'index idx_attempts_user pour voir la différence.
