import pg from 'pg';
import 'dotenv/config';

const { Pool } = pg;

/**
 * Pool de connexions PostgreSQL.
 * Le pool gère automatiquement la réutilisation des connexions, ce qui est
 * essentiel en production pour éviter d'ouvrir une connexion par requête HTTP.
 */
export const pool = new Pool({
  host: process.env.PGHOST || 'localhost',
  port: Number(process.env.PGPORT) || 5432,
  database: process.env.PGDATABASE || 'codequest',
  user: process.env.PGUSER || 'postgres',
  password: process.env.PGPASSWORD || 'postgres',
  max: 20,                       // 20 connexions simultanées max
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Toutes nos tables sont dans le schéma "codequest"
pool.on('connect', (client) => {
  client.query('SET search_path TO codequest, public');
});

pool.on('error', (err) => {
  console.error('Erreur pool PostgreSQL :', err);
});

/**
 * Helper pour les requêtes paramétrées.
 * Utilise des placeholders $1, $2... pour éviter les injections SQL.
 *
 * Exemple :
 *   const rows = await query('SELECT * FROM users WHERE user_id = $1', [42]);
 */
export async function query(text, params) {
  const start = Date.now();
  const result = await pool.query(text, params);
  const duration = Date.now() - start;

  if (process.env.NODE_ENV === 'development') {
    console.log(`[SQL] ${duration}ms — ${text.slice(0, 80).replace(/\s+/g, ' ')}…`);
  }

  return result.rows;
}

/**
 * Helper pour les transactions.
 * Garantit qu'on libère bien le client à la fin, succès ou erreur.
 *
 * Exemple :
 *   await transaction(async (client) => {
 *     await client.query('INSERT INTO duels ...');
 *     await client.query('UPDATE users SET ...');
 *   });
 */
export async function transaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SET search_path TO codequest, public');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
