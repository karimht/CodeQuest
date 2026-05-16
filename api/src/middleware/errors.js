/**
 * Wrapper pour les handlers async — propage les erreurs vers le middleware d'erreur.
 * Évite d'écrire try/catch partout.
 */
export const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

/**
 * Middleware global de gestion d'erreurs.
 * Traduit les erreurs PostgreSQL en réponses HTTP sensées.
 */
export function errorHandler(err, req, res, _next) {
  console.error('[ERROR]', err);

  // Erreurs PostgreSQL identifiées par leur code SQLSTATE
  // https://www.postgresql.org/docs/current/errcodes-appendix.html
  if (err.code === '23505') {
    return res.status(409).json({
      error: 'Conflit',
      detail: 'Une ressource avec cette valeur unique existe déjà.',
      constraint: err.constraint,
    });
  }

  if (err.code === '23503') {
    return res.status(400).json({
      error: 'Référence invalide',
      detail: 'Une clé étrangère pointe vers une ressource inexistante.',
      constraint: err.constraint,
    });
  }

  if (err.code === '23514') {
    return res.status(400).json({
      error: 'Contrainte violée',
      detail: err.message,
      constraint: err.constraint,
    });
  }

  // Erreurs métier custom (RAISE EXCEPTION dans nos triggers/procédures)
  if (err.code === 'P0001') {
    return res.status(400).json({
      error: 'Règle métier violée',
      detail: err.message.replace(/^.*?:\s*/, ''),
    });
  }

  // Erreurs HTTP custom levées dans le code
  if (err.status) {
    return res.status(err.status).json({ error: err.message });
  }

  // Tout le reste → 500
  res.status(500).json({
    error: 'Erreur interne du serveur',
    ...(process.env.NODE_ENV === 'development' && { detail: err.message }),
  });
}

/**
 * Helper pour lever des erreurs HTTP propres.
 */
export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
