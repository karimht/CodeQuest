-- =============================================================================
-- CodeQuest — Schéma de base de données
-- SGBD : PostgreSQL 14+
-- =============================================================================
-- Ce fichier crée toutes les tables, contraintes, index et types personnalisés.
-- Ordre : types ENUM → tables → contraintes → index.
-- =============================================================================

-- Nettoyage (utile pour les re-runs en TP)
DROP SCHEMA IF EXISTS codequest CASCADE;
CREATE SCHEMA codequest;
SET search_path TO codequest, public;

-- -----------------------------------------------------------------------------
-- TYPES ENUM
-- -----------------------------------------------------------------------------
CREATE TYPE difficulty_level AS ENUM ('easy', 'medium', 'hard', 'expert');
CREATE TYPE duel_status      AS ENUM ('pending', 'active', 'completed', 'cancelled');
CREATE TYPE attempt_verdict  AS ENUM ('passed', 'failed', 'timeout', 'runtime_error');
CREATE TYPE programming_lang AS ENUM ('python', 'javascript', 'java', 'cpp', 'rust', 'go');
CREATE TYPE friendship_state AS ENUM ('pending', 'accepted', 'blocked');

-- -----------------------------------------------------------------------------
-- TABLE : users
-- Les joueurs de la plateforme.
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    user_id        SERIAL PRIMARY KEY,
    username       VARCHAR(30)  NOT NULL UNIQUE,
    email          VARCHAR(120) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    display_name   VARCHAR(60)  NOT NULL,
    elo_rating     INTEGER      NOT NULL DEFAULT 1000,
    total_xp       INTEGER      NOT NULL DEFAULT 0,
    country_code   CHAR(2),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_username_format CHECK (username ~ '^[a-zA-Z0-9_]{3,30}$'),
    CONSTRAINT chk_email_format    CHECK (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
    CONSTRAINT chk_elo_positive    CHECK (elo_rating >= 0),
    CONSTRAINT chk_xp_positive     CHECK (total_xp >= 0)
);

COMMENT ON TABLE users IS 'Comptes joueurs de la plateforme CodeQuest';
COMMENT ON COLUMN users.elo_rating IS 'Score ELO recalculé à chaque duel terminé';

-- -----------------------------------------------------------------------------
-- TABLE : guilds
-- Communautés/clans de joueurs.
-- -----------------------------------------------------------------------------
CREATE TABLE guilds (
    guild_id    SERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,
    tag         VARCHAR(6)  NOT NULL UNIQUE,    -- tag court type [DEV] affiché à côté du pseudo
    description TEXT,
    leader_id   INTEGER NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_guild_leader FOREIGN KEY (leader_id)
        REFERENCES users(user_id) ON DELETE RESTRICT,
    CONSTRAINT chk_tag_format CHECK (tag ~ '^[A-Z0-9]{2,6}$')
);

-- -----------------------------------------------------------------------------
-- TABLE : guild_members (association N-N entre users et guilds)
-- Un joueur peut appartenir à plusieurs guildes.
-- -----------------------------------------------------------------------------
CREATE TABLE guild_members (
    user_id   INTEGER NOT NULL,
    guild_id  INTEGER NOT NULL,
    role      VARCHAR(20) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, guild_id),
    CONSTRAINT fk_gm_user  FOREIGN KEY (user_id)  REFERENCES users(user_id)  ON DELETE CASCADE,
    CONSTRAINT fk_gm_guild FOREIGN KEY (guild_id) REFERENCES guilds(guild_id) ON DELETE CASCADE,
    CONSTRAINT chk_role CHECK (role IN ('leader', 'officer', 'member'))
);

-- -----------------------------------------------------------------------------
-- TABLE : friendships
-- Relations d'amitié (graphe social non orienté, normalisé via requester < addressee).
-- -----------------------------------------------------------------------------
CREATE TABLE friendships (
    requester_id INTEGER NOT NULL,
    addressee_id INTEGER NOT NULL,
    state        friendship_state NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,

    PRIMARY KEY (requester_id, addressee_id),
    CONSTRAINT fk_friend_req FOREIGN KEY (requester_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_friend_add FOREIGN KEY (addressee_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_no_self_friend CHECK (requester_id <> addressee_id),
    -- Astuce : on impose un ordre pour éviter les doublons (A→B et B→A)
    CONSTRAINT chk_friend_order CHECK (requester_id < addressee_id)
);

-- -----------------------------------------------------------------------------
-- TABLE : challenges
-- Défis de programmation (énoncés). On stocke les cas de test en JSONB.
-- -----------------------------------------------------------------------------
CREATE TABLE challenges (
    challenge_id   SERIAL PRIMARY KEY,
    title          VARCHAR(120) NOT NULL,
    slug           VARCHAR(120) NOT NULL UNIQUE,
    statement      TEXT         NOT NULL,
    difficulty     difficulty_level NOT NULL,
    xp_reward      INTEGER      NOT NULL,
    time_limit_ms  INTEGER      NOT NULL DEFAULT 2000,
    author_id      INTEGER,                  -- NULL si défi officiel
    test_cases     JSONB        NOT NULL,    -- [{input: "...", expected: "..."}, ...]
    tags           TEXT[]       NOT NULL DEFAULT '{}',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    is_published   BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_challenge_author FOREIGN KEY (author_id)
        REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT chk_xp_reward_pos  CHECK (xp_reward > 0),
    CONSTRAINT chk_time_limit_pos CHECK (time_limit_ms > 0),
    CONSTRAINT chk_has_tests      CHECK (jsonb_array_length(test_cases) > 0)
);

COMMENT ON COLUMN challenges.test_cases IS
    'Tableau JSONB : [{"input":"...", "expected":"..."}, ...]';

-- -----------------------------------------------------------------------------
-- TABLE : duels
-- Affrontements 1v1 entre deux joueurs sur un challenge donné.
-- -----------------------------------------------------------------------------
CREATE TABLE duels (
    duel_id       SERIAL PRIMARY KEY,
    challenger_id INTEGER NOT NULL,
    opponent_id   INTEGER NOT NULL,
    challenge_id  INTEGER NOT NULL,
    xp_stake      INTEGER NOT NULL DEFAULT 50,
    status        duel_status NOT NULL DEFAULT 'pending',
    winner_id     INTEGER,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at    TIMESTAMPTZ,
    ended_at      TIMESTAMPTZ,

    CONSTRAINT fk_duel_challenger FOREIGN KEY (challenger_id) REFERENCES users(user_id)      ON DELETE CASCADE,
    CONSTRAINT fk_duel_opponent   FOREIGN KEY (opponent_id)   REFERENCES users(user_id)      ON DELETE CASCADE,
    CONSTRAINT fk_duel_challenge  FOREIGN KEY (challenge_id)  REFERENCES challenges(challenge_id) ON DELETE RESTRICT,
    CONSTRAINT fk_duel_winner     FOREIGN KEY (winner_id)     REFERENCES users(user_id)      ON DELETE SET NULL,

    CONSTRAINT chk_distinct_players CHECK (challenger_id <> opponent_id),
    CONSTRAINT chk_xp_stake_pos     CHECK (xp_stake >= 0),
    CONSTRAINT chk_winner_is_player CHECK (
        winner_id IS NULL OR winner_id IN (challenger_id, opponent_id)
    ),
    CONSTRAINT chk_winner_only_if_completed CHECK (
        (status = 'completed' AND winner_id IS NOT NULL) OR
        (status <> 'completed')
    ),
    CONSTRAINT chk_timing CHECK (
        (started_at IS NULL OR started_at >= created_at) AND
        (ended_at   IS NULL OR ended_at   >= started_at)
    )
);

-- -----------------------------------------------------------------------------
-- TABLE : attempts
-- Soumissions de code (dans un duel ou en entraînement libre).
-- -----------------------------------------------------------------------------
CREATE TABLE attempts (
    attempt_id      BIGSERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL,
    challenge_id    INTEGER NOT NULL,
    duel_id         INTEGER,                       -- NULL si entraînement libre
    language        programming_lang NOT NULL,
    source_code     TEXT NOT NULL,
    verdict         attempt_verdict NOT NULL,
    execution_ms    INTEGER,                       -- temps d'exécution
    tests_passed    SMALLINT NOT NULL DEFAULT 0,
    tests_total     SMALLINT NOT NULL,
    submitted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_attempt_user      FOREIGN KEY (user_id)      REFERENCES users(user_id)           ON DELETE CASCADE,
    CONSTRAINT fk_attempt_challenge FOREIGN KEY (challenge_id) REFERENCES challenges(challenge_id) ON DELETE CASCADE,
    CONSTRAINT fk_attempt_duel      FOREIGN KEY (duel_id)      REFERENCES duels(duel_id)           ON DELETE SET NULL,

    CONSTRAINT chk_tests_consistent CHECK (tests_passed >= 0 AND tests_passed <= tests_total),
    CONSTRAINT chk_exec_positive    CHECK (execution_ms IS NULL OR execution_ms >= 0)
);

-- -----------------------------------------------------------------------------
-- TABLE : badges (référentiel)
-- -----------------------------------------------------------------------------
CREATE TABLE badges (
    badge_id    SERIAL PRIMARY KEY,
    code        VARCHAR(40) NOT NULL UNIQUE,
    name        VARCHAR(80) NOT NULL,
    description TEXT NOT NULL,
    icon        VARCHAR(20),
    rarity      VARCHAR(10) NOT NULL,

    CONSTRAINT chk_rarity CHECK (rarity IN ('common', 'rare', 'epic', 'legendary'))
);

-- -----------------------------------------------------------------------------
-- TABLE : user_badges (badges débloqués par les joueurs)
-- -----------------------------------------------------------------------------
CREATE TABLE user_badges (
    user_id     INTEGER NOT NULL,
    badge_id    INTEGER NOT NULL,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, badge_id),
    CONSTRAINT fk_ub_user  FOREIGN KEY (user_id)  REFERENCES users(user_id)   ON DELETE CASCADE,
    CONSTRAINT fk_ub_badge FOREIGN KEY (badge_id) REFERENCES badges(badge_id) ON DELETE CASCADE
);

-- =============================================================================
-- INDEX
-- =============================================================================
-- Index sur les FK fréquemment jointes
CREATE INDEX idx_attempts_user            ON attempts(user_id);
CREATE INDEX idx_attempts_challenge       ON attempts(challenge_id);
CREATE INDEX idx_attempts_duel            ON attempts(duel_id) WHERE duel_id IS NOT NULL;
CREATE INDEX idx_attempts_submitted_at    ON attempts(submitted_at DESC);

CREATE INDEX idx_duels_challenger         ON duels(challenger_id);
CREATE INDEX idx_duels_opponent           ON duels(opponent_id);
CREATE INDEX idx_duels_status             ON duels(status);
CREATE INDEX idx_duels_active             ON duels(status) WHERE status IN ('pending', 'active');

CREATE INDEX idx_users_elo                ON users(elo_rating DESC);
CREATE INDEX idx_users_total_xp           ON users(total_xp DESC);

CREATE INDEX idx_challenges_difficulty    ON challenges(difficulty);
CREATE INDEX idx_challenges_tags          ON challenges USING GIN(tags);
CREATE INDEX idx_challenges_test_cases    ON challenges USING GIN(test_cases);

CREATE INDEX idx_friendships_addressee    ON friendships(addressee_id);
CREATE INDEX idx_friendships_state        ON friendships(state);
