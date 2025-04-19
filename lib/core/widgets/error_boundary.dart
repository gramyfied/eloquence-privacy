import 'package:flutter/material.dart';
import '../utils/enhanced_logger.dart';

/// Widget qui capture les erreurs dans son arbre d'enfants
/// et affiche un widget de secours en cas d'erreur.
class ErrorBoundary extends StatefulWidget {
  /// Widget enfant à afficher
  final Widget child;

  /// Widget de secours à afficher en cas d'erreur
  final Widget? fallback;

  /// Callback appelé lorsqu'une erreur est capturée
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Indique si l'erreur doit être enregistrée dans les logs
  final bool logError;

  /// Indique si l'erreur doit être signalée à Flutter
  final bool reportError;

  /// Crée un widget ErrorBoundary
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
    this.logError = true,
    this.reportError = true,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  /// Indique si une erreur a été capturée
  bool _hasError = false;

  /// L'erreur capturée
  Object? _error;

  /// La trace de la pile de l'erreur capturée
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    
    // Configurer le gestionnaire d'erreurs
    FlutterError.onError = (FlutterErrorDetails details) {
      // Enregistrer l'erreur dans les logs si demandé
      if (widget.logError) {
        logger.critical(
          'Erreur dans ErrorBoundary: ${details.exception}',
          stackTrace: details.stack,
        );
      }

      // Appeler le callback onError si fourni
      if (widget.onError != null) {
        widget.onError!(details.exception, details.stack ?? StackTrace.current);
      }

      // Signaler l'erreur à Flutter si demandé
      if (widget.reportError) {
        FlutterError.reportError(details);
      }

      // Mettre à jour l'état pour afficher le widget de secours
      if (mounted) {
        setState(() {
          _hasError = true;
          _error = details.exception;
          _stackTrace = details.stack;
        });
      }
    };
  }

  @override
  void dispose() {
    // Restaurer le gestionnaire d'erreurs par défaut
    FlutterError.onError = FlutterError.presentError;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // Afficher le widget de secours en cas d'erreur
      return widget.fallback ?? _buildDefaultErrorWidget();
    }

    // Afficher le widget enfant
    return widget.child;
  }

  /// Construit le widget d'erreur par défaut
  Widget _buildDefaultErrorWidget() {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Une erreur est survenue',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error?.toString() ?? 'Erreur inconnue',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _error = null;
                  _stackTrace = null;
                });
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension pour faciliter l'utilisation d'ErrorBoundary
extension ErrorBoundaryExtension on Widget {
  /// Enveloppe le widget dans un ErrorBoundary
  Widget withErrorBoundary({
    Widget? fallback,
    void Function(Object error, StackTrace stackTrace)? onError,
    bool logError = true,
    bool reportError = true,
  }) {
    return ErrorBoundary(
      fallback: fallback,
      onError: onError,
      logError: logError,
      reportError: reportError,
      child: this,
    );
  }
}

/// Widget qui capture les erreurs spécifiquement pour les écrans d'exercice
class ExerciseErrorBoundary extends StatelessWidget {
  /// Widget enfant à afficher
  final Widget child;

  /// Callback appelé lorsque l'utilisateur appuie sur le bouton de retour
  final VoidCallback? onBackPressed;

  /// Crée un widget ExerciseErrorBoundary
  const ExerciseErrorBoundary({
    super.key,
    required this.child,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      logError: true,
      reportError: true,
      onError: (error, stackTrace) {
        // Enregistrer l'erreur avec un tag spécifique
        logger.critical(
          'Erreur dans un écran d\'exercice: $error',
          tag: 'EXERCISE',
          stackTrace: stackTrace,
        );
      },
      fallback: _buildExerciseErrorWidget(context),
      child: child,
    );
  }

  /// Construit le widget d'erreur spécifique aux exercices
  Widget _buildExerciseErrorWidget(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erreur'),
        leading: onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackPressed,
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Une erreur est survenue pendant l\'exercice',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Nous sommes désolés pour ce problème. Veuillez réessayer ou revenir à l\'écran précédent.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                    ),
                    child: const Text('Retour'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Recharger l'écran actuel
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => ExerciseErrorBoundary(
                            onBackPressed: onBackPressed,
                            child: child,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text(
                      'Réessayer',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
