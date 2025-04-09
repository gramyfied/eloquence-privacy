import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Pour le provider
import 'package:eloquence_flutter/domain/entities/exercise.dart';
import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
import 'package:eloquence_flutter/presentation/widgets/visual_effects/info_modal.dart'; // Assurez-vous que le chemin est correct
import 'package:eloquence_flutter/presentation/widgets/visual_effects/celebration_effect.dart'; // Assurez-vous que le chemin est correct
import 'package:eloquence_flutter/app/theme.dart'; // Pour les couleurs/styles

// Provider pour la clé du navigateur (à définir dans main.dart et passer ici)
// Exemple: final navigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());
// Assurez-vous que ce provider existe et est accessible.
// Pour l'instant, on va supposer qu'il existe.
// Si ce n'est pas le cas, il faudra l'ajouter dans main.dart ou un fichier de providers global.
// Placeholder - à remplacer par le vrai provider si différent
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  // Ceci est un placeholder, assurez-vous que la vraie clé est fournie
  print("ATTENTION: Utilisation du placeholder navigatorKeyProvider. Assurez-vous qu'il est correctement configuré.");
  return GlobalKey<NavigatorState>();
});


// --- Service de Modales ---
class ModalService {
  final Ref _ref; // Utiliser Ref pour lire la clé du navigateur

  ModalService(this._ref);

  // Méthode helper pour obtenir le contexte actuel de manière sûre
  BuildContext? get _context {
     final navigatorKey = _ref.read(navigatorKeyProvider);
     return navigatorKey.currentContext;
  }

  /// Affiche la modale d'information pour un exercice donné.
  void showInfoModal(Exercise exercise) {
    final context = _context;
    if (context == null) {
       print("[ModalService] Contexte non disponible pour showInfoModal.");
       return;
    }
    showDialog(
      context: context,
      builder: (_) => InfoModal(
         title: exercise.title,
         description: exercise.objective,
         // TODO: Rendre les bénéfices dynamiques ou les passer en paramètre si nécessaire
         benefits: const [
           "Améliore la clarté de la parole.",
           "Renforce le contrôle vocal.",
           "Augmente l'intelligibilité.",
         ],
         instructions: exercise.instructions ?? "Lisez le texte affiché clairement et à un rythme modéré.",
         backgroundColor: AppTheme.primaryColor, // Ou une couleur passée en paramètre
      ),
    );
  }

  /// Affiche la modale de fin d'exercice avec les résultats.
  ///
  /// [result]: Le résultat de l'évaluation de prononciation.
  /// [onRetry]: Callback optionnel exécuté lorsque l'utilisateur clique sur "Réessayer".
  /// [onFinish]: Callback optionnel exécuté lorsque l'utilisateur clique sur "Terminer".
  /// [customFeedback]: Message de feedback personnalisé à afficher.
  void showCompletionModal({
     required PronunciationResult result,
     VoidCallback? onRetry,
     VoidCallback? onFinish,
     String? customFeedback,
     // Ajoutez d'autres paramètres si nécessaire (ex: Widget de détails spécifiques)
  }) {
     final context = _context;
     if (context == null) {
       print("[ModalService] Contexte non disponible pour showCompletionModal.");
       return;
     }

     final score = result.accuracyScore ?? 0.0; // Utiliser accuracy comme score principal ? À adapter.
     final success = score >= 70; // Votre logique de succès
     final commentaires = customFeedback ?? (result.words.isEmpty && score == 0 ? "Aucun discours détecté." : "Analyse terminée.");

     showDialog(
       context: context,
       barrierDismissible: false, // Empêcher la fermeture facile
       builder: (dialogContext) { // Utiliser dialogContext pour pop
         return Stack(
           children: [
             if (success) CelebrationEffect(onComplete: () {}), // Effet conditionnel
             AlertDialog(
               backgroundColor: AppTheme.darkSurface,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius3)),
               title: Row(
                 children: [
                   Icon(success ? Icons.check_circle_outline : Icons.info_outline, color: success ? AppTheme.accentGreen : Colors.orangeAccent, size: 28),
                   const SizedBox(width: 12),
                   Expanded(child: Text(success ? 'Exercice Réussi !' : 'Résultats', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20))),
                 ],
               ),
               content: SingleChildScrollView(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('Score Global (Précision): ${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                     const SizedBox(height: 16),
                     // Afficher les autres scores détaillés
                     Text('Score Prononciation: ${result.pronunciationScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                     Text('Fluidité: ${result.fluencyScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                     Text('Complétude: ${result.completenessScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                     // TODO: Afficher les erreurs par mot si nécessaire (result.words)
                     const SizedBox(height: 16),
                     Text(
                       commentaires,
                       style: const TextStyle(fontSize: 15, color: Colors.white),
                     ),
                     // TODO: Ajouter la lecture audio du feedback si nécessaire
                   ],
                 ),
               ),
               actions: [
                 TextButton(
                   onPressed: () {
                     Navigator.of(dialogContext).pop(); // Utiliser dialogContext
                     onFinish?.call(); // Appeler le callback si fourni
                   },
                   child: const Text('Terminer', style: TextStyle(color: Colors.white70)),
                 ),
                 ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                   onPressed: () {
                     Navigator.of(dialogContext).pop(); // Utiliser dialogContext
                     onRetry?.call(); // Appeler le callback si fourni
                   },
                   child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                 ),
               ],
             ),
           ],
         );
       },
     );
  }

  /// Affiche une modale d'erreur générique.
  void showErrorModal(String title, String message) {
     final context = _context;
     if (context == null) {
       print("[ModalService] Contexte non disponible pour showErrorModal.");
       return;
     }
     showDialog(
       context: context,
       builder: (dialogContext) => AlertDialog(
         backgroundColor: AppTheme.darkSurface,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius3)),
         title: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20))),
            ],
         ),
         content: Text(message, style: const TextStyle(fontSize: 15, color: Colors.white)),
         actions: [
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
             onPressed: () => Navigator.of(dialogContext).pop(),
             child: const Text('OK', style: TextStyle(color: Colors.white)),
           ),
         ],
       ),
     );
  }

  // Ajoutez d'autres méthodes pour différents types de modales si nécessaire
}

// --- Provider Riverpod ---
final modalServiceProvider = Provider<ModalService>((ref) {
  return ModalService(ref); // Passe ref au constructeur
});
