import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/visual_effects/celebration_effect.dart'; // Importer pour les confettis
import '../../../services/audio/example_audio_provider.dart'; // Importer pour TTS
import '../../../services/service_locator.dart'; // Importer pour serviceLocator

class ExerciseResultScreen extends StatefulWidget { // Convertir en StatefulWidget pour gérer le TTS
  final Exercise exercise;
  final Map<String, dynamic> results;
  final VoidCallback onHomePressed;
  final VoidCallback onTryAgainPressed;

  const ExerciseResultScreen({
    super.key,
    required this.exercise,
    required this.results,
    required this.onHomePressed,
    required this.onTryAgainPressed,
  });

  @override
  _ExerciseResultScreenState createState() => _ExerciseResultScreenState();
}

class _ExerciseResultScreenState extends State<ExerciseResultScreen> {
  late ExampleAudioProvider _exampleAudioProvider; // Pour le TTS

  @override
  void initState() {
    super.initState();
    _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
  }

  @override
  Widget build(BuildContext context) {
    // Extraire les scores principaux depuis les résultats
    final overallScore = (widget.results['score'] as num?)?.toDouble() ?? 0.0; // Utiliser double
    final feedback = widget.results['commentaires'] as String? ??
        'Analyse terminée.';
    final details = widget.results['details'] as Map<String, dynamic>?;
    final success = overallScore > 70 && widget.results['erreur'] == null;

    // Extraire les scores détaillés si disponibles (pour Rythme et Pauses)
    final placementScore = (details?['placement_score'] as num?)?.toDouble();
    final durationScore = (details?['duration_score'] as num?)?.toDouble();
    final averageWpm = (details?['average_wpm'] as num?)?.toDouble();

    // Extraire les scores génériques si présents (pour d'autres exercices)
    final accuracyScore = (widget.results['accuracyScore'] as num?)?.toDouble();
    final fluencyScore = (widget.results['fluencyScore'] as num?)?.toDouble();
    final completenessScore = (widget.results['completenessScore'] as num?)?.toDouble();

    // Extraire les données spécifiques à l'analyse des finales si présentes
    final finalAnalysis = widget.results['finalAnalysis'] as Map<String, dynamic>?;
    final finalScore = (finalAnalysis?['calculatedScore'] as num?)?.toDouble();
    final specificFeedback = finalAnalysis?['feedbackIA'] as String?;


    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onHomePressed, // Utiliser widget.
          ),
        ],
      ),
      body: Stack( // Utiliser Stack pour superposer les confettis
        children: [
          // Contenu principal
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildSuccessBanner(overallScore, success), // Passer success
                      const SizedBox(height: 24),
                      _buildScoreSection(
                        overallScore,
                        placementScore, // Passer les scores détaillés
                        durationScore,
                        averageWpm,
                        accuracyScore, // Passer aussi les scores génériques
                        fluencyScore,
                        completenessScore,
                        finalScore, // Passer le score de la finale
                      ),
                      const SizedBox(height: 32),
                      // Utiliser le feedback spécifique s'il existe, sinon le général
                      _buildFeedbackSection(specificFeedback ?? feedback),
                      const SizedBox(height: 32),
                      // TODO: Ajouter potentiellement une section pour visualiser la finale ici
                      _buildExerciseDetails(),
                    ],
                  ),
                ),
              ),
              _buildBottomButtons(),
            ],
          ),
              // Effet Confettis (superposé et ignorant les pointeurs)
              if (success)
                Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer( // Empêche les confettis de bloquer les interactions
                    child: CelebrationEffect(
                      intensity: 0.6,
                      primaryColor: AppTheme.primaryColor,
                    secondaryColor: AppTheme.accentGreen,
                    durationSeconds: 5,
                    // Remettre le callback onComplete requis
                    onComplete: () {
                      if (mounted) { // Ajouter une vérification 'mounted' par sécurité
                        print('[ExerciseResultScreen] Celebration animation completed.');
                      }
                    },
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(double score, bool success) { // Accepter score double et success bool
    String message = success ? 'Félicitations!' : 'Exercice Terminé';
    String submessage = '';
    Color bannerColor = success ? AppTheme.accentGreen : AppTheme.accentYellow; // Jaune si pas succès mais terminé

    if (success) {
      if (score >= 90) {
        submessage = 'Performance exceptionnelle!';
      } else if (score >= 75) {
        submessage = 'Très bonne performance!';
      } else {
         submessage = 'Objectif atteint !'; // Pour les scores entre 70 et 75
      }
    } else {
       submessage = 'Continuez à vous entraîner';
       if (score < 70) { // Seulement si le score est bas, sinon garder jaune
         bannerColor = AppTheme.accentRed; // Rouge si score < 70
       }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
        border: Border.all(
          color: bannerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Icône de succès ou d'information
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bannerColor.withOpacity(0.2),
            ),
            child: Icon(
              success ? Icons.check_circle : Icons.info_outline, // Icône différente si pas succès
              color: bannerColor,
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            submessage,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection(
    double overallScore,
    double? placementScore, // Scores spécifiques Rythme/Pauses
    double? durationScore,
    double? averageWpm,
    double? accuracyScore, // Scores génériques
    double? fluencyScore,
    double? completenessScore,
    double? finalScore, // Ajouter le paramètre manquant ici dans la définition
  ) {
    // Construire la liste des cartes de stats en fonction des scores disponibles
    List<Widget> statCards = [];

    // Carte Score Global (toujours présente)
    statCards.add(
      // Ne pas utiliser Expanded ici, car la Row parente n'est pas dans une Colonne/Row flexible
      StatCard(
        title: 'Score global',
        value: '${overallScore.toStringAsFixed(0)}%', // Afficher sans décimale
        icon: Icons.star,
        gradient: AppTheme.primaryGradient,
        height: 110, // Plus haute
      ),
    );

    // Cartes pour Rythme et Pauses (Utilisation de AppTheme.primaryGradient)
    if (placementScore != null) {
      statCards.add(StatCard(title: 'Placement Pauses', value: '${(placementScore * 100).toStringAsFixed(0)}%', icon: Icons.location_on, gradient: AppTheme.primaryGradient));
    }
    if (durationScore != null) {
      statCards.add(StatCard(title: 'Durée Pauses', value: '${(durationScore * 100).toStringAsFixed(0)}%', icon: Icons.timer, gradient: AppTheme.primaryGradient));
    }
    if (averageWpm != null) {
      statCards.add(StatCard(title: 'Rythme', value: '${averageWpm.toStringAsFixed(0)} MPM', icon: Icons.speed, gradient: AppTheme.primaryGradient));
    }

    // Cartes pour scores génériques (si les spécifiques ne sont pas là) (Utilisation de AppTheme.primaryGradient)
    if (accuracyScore != null && placementScore == null) { // Afficher seulement si pas déjà couvert par placement
       statCards.add(StatCard(title: 'Précision', value: '${accuracyScore.toStringAsFixed(0)}%', icon: Icons.gps_fixed, gradient: AppTheme.primaryGradient));
    }
     if (fluencyScore != null && durationScore == null && averageWpm == null) { // Afficher seulement si pas déjà couvert
       statCards.add(StatCard(title: 'Fluidité', value: '${fluencyScore.toStringAsFixed(0)}%', icon: Icons.waves, gradient: AppTheme.primaryGradient));
    }
     if (completenessScore != null) {
       statCards.add(StatCard(title: 'Complétude', value: '${completenessScore.toStringAsFixed(0)}%', icon: Icons.check_box, gradient: AppTheme.primaryGradient));
    }

    // Carte pour le Score Finale (si disponible)
    if (finalScore != null) {
      statCards.add(StatCard(
         title: 'Score Finale',
         value: '${finalScore.toStringAsFixed(0)}%', // Score spécifique de la finale
         icon: Icons.flag_circle_outlined, // Icône appropriée
         gradient: AppTheme.primaryGradient, // Réutiliser le gradient primaire
       ));
     }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vos résultats',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        // Afficher la première ligne (Score Global) - Utiliser Align pour centrer si seul
        Align(
          alignment: Alignment.centerLeft, // Ou center si vous préférez
          child: statCards.first,
        ),
        // Afficher les autres scores dans un Wrap pour éviter l'overflow
        if (statCards.length > 1) ...[
           const SizedBox(height: 16),
           Wrap(
             spacing: 12.0, // Espace horizontal entre les cartes
             runSpacing: 12.0, // Espace vertical entre les lignes
             // Utiliser directement les widgets StatCard dans Wrap
             children: statCards.sublist(1),
           ),
        ]
      ],
    );
  }

  Widget _buildFeedbackSection(String feedback) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded, // Icône différente
                 color: AppTheme.accentYellow,
                 size: 24,
               ),
               const SizedBox(width: 12), // Espacement standard
               // Envelopper le titre dans Expanded pour qu'il prenne l'espace restant
               const Expanded(
                 child: Text(
                   'Feedback du Coach IA',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                   overflow: TextOverflow.ellipsis, // Optionnel: Gérer le texte très long
                 ),
               ),
               // Bouton TTS
               if (feedback.isNotEmpty)
                 IconButton(
                   icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primaryColor),
                   tooltip: 'Lire le feedback',
                   onPressed: () {
                     // Ajouter une vérification pour s'assurer que le provider est prêt si nécessaire
                     try {
                       _exampleAudioProvider.playExampleFor(feedback);
                     } catch (e) {
                       print("Erreur lors de la lecture TTS: $e");
                       // Afficher un message à l'utilisateur si nécessaire
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text("Impossible de lire le feedback pour le moment."))
                       );
                     }
                   },
                 ),
            ],
          ),
          const SizedBox(height: 12),
          // Le Builder inutile est supprimé ici
          Text(
            feedback.isNotEmpty ? feedback : 'Aucun commentaire spécifique.', // Message par défaut si vide
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercice: ${widget.exercise.title}', // Utiliser widget.
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catégorie: ${widget.exercise.category.name}', // Utiliser widget.
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Difficulté: ${_getDifficultyText(widget.exercise.difficulty)}', // Utiliser widget.
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _getDifficultyText(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile:
        return 'Facile';
      case ExerciseDifficulty.moyen:
        return 'Moyen';
      case ExerciseDifficulty.difficile:
        return 'Difficile';
      default:
        return 'Moyen'; // Valeur par défaut
    }
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onHomePressed, // Utiliser widget.
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
                ),
              ),
              child: const Text('Accueil'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onTryAgainPressed, // Utiliser widget.
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ),
        ],
      ),
    );
  }
}
// --- Fin du code ---
