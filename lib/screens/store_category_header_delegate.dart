import 'dart:math';
import 'package:flutter/material.dart';
import 'package:exanor/models/category_model.dart';

class StoreCategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<ProductCategory> categories;
  final String? selectedCategoryId;
  final Function(String?) onCategorySelected;
  final VoidCallback onMenuPressed;
  final bool isLoading;
  final ThemeData theme;

  StoreCategoryHeaderDelegate({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onMenuPressed,
    required this.isLoading,
    required this.theme,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = shrinkOffset / maxExtent;
    // 0.0 = Expanded (List), 1.0 = Collapsed (Button)

    // Smooth transition thresholds
    final showList = progress < 0.4;
    final showButton = progress > 0.6;

    // Opacity handling
    final listOpacity = (1.0 - (progress * 2.5)).clamp(0.0, 1.0);
    final buttonOpacity = ((progress - 0.6) * 2.5).clamp(0.0, 1.0);

    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.colorScheme.surface;

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          // 1. Expanded List View
          if (!showButton)
            Opacity(
              opacity: listOpacity,
              child: SizedBox(
                height: maxExtent,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: isLoading
                      ? 6
                      : categories.length + 1, // +1 for "All"
                  itemBuilder: (context, index) {
                    if (isLoading) {
                      return _buildShimmerChip(isDark);
                    }

                    if (index == 0) {
                      return _buildCategoryChip(
                        label: "All",
                        isSelected: selectedCategoryId == null,
                        onTap: () => onCategorySelected(null),
                      );
                    }

                    final category = categories[index - 1];
                    return _buildCategoryChip(
                      label: category.categoryName,
                      isSelected: selectedCategoryId == category.id,
                      onTap: () => onCategorySelected(category.id),
                    );
                  },
                ),
              ),
            ),

          // 2. Collapsed Button View
          if (showButton)
            Opacity(
              opacity: buttonOpacity,
              child: Center(
                child: InkWell(
                  onTap: onMenuPressed,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "CATEGORIES",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: isSelected
            ? theme.colorScheme.primary.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.5)
              : Colors.transparent,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildShimmerChip(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 80,
        height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(covariant StoreCategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedCategoryId != selectedCategoryId ||
        oldDelegate.categories != categories ||
        oldDelegate.isLoading != isLoading;
  }
}
