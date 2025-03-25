import 'package:flutter/material.dart';
import '../../app/theme.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData? icon;
  final String? iconAsset;
  final Color backgroundColor;
  final Color textColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const CategoryCard({
    Key? key,
    required this.title,
    required this.description,
    this.icon,
    this.iconAsset,
    this.backgroundColor = AppTheme.darkSurface,
    this.textColor = Colors.white,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.borderRadius,
  }) : assert(icon != null || iconAsset != null, 'Either icon or iconAsset must be provided'),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.borderRadius3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon or Image
            iconAsset != null
                ? Image.asset(
                    iconAsset!,
                    width: 32,
                    height: 32,
                    color: textColor,
                  )
                : Icon(
                    icon,
                    size: 32,
                    color: textColor,
                  ),
                  
            const SizedBox(height: 12),
            
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Arrow indicator for navigation
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward,
                color: textColor.withOpacity(0.7),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryGrid extends StatelessWidget {
  final List<CategoryCardData> categories;
  final int crossAxisCount;
  final double spacing;
  final double aspectRatio;
  final EdgeInsets padding;

  const CategoryGrid({
    Key? key,
    required this.categories,
    this.crossAxisCount = 2,
    this.spacing = 16.0,
    this.aspectRatio = 1.0,
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return CategoryCard(
            title: category.title,
            description: category.description,
            icon: category.icon,
            iconAsset: category.iconAsset,
            backgroundColor: category.backgroundColor,
            textColor: category.textColor,
            onTap: category.onTap,
          );
        },
      ),
    );
  }
}

class CategoryCardData {
  final String title;
  final String description;
  final IconData? icon;
  final String? iconAsset;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  CategoryCardData({
    required this.title,
    required this.description,
    this.icon,
    this.iconAsset,
    this.backgroundColor = AppTheme.darkSurface,
    this.textColor = Colors.white,
    this.onTap,
  });
}
