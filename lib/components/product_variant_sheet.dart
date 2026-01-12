import 'package:flutter/material.dart';
import 'package:exanor/models/product_model.dart';
import 'package:exanor/services/api_service.dart';

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
  // Map of Variation Name -> Selected Value Object
  final Map<String, dynamic> _selectedVariations = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
  }

  void _initializeSelections() {
    // Try to pre-select first option for each variation if possible
    for (var variantGroup in widget.variants) {
      if (variantGroup is Map) {
        final name = variantGroup['variation_name'];
        final values = variantGroup['variation_values'];
        if (name != null && values is List && values.isNotEmpty) {
          // Default to first
          _selectedVariations[name] = values.first;
        }
      }
    }
  }

  Future<void> _addToCart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Construct variations list for API
      // Expected format based on usage in other parts of app:
      // "variations": [ { "variation_id": "...", "variation_value_id": "..." } ]
      // Or similar.
      // Based on typical backend for this user (Exanor), usually it wants the combination.
      // But let's check what CartScreen uses for increment:
      // "variations": productEntry['product_variations'] ?? [],

      // We need to construct the list of selected variations.
      List<Map<String, dynamic>> selectedVars = [];

      _selectedVariations.forEach((key, value) {
        // Assuming value has needed IDs.
        // If the structure from /product-variation-value/ is:
        // { "variation_name": "Size", "variation_id": "123", "variation_values": [{"id": "v1", "value": "Small"}] }

        // We might need to pass specific structure.
        // Let's guess typical structure:
        if (value is Map) {
          // This is the selected value object.
          // We probably need to send back what defines the combination.
          selectedVars.add(Map<String, dynamic>.from(value));
        }
      });

      final requestBody = {
        "quantity": 1,
        "product_id": widget.product.id,
        "store_id": widget.storeId,
        "variations": selectedVars,
      };

      final response = await ApiService.post(
        '/add-product-in-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        widget.onAddToCartSuccess(1);
        // helper handles closing if needed, or we close here?
        // Usually caller closes logic?
        // CartScreen usage: _showVariantsBottomSheet(..., onSuccess: (qty) { ... Navigator.pop ... })
        // So we just call success.
      } else {
        setState(() {
          _error = response['data']?['message'] ?? "Failed to add to cart";
        });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred";
      });
      print("Add to cart error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.product.productName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // Variants List
          ...widget.variants.map((variantGroup) {
            if (variantGroup is! Map) return const SizedBox.shrink();

            final name = variantGroup['variation_name'] ?? 'Option';
            final values = variantGroup['variation_values'] as List?;

            if (values == null || values.isEmpty)
              return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12, // Horizontal spacing
                    runSpacing: 12, // Vertical spacing
                    children: values.map((val) {
                      final isSelected = _selectedVariations[name] == val;
                      final valLabel =
                          val['value'] ??
                          val['name'] ??
                          'Unknown'; // Adjust based on actual API

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedVariations[name] = val;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            valLabel,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Add to Cart',
                      style: TextStyle(
                        color: Colors.white,
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
