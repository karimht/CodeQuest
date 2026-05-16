-- =============================================================================
-- CodeQuest — Fonctions et triggers
-- =============================================================================
-- Démontre : PL/pgSQL, triggers BEFORE/AFTER, fonctions de calcul ELO,
-- attribution automatique de badges, audit de modifications.
-- =============================================================================
SET search_path TO codequest, public;

-- -----------------------------------------------------------------------------
-- FONCTION : calculate_elo_change
-- Calcule la variation d'ELO selon la formule classique d'Arpad Elo.
-- K = 32 pour les joueurs < 2100, K = 16 sinon.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_elo_change(
    winner_elo INTEGER,
    loser_elo  INTEGER
) RETURNS INTEGER AS $$
DECLARE
    k_factor          INTEGER;
    expected_winner   NUMERIC;
    delta             INTEGER;
BEGIN
    k_factor := CASE WHEN winner_elo < 2100 THEN 32 ELSE 16 END;

    -- Probabilité attendue de victoire du gagnant
    expected_winner := 1.0 / (1.0 + POWER(10, (loser_elo - winner_elo) / 400.0));

    -- Variation (toujours positive pour le gagnant)
    delta := ROUND(k_factor * (1 - expected_winner))::INTEGER;

    RETURN GREATEST(delta, 1);   -- minimum 1 point
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_elo_change IS
'Retourne le nombre de points ELO à transférer du perdant au gagnant.';

-- -----------------------------------------------------------------------------
-- FONCTION : apply_duel_result
-- Applique le résultat d'un duel : met à jour ELO et XP des deux joueurs.
-- Appelée par le trigger trg_duel_completed.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apply_duel_result(p_duel_id INTEGER)
RETURNS VOID AS $$
DECLARE
    v_winner_id   INTEGER;
    v_loser_id    INTEGER;
    v_xp_stake    INTEGER;
    v_winner_elo  INTEGER;
    v_loser_elo   INTEGER;
    v_elo_delta   INTEGER;
BEGIN
    -- Charger les infos du duel
    SELECT
        winner_id,
        CASE WHEN winner_id = challenger_id THEN opponent_id ELSE challenger_id END,
        xp_stake
    INTO v_winner_id, v_loser_id, v_xp_stake
    FROM duels
    WHERE duel_id = p_duel_id;

    IF v_winner_id IS NULL THEN
        RAISE EXCEPTION 'Le duel % n''a pas de gagnant', p_duel_id;
    END IF;

    -- Récupérer les ELO actuels (verrouillage pour éviter race conditions)
    SELECT elo_rating INTO v_winner_elo FROM users WHERE user_id = v_winner_id FOR UPDATE;
    SELECT elo_rating INTO v_loser_elo  FROM users WHERE user_id = v_loser_id  FOR UPDATE;

    -- Calculer la variation
    v_elo_delta := calculate_elo_change(v_winner_elo, v_loser_elo);

    -- Appliquer : ELO ± delta, XP du gagnant +xp_stake, du perdant ne peut pas devenir négatif
    UPDATE users
       SET elo_rating = elo_rating + v_elo_delta,
           total_xp   = total_xp + v_xp_stake
     WHERE user_id = v_winner_id;

    UPDATE users
       SET elo_rating = GREATEST(elo_rating - v_elo_delta, 0),
           total_xp   = GREATEST(total_xp - v_xp_stake / 2, 0)
     WHERE user_id = v_loser_id;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- TRIGGER : trg_duel_completed
-- Quand un duel passe à 'completed', applique automatiquement le résultat.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_duel_completed()
RETURNS TRIGGER AS $$
BEGIN
    -- Seulement à la transition vers 'completed'
    IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
        IF NEW.winner_id IS NULL THEN
            RAISE EXCEPTION 'Un duel completed doit avoir un winner_id';
        END IF;

        -- Fixer ended_at si non fourni
        IF NEW.ended_at IS NULL THEN
            NEW.ended_at := NOW();
        END IF;

        -- Appliquer le résultat (ELO + XP)
        PERFORM apply_duel_result(NEW.duel_id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_duel_completed
BEFORE UPDATE ON duels
FOR EACH ROW
EXECUTE FUNCTION trg_fn_duel_completed();

-- -----------------------------------------------------------------------------
-- TRIGGER : trg_attempt_xp_reward
-- Quand un joueur réussit un challenge pour la première fois (verdict 'passed'),
-- on lui ajoute l'XP du challenge.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_attempt_xp_reward()
RETURNS TRIGGER AS $$
DECLARE
    v_xp_reward       INTEGER;
    v_already_solved  BOOLEAN;
BEGIN
    IF NEW.verdict = 'passed' THEN
        -- Le joueur a-t-il déjà réussi ce challenge avant ?
        SELECT EXISTS (
            SELECT 1 FROM attempts
            WHERE user_id      = NEW.user_id
              AND challenge_id = NEW.challenge_id
              AND verdict      = 'passed'
              AND attempt_id  <> NEW.attempt_id
        ) INTO v_already_solved;

        IF NOT v_already_solved THEN
            -- Première résolution : on attribue l'XP
            SELECT xp_reward INTO v_xp_reward
              FROM challenges WHERE challenge_id = NEW.challenge_id;

            UPDATE users
               SET total_xp = total_xp + v_xp_reward,
                   last_active_at = NOW()
             WHERE user_id = NEW.user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_attempt_xp_reward
AFTER INSERT ON attempts
FOR EACH ROW
EXECUTE FUNCTION trg_fn_attempt_xp_reward();

-- -----------------------------------------------------------------------------
-- TRIGGER : trg_check_badges
-- Vérifie l'attribution automatique de badges après chaque succès.
-- Démontre l'intégration de règles métier complexes côté BDD.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_check_badges()
RETURNS TRIGGER AS $$
DECLARE
    v_solved_count INTEGER;
    v_badge_id     INTEGER;
BEGIN
    IF NEW.verdict = 'passed' THEN
        -- Compter les challenges uniques résolus par le joueur
        SELECT COUNT(DISTINCT challenge_id) INTO v_solved_count
          FROM attempts
         WHERE user_id = NEW.user_id AND verdict = 'passed';

        -- Badge "Premier pas" : 1 challenge résolu
        IF v_solved_count = 1 THEN
            SELECT badge_id INTO v_badge_id FROM badges WHERE code = 'FIRST_BLOOD';
            IF v_badge_id IS NOT NULL THEN
                INSERT INTO user_badges (user_id, badge_id)
                VALUES (NEW.user_id, v_badge_id)
                ON CONFLICT DO NOTHING;
            END IF;
        END IF;

        -- Badge "Décennale" : 10 challenges
        IF v_solved_count = 10 THEN
            SELECT badge_id INTO v_badge_id FROM badges WHERE code = 'TEN_SOLVED';
            IF v_badge_id IS NOT NULL THEN
                INSERT INTO user_badges (user_id, badge_id)
                VALUES (NEW.user_id, v_badge_id)
                ON CONFLICT DO NOTHING;
            END IF;
        END IF;

        -- Badge "Centurion" : 100 challenges
        IF v_solved_count = 100 THEN
            SELECT badge_id INTO v_badge_id FROM badges WHERE code = 'CENTURION';
            IF v_badge_id IS NOT NULL THEN
                INSERT INTO user_badges (user_id, badge_id)
                VALUES (NEW.user_id, v_badge_id)
                ON CONFLICT DO NOTHING;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_badges
AFTER INSERT ON attempts
FOR EACH ROW
EXECUTE FUNCTION trg_fn_check_badges();

-- -----------------------------------------------------------------------------
-- TRIGGER : trg_update_last_active
-- Met à jour automatiquement last_active_at lors d'une tentative.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_fn_update_last_active()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users SET last_active_at = NOW()
     WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_last_active
AFTER INSERT ON attempts
FOR EACH ROW
EXECUTE FUNCTION trg_fn_update_last_active();

-- -----------------------------------------------------------------------------
-- PROCÉDURE : create_duel
-- Procédure stockée pour créer un duel en vérifiant toutes les règles métier.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE create_duel(
    p_challenger_id IN  INTEGER,
    p_opponent_id   IN  INTEGER,
    p_challenge_id  IN  INTEGER,
    p_xp_stake      IN  INTEGER,
    p_duel_id       OUT INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_challenger_xp INTEGER;
BEGIN
    -- Vérifications
    IF p_challenger_id = p_opponent_id THEN
        RAISE EXCEPTION 'Un joueur ne peut pas se défier lui-même';
    END IF;

    -- Le challenger a-t-il assez d'XP pour parier ?
    SELECT total_xp INTO v_challenger_xp FROM users WHERE user_id = p_challenger_id;
    IF v_challenger_xp IS NULL THEN
        RAISE EXCEPTION 'Challenger introuvable (id=%)', p_challenger_id;
    END IF;
    IF v_challenger_xp < p_xp_stake THEN
        RAISE EXCEPTION 'XP insuffisants : % requis, % disponibles', p_xp_stake, v_challenger_xp;
    END IF;

    -- L'opposant existe ?
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_opponent_id) THEN
        RAISE EXCEPTION 'Opposant introuvable (id=%)', p_opponent_id;
    END IF;

    -- Le challenge existe et est publié ?
    IF NOT EXISTS (
        SELECT 1 FROM challenges WHERE challenge_id = p_challenge_id AND is_published
    ) THEN
        RAISE EXCEPTION 'Challenge introuvable ou non publié (id=%)', p_challenge_id;
    END IF;

    -- Création
    INSERT INTO duels (challenger_id, opponent_id, challenge_id, xp_stake, status)
    VALUES (p_challenger_id, p_opponent_id, p_challenge_id, p_xp_stake, 'pending')
    RETURNING duel_id INTO p_duel_id;
END;
$$;

-- Usage : CALL create_duel(1, 2, 5, 100, NULL);
