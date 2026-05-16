# 🎮 CodeQuest — Projet de Base de Données

**Plateforme de défis de programmation entre amis** — projet académique conçu pour démontrer la maîtrise de PostgreSQL et la conception d'une API REST connectée à une BDD relationnelle.

> **Concept** : une mini-plateforme à la HackerRank/LeetCode où les joueurs s'affrontent en duels 1v1, parient des XP, montent en ELO, rejoignent des guildes et débloquent des badges.

---

## 📚 Concepts de BDD couverts

| Concept | Où le trouver |
|---------|---------------|
| **Schéma relationnel normalisé (3NF)** | `sql/01_schema.sql` |
| **Types ENUM personnalisés** | `sql/01_schema.sql` lignes 15-20 |
| **Contraintes CHECK** | Format username, ELO ≥ 0, etc. |
| **Clés étrangères avec actions (CASCADE, SET NULL, RESTRICT)** | Tables `attempts`, `challenges`, etc. |
| **Index B-tree, partiels, GIN** | Fin de `01_schema.sql` |
| **Tableaux PostgreSQL (`text[]`)** | Colonne `challenges.tags` |
| **JSONB + indexation GIN** | Colonne `challenges.test_cases` |
| **Vues classiques** | `sql/02_views.sql` |
| **Vues matérialisées + index unique** | `mv_global_leaderboard` |
| **Window functions** (RANK, LAG, NTILE, AVG OVER) | `sql/02_views.sql` & `05_queries_demo.sql` |
| **CTE (WITH) simples et récursives** | `sql/05_queries_demo.sql` § 6 |
| **Fonctions PL/pgSQL** | `sql/03_functions_triggers.sql` |
| **Triggers BEFORE/AFTER** | `trg_duel_completed`, `trg_attempt_xp_reward` |
| **Procédures stockées (CALL avec OUT)** | `create_duel` |
| **Transactions ACID + verrouillage (FOR UPDATE)** | `apply_duel_result` |
| **Anti-jointures (LEFT JOIN + IS NULL)** | `05_queries_demo.sql` § 2.3 |
| **Sous-requêtes corrélées (EXISTS)** | `05_queries_demo.sql` § 4 |
| **Agrégations conditionnelles (FILTER)** | Partout |
| **Collaborative filtering** | Endpoint `/recommendations/:userId` |

---

## 🏗️ Architecture

```
codequest/
├── sql/                          # Tout le SQL, à exécuter dans l'ordre
│   ├── 01_schema.sql            # DDL : tables, contraintes, index
│   ├── 02_views.sql             # Vues + vue matérialisée
│   ├── 03_functions_triggers.sql # PL/pgSQL : fonctions, triggers, procédures
│   ├── 04_seed.sql              # Données réalistes (30 users, 20 challenges, 200+ attempts)
│   └── 05_queries_demo.sql      # Requêtes pédagogiques classées par niveau
├── api/                          # API REST Node.js + Express
│   ├── src/
│   │   ├── db/pool.js           # Connexion PostgreSQL (pg)
│   │   ├── middleware/errors.js  # Gestion d'erreurs PostgreSQL → HTTP
│   │   ├── routes/              # 5 fichiers : users, challenges, duels, attempts, leaderboard
│   │   └── server.js            # Point d'entrée Express
│   ├── package.json
│   └── .env.example
└── docs/
    ├── SCHEMA_ER.md             # Diagramme entité-relation + justifications
    └── requests.http            # Toutes les requêtes API testables
```

---

## 🚀 Installation pas à pas

### 1. Prérequis

- **PostgreSQL 14+** installé (téléchargeable sur [postgresql.org](https://www.postgresql.org/download/))
- **Node.js 18+**
- Un client SQL au choix : `psql` (en ligne de commande), pgAdmin, DBeaver, ou TablePlus

### 2. Créer la base

Ouvre un terminal et lance :

```bash
# Se connecter à PostgreSQL en super-utilisateur
psql -U postgres

# Dans psql :
CREATE DATABASE codequest;
\q
```

### 3. Exécuter les scripts SQL (dans l'ordre !)

```bash
cd codequest/sql

psql -U postgres -d codequest -f 01_schema.sql
psql -U postgres -d codequest -f 02_views.sql
psql -U postgres -d codequest -f 03_functions_triggers.sql
psql -U postgres -d codequest -f 04_seed.sql
```

Le dernier script affichera un récapitulatif :
```
 entity     | count
------------+-------
 Users      |    30
 Challenges |    20
 Duels      |    13
 Attempts   |   ~240
 Guilds     |     5
 ...
```

### 4. Lancer l'API

```bash
cd codequest/api
cp .env.example .env
# Éditer .env si tes credentials PostgreSQL diffèrent
npm install
npm run dev
```

→ `http://localhost:3000/api/health` doit répondre `{ "status": "ok" }`.

### 5. Tester les endpoints

Ouvre `docs/requests.http` dans VS Code avec l'extension **REST Client**, ou copie les requêtes dans Postman.

---

## 🧪 Démonstrations clés à montrer en soutenance

### 1. Le trigger `trg_duel_completed` recalcule l'ELO automatiquement

```bash
# Avant : noter l'ELO de l'utilisateur 1
curl http://localhost:3000/api/users/1 | grep elo_rating

# Terminer le duel actif (le duel 10 dans le seed)
curl -X PATCH http://localhost:3000/api/duels/10/complete \
  -H "Content-Type: application/json" \
  -d '{"winner_id": 1}'

# Après : ELO mis à jour par le trigger sans aucun calcul côté API !
curl http://localhost:3000/api/users/1 | grep elo_rating
```

### 2. CTE récursive pour les amis d'amis

Exécute la requête § 6.2 de `05_queries_demo.sql` : tu obtiens la liste des amis directs ET des amis d'amis du joueur 1.

### 3. Window functions pour le classement

```sql
SELECT username, elo_rating,
       RANK()       OVER (ORDER BY elo_rating DESC) AS rank,
       LAG(elo_rating) OVER (ORDER BY elo_rating DESC) - elo_rating AS gap_above
FROM users;
```

### 4. Procédure stockée avec validation métier

```sql
-- Va échouer avec message clair grâce à RAISE EXCEPTION
CALL create_duel(1, 1, 5, 100, NULL);
-- ERROR: Un joueur ne peut pas se défier lui-même
```

### 5. Performance : vue matérialisée vs calcul à la volée

```sql
-- Calcul à la volée (lent sur grosse table)
EXPLAIN ANALYZE
SELECT user_id, RANK() OVER (ORDER BY elo_rating DESC) FROM users;

-- Vue matérialisée (instantané)
EXPLAIN ANALYZE
SELECT * FROM mv_global_leaderboard;
```

### 6. Sécurité : requêtes paramétrées

Toute l'API utilise `$1, $2, ...` (jamais de concaténation). Démo d'injection SQL qui ne marche pas :

```bash
# Cette URL est inoffensive grâce aux paramètres préparés
curl "http://localhost:3000/api/challenges?search='; DROP TABLE users; --"
# → renvoie simplement aucun résultat
```

---

## 📊 Modèle conceptuel

Voir `docs/SCHEMA_ER.md` pour :
- Diagramme entité-relation Mermaid
- Justification de chaque choix de design
- Discussion des cardinalités

---

## 🎯 Pistes d'extension (bonus pour ta soutenance)

| Idée | Concept de BDD touché |
|------|----------------------|
| Ajouter une table `attempt_logs` partitionnée par mois | Partitionnement |
| Implémenter une recherche full-text sur les énoncés | `tsvector`, `to_tsquery` |
| Ajouter un système de tournois (table `tournaments`) | Modélisation N-N complexe |
| Migrer les credentials vers une table `auth_sessions` | Sécurité, gestion de session |
| Audit log automatique sur toutes les modifications | Triggers + table d'audit |
| Replica en lecture seule pour le leaderboard | Réplication |
| Cache Redis devant la vue matérialisée | Stratégie de cache |

---

## 📖 Pour aller plus loin (cours BDD)

Chaque concept du programme typique de BDD est illustré dans ce projet :

- **Algèbre relationnelle** → toutes les requêtes du `05_queries_demo.sql`
- **Normalisation (1NF, 2NF, 3NF)** → schéma normalisé avec table d'association
- **Indexation** → différents types d'index pour différents cas d'usage
- **Optimisation** → vue matérialisée, EXPLAIN ANALYZE
- **Transactions et concurrence** → `FOR UPDATE` dans `apply_duel_result`
- **Intégrité référentielle** → toutes les FK avec actions appropriées
- **Triggers et procédures** → logique métier côté BDD
- **Patterns avancés** → JSONB, CTE récursives, window functions

---

## 📝 Licence

Projet académique — libre d'usage pour fins éducatives.
