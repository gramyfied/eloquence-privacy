import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Widget qui affiche une icône d'information qui, lorsqu'elle est cliquée,
/// affiche une modale avec des informations détaillées
class InfoIconButton extends StatelessWidget {
  /// Titre de l'information
  final String title;
  
  /// Description détaillée
  final String description;
  
  /// Liste des bénéfices
  final List<String> benefits;
  
  /// Instructions d'utilisation
  final String instructions;
  
  /// Animation optionnelle à afficher dans la modale
  final Widget? animation;
  
  /// Couleur de fond du bouton
  final Color backgroundColor;
  
  /// Taille de l'icône
  final double iconSize;
  
  const InfoIconButton({
    super.key,
    required this.title,
    required this.description,
    required this.benefits,
    required this.instructions,
    this.animation,
    this.backgroundColor = Colors.blue,
    this.iconSize = 24.0,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showInfoModal(context),
      child: Container(
        width: iconSize + 16,
        height: iconSize + 16,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.info_outline,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
  
  void _showInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => InfoModal(
        title: title,
        description: description,
        benefits: benefits,
        instructions: instructions,
        animation: animation,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

/// Widget qui affiche une modale avec des informations détaillées
class InfoModal extends StatelessWidget {
  /// Titre de l'information
  final String title;
  
  /// Description détaillée
  final String description;
  
  /// Liste des bénéfices
  final List<String> benefits;
  
  /// Instructions d'utilisation
  final String instructions;
  
  /// Animation optionnelle à afficher dans la modale
  final Widget? animation;
  
  /// Couleur de fond de la modale
  final Color backgroundColor;
  
  const InfoModal({
    super.key,
    required this.title,
    required this.description,
    required this.benefits,
    required this.instructions,
    this.animation,
    required this.backgroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Poignée de la modale
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // En-tête
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  backgroundColor,
                  backgroundColor.withOpacity(0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Contenu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Animation (si disponible)
                  if (animation != null) ...[
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: animation,
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Bénéfices
                  const Text(
                    'Bénéfices',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BulletPointList(
                    items: benefits,
                    bulletColor: backgroundColor,
                  ),
                  const SizedBox(height: 24),
                  
                  // Instructions
                  const Text(
                    'Comment pratiquer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    instructions,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bouton de fermeture
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Compris !',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget qui affiche une liste de points avec des puces
class BulletPointList extends StatelessWidget {
  /// Liste des éléments à afficher
  final List<String> items;
  
  /// Couleur des puces
  final Color bulletColor;
  
  /// Taille des puces
  final double bulletSize;
  
  /// Espacement entre les éléments
  final double spacing;
  
  /// Style de texte pour les éléments
  final TextStyle? textStyle;
  
  const BulletPointList({
    super.key,
    required this.items,
    this.bulletColor = Colors.white,
    this.bulletSize = 6.0,
    this.spacing = 12.0,
    this.textStyle,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => _buildBulletItem(item, context)).toList(),
    );
  }
  
  Widget _buildBulletItem(String item, BuildContext context) {
    final defaultTextStyle = TextStyle(
      fontSize: 16,
      color: Colors.white.withOpacity(0.9),
      height: 1.5,
    );
    
    return Padding(
      padding: EdgeInsets.only(bottom: spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              width: bulletSize,
              height: bulletSize,
              decoration: BoxDecoration(
                color: bulletColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item,
              style: textStyle ?? defaultTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}
