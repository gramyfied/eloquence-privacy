import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Widget de carte de statistique
class StatCard extends StatelessWidget {
  /// Titre de la statistique
  final String title;
  
  /// Valeur de la statistique
  final String value;
  
  /// Icône de la statistique
  final IconData icon;
  
  /// Dégradé de couleur de la carte
  final Gradient gradient;
  
  /// Hauteur de la carte
  final double? height;
  
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.height,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10), // Padding réduit
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11, // Taille de police réduite
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 2), // Espacement réduit
              Icon(
                icon,
                color: Colors.white,
                size: 14, // Taille d'icône réduite
              ),
            ],
          ),
          const SizedBox(height: 6), // Espacement réduit
          Text(
            value,
            style: const TextStyle(
              fontSize: 18, // Taille de police réduite
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
