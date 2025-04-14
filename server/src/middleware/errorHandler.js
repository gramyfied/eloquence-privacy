/**
 * Middleware de gestion des erreurs
 * Intercepte les erreurs et renvoie une réponse JSON appropriée
 */
export const errorHandler = (err, req, res, next) => {
  console.error('Erreur:', err);
  
  // Déterminer le code d'état HTTP
  let statusCode = 500;
  if (err.statusCode) {
    statusCode = err.statusCode;
  } else if (err.name === 'ValidationError') {
    statusCode = 400;
  } else if (err.name === 'UnauthorizedError') {
    statusCode = 401;
  } else if (err.name === 'ForbiddenError') {
    statusCode = 403;
  } else if (err.name === 'NotFoundError') {
    statusCode = 404;
  }
  
  // Construire la réponse d'erreur
  const errorResponse = {
    error: err.name || 'InternalServerError',
    message: err.message || 'Une erreur interne est survenue',
    statusCode
  };
  
  // Ajouter des détails supplémentaires en mode développement
  if (process.env.NODE_ENV === 'development' && err.stack) {
    errorResponse.stack = err.stack;
    
    if (err.errors) {
      errorResponse.errors = err.errors;
    }
  }
  
  // Envoyer la réponse
  res.status(statusCode).json(errorResponse);
};

/**
 * Classe d'erreur personnalisée pour les erreurs d'API
 */
export class ApiError extends Error {
  constructor(message, statusCode = 500, name = 'ApiError') {
    super(message);
    this.name = name;
    this.statusCode = statusCode;
    Error.captureStackTrace(this, this.constructor);
  }
  
  static badRequest(message = 'Requête invalide') {
    return new ApiError(message, 400, 'BadRequestError');
  }
  
  static unauthorized(message = 'Non autorisé') {
    return new ApiError(message, 401, 'UnauthorizedError');
  }
  
  static forbidden(message = 'Accès refusé') {
    return new ApiError(message, 403, 'ForbiddenError');
  }
  
  static notFound(message = 'Ressource non trouvée') {
    return new ApiError(message, 404, 'NotFoundError');
  }
  
  static internalServer(message = 'Erreur interne du serveur') {
    return new ApiError(message, 500, 'InternalServerError');
  }
  
  static serviceUnavailable(message = 'Service indisponible') {
    return new ApiError(message, 503, 'ServiceUnavailableError');
  }
}
