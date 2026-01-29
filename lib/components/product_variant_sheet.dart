import 'dart:async';
import 'package:flutter/material.dart';
import 'package:exanor/models/product_model.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/components/peel_button.dart';

class ProductVariantSheet extends StatefulWidget {
  final List<dynamic> variants;
  final Product product;
  final String storeId;
  final Function(int) onAddToCartSuccess;

  const ProductVariantSheet({
    super.key,
    required this.variants,
    required this.product,
    required this.storeId,
    required this.onAddToCartSuccess,
  });

  @override
  State<ProductVariantSheet> createState() => _ProductVariantSheetState();
}

class _ProductVariantSheetState extends State<ProductVariantSheet> {
  // Map of Variation Name -> Selected Value ID Strings
  // Using IDs to match API requirements
  final Map<String, String> _selectedVariationIds = {};

  // State for validation
  bool _isValidating = false;
  bool _isAdding = false;
  String? _error;

  // Confirmed details from validation
  double _currentPrice = 0.0;
  bool _isAvailable = true;
  int _quantity = 1;
  String? _productCombinationId;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    // Validate immediately with initial selections
    _validateAvailability();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _initializeSelections() {
    // Parse variants based on user sample structure (nested variants list)
    // Structure: List -> Map with 'variation_name', 'variation_value' (List)
    for (var variantGroup in widget.variants) {
      if (variantGroup is Map) {
        final name = variantGroup['variation_name'];
        final values =
            variantGroup['variation_value']; // Note: 'variation_value' not 'variation_values' based on sample

        if (name != null && values is List && values.isNotEmpty) {
          // Default to first
          final firstVal = values.first;
          if (firstVal is Map && firstVal['id'] != null) {
            _selectedVariationIds[name] = firstVal['id'];
          }
        }
      }
    }
  }

  Future<void> _validateAvailability() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Debounce to avoid spamming if user taps rapidly
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;

      setState(() {
        _isValidating = true;
        _error = null;
      });

      try {
        // Construct variations list: just the IDs
        final variationIds = _selectedVariationIds.values.toList();

        final requestBody = {
          "product_id": widget.product.id,
          "store_id": widget.storeId,
          "quantity": _quantity,
          "variations": variationIds,
        };

        final response = await ApiService.post(
          '/validate-product-availability/',
          body: requestBody,
          useBearerToken: true,
        );

        if (response['data'] != null) {
          // status might be != 200 based on availability logic, check body
          final data = response['data']['response'];
          if (data != null) {
            if (mounted) {
              setState(() {
                // Ensure types match API sample
                _isAvailable = data['is_available'] ?? false;

                // Pricing
                if (data['pricing_details'] != null) {
                  _currentPrice =
                      (data['pricing_details']['selling_amount_including_tax']
                              as num)
                          .toDouble();
                }

                _productCombinationId = data['product_combination_id'];
                debugPrint("Validated Combination: $_productCombinationId");
                _isValidating = false;
              });
            }
          } else {
            // Handle unexpected structure
            if (mounted) setState(() => _isValidating = false);
          }
        }
      } catch (e) {
        print("Validation error: $e");
        if (mounted) {
          setState(() {
            _isValidating = false;
            // Don't show error to user immediately on validation fail, just maybe disable button or show unavail
          });
        }
      }
    });
  }

  Future<void> _addToCart() async {
    if (!_isAvailable) return;

    setState(() {
      _isAdding = true;
      _error = null;
    });

    try {
      final requestBody = {
        "quantity": _quantity,
        "product_id": widget.product.id,
        "store_id": widget.storeId,
        "variations": _selectedVariationIds.values.toList(),
      };

      final response = await ApiService.post(
        '/add-product-in-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        widget.onAddToCartSuccess(_quantity);
      } else {
        setState(() {
          _error = response['data']?['message'] ?? "Failed to add to cart";
        });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  void _updateQuantity(int delta) {
    if (_quantity + delta < 1) return;
    setState(() {
      _quantity += delta;
      // Trigger validation to get updated price or stock check
      _validateAvailability();
    });
  }

  // Helper to parse hex color from config
  Color _hexToColor(String hex) {
    try {
      String cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse('0x$cleanHex'));
    } catch (e) {
      return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Get gradient colors from Central Config (Remote Config)
    // Matching logic from CustomSliverAppBar (Top Banner)
    final List<Color> buttonGradient = isDarkMode
        ? [
            _hexToColor(
              FirebaseRemoteConfigService.getThemeGradientDarkStart(),
            ),
            _hexToColor(FirebaseRemoteConfigService.getThemeGradientDarkEnd()),
          ]
        : [
            _hexToColor(
              FirebaseRemoteConfigService.getThemeGradientLightStart(),
            ),
            _hexToColor(
              FirebaseRemoteConfigService.getThemeGradientLightStart(),
            ),
          ];

    // Ensure visibility generally by checking if transparent
    final effectiveGradient = (buttonGradient.first == Colors.transparent)
        ? [theme.primaryColor, theme.primaryColor]
        : buttonGradient;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF5F5F7), // Very subtle grey-white
          ],
          // If user wants "Linear Grafing" maybe they mean a literal graph paper? Unlikely.
          // Maybe "Linear Gradient" with strong direction.
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar for visual cue
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.productName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.2,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Price display here if available/static for base
                      // For now, simpler is better
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 20),
                  ),
                  color: Colors.black54,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Error Message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 20, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Variants List - LINEAR Layout (Horizontal Scroll) instead of Wrap
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.variants.map((variantGroup) {
                  if (variantGroup is! Map) return const SizedBox.shrink();

                  final name = variantGroup['variation_name'] ?? 'Option';
                  final values = variantGroup['variation_value'] as List?;

                  if (values == null || values.isEmpty)
                    return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 12,
                        ),
                        child: Text(
                          name.toString().toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[500],
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      // Horizontal List (Linear)
                      SizedBox(
                        height: 50,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          scrollDirection: Axis.horizontal,
                          itemCount: values.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final val = values[index];
                            final valId = val['id'];
                            final valName =
                                val['variation_value_name'] ?? 'Unknown';
                            final isSelected =
                                _selectedVariationIds[name] == valId;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedVariationIds[name] = valId;
                                });
                                _validateAvailability();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  // Linear Gradient for selected item too? or smooth solid color
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.grey[200]!,
                                    width: isSelected ? 0 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  valName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Bottom Section with Quantity and Add Button
          // Using a subtle surface elevation
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
              border: Border(top: BorderSide(color: Colors.grey[50]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price Display - Separate from button
                if (_isAvailable && _currentPrice > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Price',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '₹${_currentPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Quantity and Add to Cart Button Row
                Row(
                  children: [
                    // Quantity Stepper - Linear Design
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFFF5F5F7), // Subtle grey
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Row(
                        children: [
                          _buildQtyBtn(
                            icon: Icons.remove,
                            onTap: () => _updateQuantity(-1),
                            isEnabled: _quantity > 1,
                          ),
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          _buildQtyBtn(
                            icon: Icons.add,
                            onTap: () => _updateQuantity(1),
                            isEnabled: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Add Button using PeelButton (Price removed)
                    Expanded(
                      child: PeelButton(
                        onTap: _addToCart,
                        text: !_isAvailable ? 'UNAVAILABLE' : 'ADD TO CART',
                        price: null, // Price is now displayed separately above
                        isLoading: _isAdding || _isValidating,
                        isEnabled: _isAvailable && !_isAdding && !_isValidating,
                        color: theme.primaryColor,
                        gradientColors: effectiveGradient,
                        height: 56,
                        borderRadius: 16, // Matching Qty Button
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isEnabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 40,
          height: 56,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: isEnabled ? Colors.black87 : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}
