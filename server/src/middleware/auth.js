/**
 * Middleware d'authentification par clé API
 * Vérifie que la requête contient une clé API valide dans l'en-tête Authorization
 * En mode développement (NODE_ENV=development), la vérification est désactivée
 */
export const apiKeyAuth = (req, res, next) => {
  // En mode développement, désactiver la vérification de la clé API
  if (process.env.NODE_ENV === 'development') {
    return next();
  }
  
  // Récupérer la clé API depuis l'en-tête Authorization
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Authentification requise',
      message: 'Veuillez fournir une clé API valide dans l\'en-tête Authorization'
    });
  }
  
  // Extraire la clé API
  const apiKey = authHeader.split(' ')[1];
  
  // Vérifier la clé API
  if (apiKey !== process.env.API_KEY) {
    return res.status(403).json({
      error: 'Accès refusé',
      message: 'Clé API invalide'
    });
  }
  
  // Si la clé API est valide, passer à la suite
  next();
};
