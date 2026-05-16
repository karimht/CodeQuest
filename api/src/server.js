import express from 'express';
import cors from 'cors';
import 'dotenv/config';

import usersRouter       from './routes/users.js';
import challengesRouter  from './routes/challenges.js';
import duelsRouter       from './routes/duels.js';
import attemptsRouter    from './routes/attempts.js';
import leaderboardRouter from './routes/leaderboard.js';
import { errorHandler }  from './middleware/errors.js';
import { pool, query }   from './db/pool.js';

const app = express();

// Middlewares globaux
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Endpoint de santé : vérifie que la BDD répond
app.get('/api/health', async (_req, res) => {
  try {
    const [{ now }] = await query('SELECT NOW() AS now');
    res.json({ status: 'ok', database: 'connected', server_time: now });
  } catch (err) {
    res.status(503).json({ status: 'degraded', database: 'disconnected', error: err.message });
  }
});

// Routes métier
app.use('/api/users',       usersRouter);
app.use('/api/challenges',  challengesRouter);
app.use('/api/duels',       duelsRouter);
app.use('/api/attempts',    attemptsRouter);
app.use('/api/leaderboard', leaderboardRouter);

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint inconnu', path: req.path });
});

// Middleware de gestion d'erreurs (toujours en dernier)
app.use(errorHandler);

const PORT = Number(process.env.PORT) || 3000;
app.listen(PORT, () => {
  console.log(`✅ API CodeQuest sur http://localhost:${PORT}`);
  console.log(`   Health check : http://localhost:${PORT}/api/health`);
});

// Fermeture propre du pool quand on arrête le serveur
const shutdown = async () => {
  console.log('\n🛑 Fermeture du serveur...');
  await pool.end();
  process.exit(0);
};
process.on('SIGINT',  shutdown);
process.on('SIGTERM', shutdown);
