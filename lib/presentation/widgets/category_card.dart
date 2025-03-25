import 'package:flutter/material.dart';
import 'package:eloquence_frontend/app/modern_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Widget représentant une carte de catégorie d'exercice
class CategoryCard extends StatelessWidget {
  /// Titre de la catégorie
  final String title;
  
  /// Description de la catégorie
  final String description;
  
  /// Icône de la catégorie
  final IconData icon;
  
  /// Couleur de la catégorie
  final Color color;
  
  /// Fonction appelée lorsque la carte est pressée
  final VoidCallback onTap;
  
  /// Délai d'animation
  final Duration animationDelay;
  
  /// Constructeur
  const CategoryCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ModernTheme.cardDarkStart,
              ModernTheme.cardDarkEnd,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: ModernTheme.shadowDark,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Contenu principal
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône avec fond
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Titre
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Description
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: ModernTheme.textSecondaryDark,
                      ),
                    ),
                    
                    // Espace pour l'icône de flèche
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              
              // Icône de flèche (en bas à droite)
              Positioned(
                bottom: 16,
                right: 16,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: ModernTheme.textSecondaryDark,
                  size: 16,
                ),
              ),
              
              // Effet de surbrillance en haut
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        color.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
      .animate(delay: animationDelay)
      .fadeIn(duration: 600.ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
    );
  }
}

/// Widget représentant une carte de difficulté
class DifficultyCard extends StatelessWidget {
  /// Niveau de difficulté
  final String level;
  
  /// Indique si la carte est sélectionnée
  final bool isSelected;
  
  /// Fonction appelée lorsque la carte est pressée
  final VoidCallback onTap;
  
  /// Constructeur
  const DifficultyCard({
    super.key,
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isSelected ? Colors.white : ModernTheme.textSecondaryDark;
    final Color backgroundColor = isSelected ? ModernTheme.primaryColor : Colors.transparent;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ModernTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          level,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Widget représentant une carte de session dans l'historique
class SessionHistoryCard extends StatelessWidget {
  /// Date de la session
  final String date;
  
  /// Titre de la session
  final String title;
  
  /// Durée de la session
  final String duration;
  
  /// Score de la session (en pourcentage)
  final int score;
  
  /// Fonction appelée lorsque la carte est pressée
  final VoidCallback onTap;
  
  /// Constructeur
  const SessionHistoryCard({
    super.key,
    required this.date,
    required this.title,
    required this.duration,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Déterminer la couleur du score en fonction de sa valeur
    Color scoreColor;
    if (score >= 80) {
      scoreColor = ModernTheme.successColor;
    } else if (score >= 60) {
      scoreColor = ModernTheme.warningColor;
    } else {
      scoreColor = ModernTheme.errorColor;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: ModernTheme.cardDarkStart,
          boxShadow: [
            BoxShadow(
              color: ModernTheme.shadowDark,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 14,
                      color: ModernTheme.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Titre
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Durée
                  Text(
                    'Durée : $duration',
                    style: TextStyle(
                      fontSize: 14,
                      color: ModernTheme.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            
            // Score
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            
            // Flèche
            Positioned(
              bottom: 20,
              right: 20,
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: ModernTheme.textSecondaryDark,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget représentant une carte de statistique
class StatCard extends StatelessWidget {
  /// Titre de la statistique
  final String title;
  
  /// Valeur de la statistique
  final String value;
  
  /// Icône de la statistique
  final IconData icon;
  
  /// Couleur de l'icône
  final Color iconColor;
  
  /// Constructeur
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ModernTheme.cardDarkStart,
        boxShadow: [
          BoxShadow(
            color: ModernTheme.shadowDark,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône avec fond
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          
          // Valeur
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          
          // Titre
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: ModernTheme.textSecondaryDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Widget représentant un bouton de période pour les statistiques
class PeriodButton extends StatelessWidget {
  /// Texte du bouton
  final String text;
  
  /// Indique si le bouton est sélectionné
  final bool isSelected;
  
  /// Fonction appelée lorsque le bouton est pressé
  final VoidCallback onTap;
  
  /// Constructeur
  const PeriodButton({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isSelected ? Colors.white : ModernTheme.textSecondaryDark;
    final Color backgroundColor = isSelected ? ModernTheme.primaryColor : ModernTheme.cardDarkStart;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ModernTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Widget représentant un bouton de microphone flottant
class MicrophoneButton extends StatelessWidget {
  /// Fonction appelée lorsque le bouton est pressé
  final VoidCallback onTap;
  
  /// Taille du bouton
  final double size;
  
  /// Indique si le bouton est actif (enregistrement en cours)
  final bool isActive;
  
  /// Constructeur
  const MicrophoneButton({
    super.key,
    required this.onTap,
    this.size = 64,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ModernTheme.primaryColor,
          boxShadow: [
            BoxShadow(
              color: ModernTheme.primaryColor.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: size / 2,
        ),
      )
      .animate(onPlay: (controller) => controller.repeat())
      .scaleXY(
        begin: 1.0,
        end: isActive ? 1.1 : 1.0,
        duration: 1000.ms,
        curve: Curves.easeInOut,
      )
      .then()
      .scaleXY(
        begin: isActive ? 1.1 : 1.0,
        end: 1.0,
        duration: 1000.ms,
        curve: Curves.easeInOut,
      ),
    );
  }
}
