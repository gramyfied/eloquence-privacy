import 'package:flutter/material.dart';
import '../../../core/theme/dark_theme.dart';

class GradientBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationItem> items;
  final double height;
  final double borderRadius;
  final Color? backgroundColor;
  
  const GradientBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = 80.0,
    this.borderRadius = 30.0,
    this.backgroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? DarkTheme.backgroundMedium.withOpacity(0.8);
    
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == currentIndex;
            
            return _buildNavItem(
              context: context,
              item: item,
              isSelected: isSelected,
              onTap: () => onTap(index),
            );
          }),
        ),
      ),
    );
  }
  
  Widget _buildNavItem({
    required BuildContext context,
    required BottomNavigationItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Couleurs pour l'état sélectionné et non sélectionné
    final Color selectedColor = item.selectedColor ?? DarkTheme.primaryPurple;
    final Color unselectedColor = item.unselectedColor ?? DarkTheme.textSecondary;
    
    // Couleur actuelle basée sur l'état
    final color = isSelected ? selectedColor : unselectedColor;
    
    // Effet de lueur pour l'élément sélectionné
    final decoration = isSelected
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                selectedColor.withOpacity(0.0),
                selectedColor.withOpacity(0.1),
                selectedColor.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          )
        : null;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: decoration,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Indicateur supérieur pour l'élément sélectionné
              if (isSelected)
                Container(
                  width: 20,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        selectedColor.withOpacity(0.7),
                        selectedColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(
                        color: selectedColor.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 11),
              
              // Icône avec effet de lueur si sélectionné
              Icon(
                item.icon,
                color: color,
                size: isSelected ? 26 : 24,
                shadows: isSelected
                    ? [
                        Shadow(
                          color: selectedColor.withOpacity(0.7),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              
              const SizedBox(height: 4),
              
              // Texte
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  shadows: isSelected
                      ? [
                          Shadow(
                            color: selectedColor.withOpacity(0.7),
                            blurRadius: 5,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottomNavigationItem {
  final IconData icon;
  final String label;
  final Color? selectedColor;
  final Color? unselectedColor;
  
  const BottomNavigationItem({
    required this.icon,
    required this.label,
    this.selectedColor,
    this.unselectedColor,
  });
}
