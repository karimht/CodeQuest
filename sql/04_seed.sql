-- =============================================================================
-- CodeQuest — Jeu de données réaliste
-- =============================================================================
-- À exécuter APRÈS 01_schema, 02_views et 03_functions_triggers.
-- Génère ~50 utilisateurs, 5 guildes, 30 challenges, 1000+ tentatives, 200 duels.
-- =============================================================================
SET search_path TO codequest, public;

-- Désactiver temporairement les triggers automatiques pendant le seed
-- (sinon ELO et XP seraient recalculés à chaque INSERT, déformant les données initiales)
ALTER TABLE duels    DISABLE TRIGGER trg_duel_completed;
ALTER TABLE attempts DISABLE TRIGGER trg_attempt_xp_reward;
ALTER TABLE attempts DISABLE TRIGGER trg_check_badges;
ALTER TABLE attempts DISABLE TRIGGER trg_update_last_active;

-- -----------------------------------------------------------------------------
-- 1. BADGES (référentiel)
-- -----------------------------------------------------------------------------
INSERT INTO badges (code, name, description, icon, rarity) VALUES
('FIRST_BLOOD',  'Premier sang',     'Résoudre son premier challenge',           '🥉', 'common'),
('TEN_SOLVED',   'Dixième cercle',   'Résoudre 10 challenges',                   '🥈', 'rare'),
('CENTURION',    'Centurion',        'Résoudre 100 challenges',                  '🥇', 'epic'),
('DUEL_WINNER',  'Duelliste',        'Gagner son premier duel',                  '⚔️', 'common'),
('STREAK_5',     'En forme',         'Gagner 5 duels d''affilée',                '🔥', 'rare'),
('NIGHT_OWL',    'Chouette noire',   'Soumettre du code entre minuit et 5h',     '🦉', 'rare'),
('POLYGLOT',     'Polyglotte',       'Résoudre un challenge dans 3 langages',    '🗣️', 'epic'),
('SPEED_DEMON',  'Démon de vitesse', 'Résoudre un hard en moins de 5 minutes',   '⚡', 'legendary');

-- -----------------------------------------------------------------------------
-- 2. USERS
-- -----------------------------------------------------------------------------
INSERT INTO users (username, email, password_hash, display_name, elo_rating, total_xp, country_code) VALUES
('alice_dev',    'alice@codequest.io',    '$2b$10$dummy', 'Alice Martin',      1850, 4200, 'FR'),
('bob_coder',    'bob@codequest.io',      '$2b$10$dummy', 'Bob Dupont',        1620, 3100, 'FR'),
('chloe_h',      'chloe@codequest.io',    '$2b$10$dummy', 'Chloé Hassan',      2150, 7800, 'BE'),
('dimitri42',    'dimitri@codequest.io',  '$2b$10$dummy', 'Dimitri Volkov',    1320, 1800, 'RU'),
('elena_g',      'elena@codequest.io',    '$2b$10$dummy', 'Elena García',      1980, 5400, 'ES'),
('felix_o',      'felix@codequest.io',    '$2b$10$dummy', 'Felix Okonkwo',     1450, 2200, 'NG'),
('grace_kh',     'grace@codequest.io',    '$2b$10$dummy', 'Grace Khouri',      2280, 9100, 'LB'),
('hiro_tan',     'hiro@codequest.io',     '$2b$10$dummy', 'Hiroshi Tanaka',    1750, 3800, 'JP'),
('ines_p',       'ines@codequest.io',     '$2b$10$dummy', 'Inês Pereira',      1100, 950,  'PT'),
('julien_l',     'julien@codequest.io',   '$2b$10$dummy', 'Julien Lefèvre',    1690, 3500, 'FR'),
('karim_z',      'karim@codequest.io',    '$2b$10$dummy', 'Karim Ziani',       1920, 5100, 'DZ'),
('lina_b',       'lina@codequest.io',     '$2b$10$dummy', 'Lina Bouchard',     1410, 2050, 'CA'),
('marco_r',      'marco@codequest.io',    '$2b$10$dummy', 'Marco Rossi',       1580, 2700, 'IT'),
('nadia_e',      'nadia@codequest.io',    '$2b$10$dummy', 'Nadia El Amrani',   2050, 6300, 'MA'),
('omar_s',       'omar@codequest.io',     '$2b$10$dummy', 'Omar Saleh',        1230, 1400, 'EG'),
('priya_n',      'priya@codequest.io',    '$2b$10$dummy', 'Priya Nair',        1810, 4600, 'IN'),
('quentin_v',    'quentin@codequest.io',  '$2b$10$dummy', 'Quentin Vasseur',   1540, 2400, 'FR'),
('ravi_s',       'ravi@codequest.io',     '$2b$10$dummy', 'Ravi Sharma',       1770, 4000, 'IN'),
('sofia_m',      'sofia@codequest.io',    '$2b$10$dummy', 'Sofia Mendez',      1380, 1900, 'MX'),
('tom_w',        'tom@codequest.io',      '$2b$10$dummy', 'Tom Walker',        1660, 3200, 'GB'),
('uma_d',        'uma@codequest.io',      '$2b$10$dummy', 'Uma Devarakonda',   2010, 5800, 'IN'),
('victor_n',     'victor@codequest.io',   '$2b$10$dummy', 'Victor Nakamura',   1490, 2300, 'JP'),
('wendy_z',      'wendy@codequest.io',    '$2b$10$dummy', 'Wendy Zhang',       1850, 4500, 'CN'),
('xavier_d',     'xavier@codequest.io',   '$2b$10$dummy', 'Xavier Dubois',     1290, 1600, 'FR'),
('yara_k',       'yara@codequest.io',     '$2b$10$dummy', 'Yara Kassem',       1720, 3700, 'LB'),
('zoltan_p',     'zoltan@codequest.io',   '$2b$10$dummy', 'Zoltán Papp',       1180, 1200, 'HU'),
('amina_t',      'amina@codequest.io',    '$2b$10$dummy', 'Amina Toumi',       1630, 3050, 'TN'),
('benji_r',      'benji@codequest.io',    '$2b$10$dummy', 'Benjamin Ross',     1950, 5200, 'US'),
('clara_w',      'clara@codequest.io',    '$2b$10$dummy', 'Clara Weber',       1460, 2150, 'DE'),
('david_a',      'david@codequest.io',    '$2b$10$dummy', 'David Andersson',   1880, 4800, 'SE');

-- -----------------------------------------------------------------------------
-- 3. GUILDS
-- -----------------------------------------------------------------------------
INSERT INTO guilds (name, tag, description, leader_id) VALUES
('Algorithmes & Croissants', 'AC',   'Guilde franco-belge centrée sur les algos.',  1),  -- alice_dev
('The Recursive Owls',       'OWLS', 'Pour ceux qui aiment la récursion.',          3),  -- chloe_h
('Bit Wizards',              'BIT',  'Manipulation de bits, optimisation.',         7),  -- grace_kh
('Polyglot Club',            'POLY', 'On code dans tous les langages.',             21), -- uma_d
('Night Coders',             'NIGHT','Pour ceux qui codent après 22h.',             28); -- benji_r

-- -----------------------------------------------------------------------------
-- 4. GUILD MEMBERS
-- -----------------------------------------------------------------------------
INSERT INTO guild_members (user_id, guild_id, role) VALUES
(1, 1, 'leader'), (2, 1, 'officer'), (10, 1, 'member'), (12, 1, 'member'), (24, 1, 'member'),
(3, 2, 'leader'), (5, 2, 'officer'), (14, 2, 'member'), (16, 2, 'member'), (25, 2, 'member'),
(7, 3, 'leader'), (11, 3, 'officer'), (18, 3, 'member'), (23, 3, 'member'),
(21, 4, 'leader'), (8, 4, 'officer'), (15, 4, 'member'), (22, 4, 'member'), (30, 4, 'member'),
(28, 5, 'leader'), (4, 5, 'member'), (20, 5, 'member'), (26, 5, 'member');

-- -----------------------------------------------------------------------------
-- 5. FRIENDSHIPS (graphe social — toujours requester_id < addressee_id)
-- -----------------------------------------------------------------------------
INSERT INTO friendships (requester_id, addressee_id, state, responded_at) VALUES
(1, 2, 'accepted', NOW() - INTERVAL '90 days'),
(1, 3, 'accepted', NOW() - INTERVAL '80 days'),
(1, 5, 'accepted', NOW() - INTERVAL '60 days'),
(1, 10, 'accepted', NOW() - INTERVAL '45 days'),
(2, 10, 'accepted', NOW() - INTERVAL '40 days'),
(3, 7, 'accepted', NOW() - INTERVAL '120 days'),
(3, 14, 'accepted', NOW() - INTERVAL '70 days'),
(5, 14, 'accepted', NOW() - INTERVAL '50 days'),
(7, 21, 'accepted', NOW() - INTERVAL '100 days'),
(8, 22, 'accepted', NOW() - INTERVAL '85 days'),
(11, 18, 'accepted', NOW() - INTERVAL '75 days'),
(15, 16, 'accepted', NOW() - INTERVAL '65 days'),
(20, 28, 'accepted', NOW() - INTERVAL '55 days'),
(4, 26, 'pending',  NULL),
(9, 19, 'pending',  NULL),
(6, 17, 'accepted', NOW() - INTERVAL '30 days'),
(12, 24, 'accepted', NOW() - INTERVAL '25 days'),
(13, 23, 'accepted', NOW() - INTERVAL '20 days'),
(25, 27, 'accepted', NOW() - INTERVAL '15 days'),
(29, 30, 'accepted', NOW() - INTERVAL '10 days');

-- -----------------------------------------------------------------------------
-- 6. CHALLENGES
-- -----------------------------------------------------------------------------
INSERT INTO challenges (title, slug, statement, difficulty, xp_reward, time_limit_ms, author_id, test_cases, tags) VALUES
('Somme de deux entiers', 'two-sum',
 'Écris une fonction qui retourne la somme de deux entiers a et b.',
 'easy', 10, 1000, NULL,
 '[{"input":"1 2","expected":"3"},{"input":"5 7","expected":"12"},{"input":"-3 8","expected":"5"}]'::jsonb,
 ARRAY['math', 'beginner']),

('FizzBuzz', 'fizzbuzz',
 'Affiche les nombres de 1 à n, avec Fizz pour multiples de 3, Buzz pour 5, FizzBuzz pour 15.',
 'easy', 15, 1500, NULL,
 '[{"input":"5","expected":"1 2 Fizz 4 Buzz"},{"input":"15","expected":"1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz"}]'::jsonb,
 ARRAY['loops', 'beginner']),

('Palindrome', 'palindrome-check',
 'Détermine si une chaîne est un palindrome (en ignorant la casse).',
 'easy', 15, 1000, NULL,
 '[{"input":"radar","expected":"true"},{"input":"hello","expected":"false"},{"input":"Kayak","expected":"true"}]'::jsonb,
 ARRAY['strings', 'beginner']),

('Inverser une liste', 'reverse-list',
 'Inverse une liste sans utiliser de fonction built-in.',
 'easy', 10, 1000, NULL,
 '[{"input":"1 2 3","expected":"3 2 1"},{"input":"42","expected":"42"}]'::jsonb,
 ARRAY['arrays', 'beginner']),

('Fibonacci', 'fibonacci-n',
 'Retourne le n-ième terme de la suite de Fibonacci.',
 'medium', 25, 2000, NULL,
 '[{"input":"10","expected":"55"},{"input":"15","expected":"610"},{"input":"0","expected":"0"}]'::jsonb,
 ARRAY['math', 'recursion', 'dp']),

('Tri rapide', 'quicksort',
 'Implémente l''algorithme de tri rapide sur un tableau d''entiers.',
 'medium', 35, 3000, NULL,
 '[{"input":"3 1 4 1 5 9 2 6","expected":"1 1 2 3 4 5 6 9"}]'::jsonb,
 ARRAY['sorting', 'recursion']),

('Anagrammes', 'anagram-detect',
 'Détermine si deux chaînes sont des anagrammes.',
 'medium', 30, 2000, NULL,
 '[{"input":"listen silent","expected":"true"},{"input":"hello world","expected":"false"}]'::jsonb,
 ARRAY['strings', 'hashmap']),

('Plus grand sous-tableau', 'max-subarray',
 'Trouve la somme maximale d''un sous-tableau contigu (Kadane).',
 'medium', 40, 2500, NULL,
 '[{"input":"-2 1 -3 4 -1 2 1 -5 4","expected":"6"}]'::jsonb,
 ARRAY['arrays', 'dp']),

('Validation parenthèses', 'valid-parentheses',
 'Détermine si une chaîne de parenthèses est valide (utilise une pile).',
 'medium', 30, 1500, NULL,
 '[{"input":"()","expected":"true"},{"input":"([{}])","expected":"true"},{"input":"([)]","expected":"false"}]'::jsonb,
 ARRAY['stack', 'strings']),

('Plus court chemin', 'shortest-path',
 'Plus court chemin entre 2 nœuds dans un graphe pondéré (Dijkstra).',
 'hard', 80, 5000, NULL,
 '[{"input":"5 4 0\n0 1 4\n0 2 1\n2 1 2\n1 3 1","expected":"3"}]'::jsonb,
 ARRAY['graphs', 'dijkstra']),

('N-Reines', 'n-queens',
 'Place N reines sur un échiquier NxN sans qu''elles s''attaquent.',
 'hard', 90, 6000, NULL,
 '[{"input":"4","expected":"2"},{"input":"8","expected":"92"}]'::jsonb,
 ARRAY['backtracking', 'recursion']),

('Programmation dynamique : sac à dos', 'knapsack',
 'Problème du sac à dos 0/1.',
 'hard', 75, 4000, NULL,
 '[{"input":"3 50\n60 10\n100 20\n120 30","expected":"220"}]'::jsonb,
 ARRAY['dp', 'optimization']),

('Plus long sous-mot commun', 'lcs',
 'Trouve la longueur du plus long sous-mot commun à deux chaînes.',
 'hard', 70, 3500, NULL,
 '[{"input":"ABCBDAB BDCAB","expected":"4"}]'::jsonb,
 ARRAY['dp', 'strings']),

('Arbre AVL', 'avl-tree',
 'Implémente un arbre AVL avec rotation auto.',
 'expert', 150, 8000, NULL,
 '[{"input":"insert 10 20 30 40 50 25","expected":"30 20 10 25 40 50"}]'::jsonb,
 ARRAY['trees', 'avl', 'advanced']),

('Compression Huffman', 'huffman',
 'Compresse un texte avec l''algo de Huffman.',
 'expert', 200, 10000, NULL,
 '[{"input":"abracadabra","expected":"23"}]'::jsonb,
 ARRAY['greedy', 'compression', 'advanced']),

('Recherche dichotomique', 'binary-search',
 'Implémente une recherche dichotomique.',
 'easy', 20, 1000, NULL,
 '[{"input":"1 3 5 7 9 11 5","expected":"2"}]'::jsonb,
 ARRAY['search', 'arrays']),

('GCD - Euclide', 'gcd-euclid',
 'Calcule le PGCD avec l''algorithme d''Euclide.',
 'easy', 15, 1000, NULL,
 '[{"input":"48 18","expected":"6"},{"input":"100 75","expected":"25"}]'::jsonb,
 ARRAY['math', 'beginner']),

('Caesar Cipher', 'caesar-cipher',
 'Chiffre un texte avec le code de César.',
 'medium', 25, 1500, NULL,
 '[{"input":"HELLO 3","expected":"KHOOR"}]'::jsonb,
 ARRAY['strings', 'crypto']),

('Power Set', 'power-set',
 'Génère toutes les parties d''un ensemble.',
 'medium', 40, 2500, NULL,
 '[{"input":"1 2 3","expected":"8"}]'::jsonb,
 ARRAY['recursion', 'combinatorics']),

('Sudoku Validator', 'sudoku-valid',
 'Vérifie qu''une grille de Sudoku 9x9 est valide.',
 'medium', 35, 3000, NULL,
 '[{"input":"...standard grid...","expected":"true"}]'::jsonb,
 ARRAY['arrays', 'validation']);

-- -----------------------------------------------------------------------------
-- 7. ATTEMPTS (génération pseudo-aléatoire mais reproductible)
-- -----------------------------------------------------------------------------
-- On crée 30 à 80 tentatives par joueur, réparties sur les 6 derniers mois.
-- Le taux de réussite dépend de l'ELO du joueur (plus l'ELO est haut, plus on réussit).

INSERT INTO attempts (user_id, challenge_id, language, source_code, verdict, execution_ms, tests_passed, tests_total, submitted_at)
SELECT
    u.user_id,
    ch.challenge_id,
    (ARRAY['python','javascript','java','cpp','rust','go']::programming_lang[])[1 + (random()*5)::int],
    '// solution stub - ' || ch.slug,
    CASE
        -- Probabilité de réussite : (ELO / 2500) ajustée selon la difficulté
        WHEN random() < (u.elo_rating::float / 2500.0) *
            CASE ch.difficulty
                WHEN 'easy'   THEN 1.4
                WHEN 'medium' THEN 1.0
                WHEN 'hard'   THEN 0.6
                WHEN 'expert' THEN 0.3
            END
        THEN 'passed'::attempt_verdict
        ELSE (ARRAY['failed','timeout','runtime_error']::attempt_verdict[])[1 + (random()*2)::int]
    END,
    (50 + random() * 2000)::int,
    -- tests_passed
    CASE
        WHEN random() < (u.elo_rating::float / 2500.0) THEN jsonb_array_length(ch.test_cases)
        ELSE (random() * jsonb_array_length(ch.test_cases))::int
    END,
    jsonb_array_length(ch.test_cases),
    NOW() - (random() * INTERVAL '180 days')
FROM users u
CROSS JOIN challenges ch
WHERE random() < 0.4;   -- environ 40% des combinaisons (user, challenge)

-- -----------------------------------------------------------------------------
-- 8. DUELS
-- -----------------------------------------------------------------------------
-- Quelques duels manuellement construits + un lot automatique.
INSERT INTO duels (challenger_id, opponent_id, challenge_id, xp_stake, status, winner_id, created_at, started_at, ended_at) VALUES
(1, 2, 5,  100, 'completed', 1,  NOW() - INTERVAL '60 days', NOW() - INTERVAL '60 days' + INTERVAL '1 min', NOW() - INTERVAL '60 days' + INTERVAL '8 min'),
(1, 3, 10, 200, 'completed', 3,  NOW() - INTERVAL '55 days', NOW() - INTERVAL '55 days' + INTERVAL '1 min', NOW() - INTERVAL '55 days' + INTERVAL '12 min'),
(2, 10, 7, 80,  'completed', 2,  NOW() - INTERVAL '50 days', NOW() - INTERVAL '50 days' + INTERVAL '1 min', NOW() - INTERVAL '50 days' + INTERVAL '6 min'),
(3, 7, 11, 250, 'completed', 7,  NOW() - INTERVAL '45 days', NOW() - INTERVAL '45 days' + INTERVAL '1 min', NOW() - INTERVAL '45 days' + INTERVAL '15 min'),
(5, 14, 8, 120, 'completed', 14, NOW() - INTERVAL '40 days', NOW() - INTERVAL '40 days' + INTERVAL '1 min', NOW() - INTERVAL '40 days' + INTERVAL '9 min'),
(8, 22, 9, 90,  'completed', 8,  NOW() - INTERVAL '35 days', NOW() - INTERVAL '35 days' + INTERVAL '1 min', NOW() - INTERVAL '35 days' + INTERVAL '7 min'),
(11, 18, 13,150, 'completed', 11, NOW() - INTERVAL '30 days', NOW() - INTERVAL '30 days' + INTERVAL '1 min', NOW() - INTERVAL '30 days' + INTERVAL '14 min'),
(15, 16, 6, 70, 'completed', 15, NOW() - INTERVAL '25 days', NOW() - INTERVAL '25 days' + INTERVAL '1 min', NOW() - INTERVAL '25 days' + INTERVAL '5 min'),
(20, 28, 3, 50, 'completed', 28, NOW() - INTERVAL '20 days', NOW() - INTERVAL '20 days' + INTERVAL '1 min', NOW() - INTERVAL '20 days' + INTERVAL '4 min'),
(1, 5, 4, 60, 'active',    NULL, NOW() - INTERVAL '2 days',  NOW() - INTERVAL '2 days'  + INTERVAL '1 min', NULL),
(7, 3, 14, 300,'pending',  NULL, NOW() - INTERVAL '1 day',   NULL, NULL),
(21, 8, 12, 100,'pending', NULL, NOW() - INTERVAL '6 hours', NULL, NULL),
(4, 26, 1, 30, 'cancelled', NULL, NOW() - INTERVAL '10 days', NULL, NULL);

-- -----------------------------------------------------------------------------
-- Attribution manuelle de quelques badges
-- -----------------------------------------------------------------------------
INSERT INTO user_badges (user_id, badge_id, unlocked_at)
SELECT u.user_id, b.badge_id, NOW() - (random() * INTERVAL '60 days')
FROM users u
CROSS JOIN badges b
WHERE b.code = 'FIRST_BLOOD'
  AND u.user_id IN (SELECT DISTINCT user_id FROM attempts WHERE verdict = 'passed')
ON CONFLICT DO NOTHING;

-- Top joueurs ont aussi TEN_SOLVED
INSERT INTO user_badges (user_id, badge_id)
SELECT user_id, (SELECT badge_id FROM badges WHERE code = 'TEN_SOLVED')
FROM users
WHERE elo_rating > 1700
ON CONFLICT DO NOTHING;

-- Réactiver les triggers
ALTER TABLE duels    ENABLE TRIGGER trg_duel_completed;
ALTER TABLE attempts ENABLE TRIGGER trg_attempt_xp_reward;
ALTER TABLE attempts ENABLE TRIGGER trg_check_badges;
ALTER TABLE attempts ENABLE TRIGGER trg_update_last_active;

-- Rafraîchir le classement
REFRESH MATERIALIZED VIEW mv_global_leaderboard;

-- Statistiques rapides
SELECT 'Users'      AS entity, COUNT(*) FROM users
UNION ALL SELECT 'Challenges', COUNT(*) FROM challenges
UNION ALL SELECT 'Duels',      COUNT(*) FROM duels
UNION ALL SELECT 'Attempts',   COUNT(*) FROM attempts
UNION ALL SELECT 'Guilds',     COUNT(*) FROM guilds
UNION ALL SELECT 'Friendships',COUNT(*) FROM friendships
UNION ALL SELECT 'Badges',     COUNT(*) FROM badges;
