import 'package:flutter/material.dart';
import 'package:exanor/models/product_model.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/components/peel_button.dart';

class ProductDetailsSheet extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final int currentQuantity;

  const ProductDetailsSheet({
    super.key,
    required this.product,
    required this.onAdd,
    required this.onRemove,
    required this.currentQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Strict food preference logic: only show if explicitly veg or non-veg
    final foodPref = product.foodPreference.toLowerCase();
    final bool isKnownFoodPref =
        foodPref.contains('veg') || foodPref.contains('non');
    final bool isVeg = foodPref.contains('veg') && !foodPref.contains('non');

    // Dialog Constrained Size
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Image Area
          Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                ),
                child: Hero(
                  tag: 'product_img_${product.id}',
                  child: CustomCachedNetworkImage(
                    imgUrl: product.imgUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Close Button (Top Left)
              Positioned(
                top: 16,
                left: 16,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 24),
                  ),
                ),
              ),

              // Actions (Top Right)
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: [
                    _buildIconButton(Icons.bookmark_border),
                    const SizedBox(width: 12),
                    _buildIconButton(Icons.share_outlined),
                  ],
                ),
              ),
            ],
          ),

          // 2. Details Section
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Metadata Tiles Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Unit Tile
                        _buildInfoTile(
                          theme,
                          label: product.childCategory.isNotEmpty
                              ? product.childCategory
                              : '1 Unit',
                          icon: Icons.scale_outlined,
                        ),

                        // Food Pref Tile (Conditional)
                        if (isKnownFoodPref) ...[
                          const SizedBox(width: 8),
                          _buildInfoTile(
                            theme,
                            label: isVeg ? "Veg" : "Non-Veg",
                            icon: Icons.circle,
                            iconColor: isVeg ? Colors.green : Colors.red,
                            iconSize: 10,
                            isVegIndicator: true,
                          ),
                        ],

                        // Parent Category Tile
                        if (product.parentCategory.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildInfoTile(
                            theme,
                            label: product.parentCategory,
                            icon: Icons.category_outlined,
                          ),
                        ],

                        // Featured Tag
                        if (product.isFeatured) ...[
                          const SizedBox(width: 8),
                          _buildInfoTile(
                            theme,
                            label: "Featured",
                            icon: Icons.star,
                            isHighlight: true,
                            iconColor: Colors.amber,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    "Description",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description.isNotEmpty
                        ? product.description
                        : "Fresh and high quality product directly from the store. Enjoy the premium quality and fast delivery.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 3. Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.05),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Price Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.priceStartsFrom != null &&
                        product.lowestAvailablePrice != null &&
                        product.lowestAvailablePrice! >
                            product.priceStartsFrom!)
                      Text(
                        "${((1 - (product.priceStartsFrom! / product.lowestAvailablePrice!)) * 100).toInt()}% OFF",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₹${product.priceStartsFrom?.toStringAsFixed(0) ?? '--'}",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (product.lowestAvailablePrice != null &&
                            product.lowestAvailablePrice! >
                                (product.priceStartsFrom ?? 0))
                          Text(
                            "₹${product.lowestAvailablePrice!.toStringAsFixed(0)}",
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // Add Button
                SizedBox(
                  width: 140,
                  height: 48,
                  child: currentQuantity == 0
                      ? PeelButton(
                          height: 48,
                          borderRadius: 12,
                          onTap: onAdd,
                          text: "ADD",
                          color: const Color(0xFF1B4B66), // Deep brand color
                          isEnabled: true,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B4B66),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1B4B66).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSheetQtyBtn(Icons.remove, onRemove),
                              Container(
                                width: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  '$currentQuantity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              _buildSheetQtyBtn(Icons.add, onAdd),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    ThemeData theme, {
    required String label,
    required IconData icon,
    bool isHighlight = false,
    Color? iconColor,
    double iconSize = 14,
    bool isVegIndicator = false,
  }) {
    final borderColor = isHighlight
        ? Colors.amber.withOpacity(0.5)
        : isVegIndicator
        ? (iconColor ?? Colors.grey).withOpacity(0.5)
        : theme.colorScheme.outline.withOpacity(0.1);

    final bgColor = isHighlight
        ? Colors.amber.withOpacity(0.1)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVegIndicator)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                border: Border.all(
                  color: iconColor ?? Colors.black,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(
                  2,
                ), // Square for food mark styling usually, but rounded matches app
              ),
              alignment: Alignment.center,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: iconColor ?? Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? theme.colorScheme.onSurface.withOpacity(0.6),
            ),

          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.1, // Tight height for alignment
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetQtyBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(
          0.8,
        ), // Glassy white for buttons on image
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
        ],
      ),
      child: Icon(icon, size: 20, color: Colors.black87),
    );
  }
}
