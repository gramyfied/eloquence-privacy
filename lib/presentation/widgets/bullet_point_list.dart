import 'package:flutter/material.dart';

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
    Key? key,
    required this.items,
    this.bulletColor = Colors.white,
    this.bulletSize = 6.0,
    this.spacing = 12.0,
    this.textStyle,
  }) : super(key: key);
  
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
