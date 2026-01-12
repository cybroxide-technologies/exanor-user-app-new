import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/product_model.dart';

import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/components/order_method_selector.dart';
import 'package:exanor/components/product_variant_sheet.dart'; // Added
import 'package:shimmer/shimmer.dart';

class CartScreen extends StatefulWidget {
  final String storeId;
  final String userAddressId;
  final double lat;
  final double lng;

  const CartScreen({
    super.key,
    required this.storeId,
    required this.userAddressId,
    required this.lat,
    required this.lng,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _cartData;
  List<Product> _suggestedProducts = [];
  bool _isLoadingSuggestions = true;
  List<dynamic> _orderMethods = [];
  String? _selectedOrderMethodId;
  final Set<String> _updatingItemIds = {};

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _fetchOrderMethods();
    _initDataSequentially();
  }

  Future<void> _initDataSequentially() async {
    await _fetchCartData();
    if (mounted) {
      _fetchProductSuggestions();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderMethods() async {
    try {
      final requestBody = {
        "query": {"is_enabled": true},
        "store_id": widget.storeId,
      };

      final response = await ApiService.post(
        '/order-method/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final methods = response['data']['response'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _orderMethods = methods;
            // Try to select existing method from cart if available, else first
            // For now default to first if not set
            if (_selectedOrderMethodId == null && methods.isNotEmpty) {
              _selectedOrderMethodId = methods.first['id'];
            }
          });

          // If we have cart data, see if it has method id
          if (_cartData != null && _cartData!['order_method_id'] != null) {
            setState(() {
              _selectedOrderMethodId = _cartData!['order_method_id'];
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching order methods: $e');
    }
  }

  Future<void> _fetchCartData({bool forceLoading = false}) async {
    if (forceLoading) {
      if (mounted) setState(() => _isLoading = true);
    }
    try {
      final requestBody = {
        "coupon_code": "",
        "store_id": widget.storeId,
        "order_method_id": _selectedOrderMethodId ?? "",
        "user_address_id": widget.userAddressId,
        "lat": widget.lat,
        "lng": widget.lng,
      };

      final response = await ApiService.post(
        '/auto-validate-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      // Handle 200 or 400 with data
      if (response['data'] != null && response['data']['response'] != null) {
        if (mounted) {
          setState(() {
            _cartData = response['data']['response'];

            // Sync method ID if returned from backend
            if (_cartData!['order_method_id'] != null) {
              _selectedOrderMethodId = _cartData!['order_method_id'];
            }

            _isLoading = false;
            _filterSuggestions(animate: true);
          });
        }
      } else {
        // Fallback for error?
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (e is ApiException && e.response != null) {
        final response = e.response!;
        if (response['data'] != null && response['data']['response'] != null) {
          if (mounted) {
            setState(() {
              _cartData = response['data']['response'];

              if (_cartData!['order_method_id'] != null) {
                _selectedOrderMethodId = _cartData!['order_method_id'];
              }

              _isLoading = false;
              _filterSuggestions(animate: true);
            });
          }
          return;
        }
      }
      print('❌ Error fetching cart: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSuggestions({bool animate = true}) {
    if (_cartData == null || _suggestedProducts.isEmpty) return;

    final cartItems = _cartData!['items_available'] as List?;
    final itemIdsInCart = <String>{};

    // Helper to extract IDs safely
    void extractIds(List? items) {
      if (items == null) return;
      for (var item in items) {
        if (item is Map) {
          if (item['product_id'] != null)
            itemIdsInCart.add(item['product_id'].toString());
          // Also check for product_combination_id or id if needed, but product_id is safest for "product" level exclusion
        }
      }
    }

    extractIds(cartItems);
    extractIds(_cartData!['product_in_cart'] as List?);

    // Iterate backwards to remove safely
    for (int i = _suggestedProducts.length - 1; i >= 0; i--) {
      // Robust comparison
      if (itemIdsInCart.contains(_suggestedProducts[i].id.toString())) {
        final removedItem = _suggestedProducts[i];

        // If we are animating (view is likely visible)
        if (animate &&
            _listKey.currentState != null &&
            !_isLoadingSuggestions) {
          _suggestedProducts.removeAt(i);
          _listKey.currentState!.removeItem(
            i,
            (context, animation) => SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              child: _buildSuggestionCard(
                removedItem,
                Theme.of(context),
                isRemoving: true,
              ),
            ),
            duration: const Duration(milliseconds: 300),
          );
        } else {
          // Just remove from list if not animating or view not ready
          _suggestedProducts.removeAt(i);
        }
      }
    }
  }

  Future<void> _fetchProductSuggestions() async {
    // Basic fetch of products fro store as suggestion
    // Reusing store fetch logic simplified
    try {
      final requestBody = {"store_id": widget.storeId, "query": {}, "page": 1};

      final response = await ApiService.post(
        '/product/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final list = (response['data']['response'] as List)
            .map((e) => Product.fromJson(e))
            .toList();
        if (mounted) {
          setState(() {
            _suggestedProducts = list.take(6).toList(); // Take slightly more
            _filterSuggestions(
              animate: false,
            ); // Filter initially without animation as list is just building
            _isLoadingSuggestions = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  Map<String, dynamic>? _findProductDetails(String combinationId) {
    if (_cartData == null) return null;
    final productsInCart = _cartData!['product_in_cart'] as List?;
    if (productsInCart == null) return null;

    try {
      return productsInCart.firstWhere(
        (p) =>
            p['product_combination_id'] == combinationId ||
            p['id'] == combinationId,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _incrementCartItem(Map<String, dynamic> item) async {
    final combinationId = item['product_combination_id'] ?? item['id'];

    if (_updatingItemIds.contains(combinationId)) return;

    final productEntry = _findProductDetails(combinationId);
    if (productEntry == null) return;

    setState(() {
      _updatingItemIds.add(combinationId);
    });

    try {
      final requestBody = {
        "quantity": 1,
        "product_id": productEntry['product_id'],
        "store_id": widget.storeId,
        "variations": productEntry['product_variations'] ?? [],
      };

      final response = await ApiService.post(
        '/add-product-in-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        await _fetchCartData(forceLoading: false);
      } else {
        await _fetchCartData(forceLoading: false);
      }
    } catch (e) {
      print('Error incrementing: $e');
    } finally {
      if (mounted) {
        setState(() {
          _updatingItemIds.remove(combinationId);
        });
      }
    }
  }

  Future<void> _decrementCartItem(Map<String, dynamic> item) async {
    final combinationId = item['product_combination_id'] ?? item['id'];

    if (_updatingItemIds.contains(combinationId)) return;

    final currentQty = (item['enquired_quantity'] as num?)?.toInt() ?? 1;

    if (currentQty <= 1) {
      final confirm = await _showRemoveConfirmation();
      if (!confirm) return;
    }

    final productEntry = _findProductDetails(combinationId);
    if (productEntry == null) return;

    setState(() {
      _updatingItemIds.add(combinationId);
    });

    try {
      final requestBody = {
        "store_id": widget.storeId,
        "product_id": "",
        "product_combination_id": item['id'],
      };

      final response = await ApiService.post(
        '/decrement-product-in-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        await _fetchCartData(forceLoading: false);
      } else {
        await _fetchCartData(forceLoading: false);
      }
    } catch (e) {
      print('Error decrementing: $e');
    } finally {
      if (mounted) {
        setState(() {
          _updatingItemIds.remove(combinationId);
        });
      }
    }
  }

  Future<void> _addSuggestedProduct(Product product, int index) async {
    try {
      final requestBody = {
        "order_by": "variation_name",
        "query": {"store_id": widget.storeId, "product_id": product.id},
      };

      // Show loading on the specific item if desired, or simplified

      final response = await ApiService.post(
        '/product-variation-value/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final isSuccess =
            responseData['additional_data']?['is_product_added_to_cart_successfully'] ==
            true;

        if (isSuccess) {
          _handleSuggestionAdded(index);
        } else {
          // Has variants
          final variants = responseData['response'];
          if (variants is List) {
            _showVariantsBottomSheet(variants, product, (qty) {
              _handleSuggestionAdded(index);
              Navigator.pop(context);
            });
          }
        }
      }
    } catch (e) {
      print('Error adding suggestion: $e');
    }
  }

  void _handleSuggestionAdded(int index) {
    // 1. Refresh Cart
    _fetchCartData(forceLoading: false);

    // 2. Remove from list with animation
    if (index < _suggestedProducts.length) {
      final removedItem = _suggestedProducts[index];
      _suggestedProducts.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => SizeTransition(
          sizeFactor: animation,
          axis: Axis.horizontal,
          child: _buildSuggestionCard(
            removedItem,
            Theme.of(context),
            isRemoving: true,
          ),
        ),
        duration: const Duration(milliseconds: 500),
      );
    }

    // 3. Scroll to top
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  void _showVariantsBottomSheet(
    List<dynamic> variants,
    Product product,
    Function(int) onSuccess,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ProductVariantSheet(
          variants: variants,
          product: product,
          storeId: widget.storeId,
          onAddToCartSuccess: onSuccess,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading && _cartData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          title: const Text('Cart'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: _buildSkeletonLoader(),
      );
    }

    if (_cartData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(title: const Text('Cart')),
        body: const Center(child: Text('Failed to load cart')),
      );
    }

    final items = _cartData!['items_available'] as List? ?? [];
    // If items_available is empty, maybe check product_in_cart?
    // User sample has items in items_available.

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(
          'Cart',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
        bottom: _orderMethods.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: OrderMethodSelector(
                  methods: _orderMethods,
                  selectedMethodId: _selectedOrderMethodId,
                  onMethodSelected: (id) {
                    setState(() {
                      _selectedOrderMethodId = id;
                      _isLoading = true; // Reload cart with new method
                    });
                    _fetchCartData(forceLoading: true);
                  },
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_fetchCartData(), _fetchProductSuggestions()]);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              if (_isLoading && _cartData != null)
                const LinearProgressIndicator(minHeight: 2),

              // ... existing column children
              // ... existing column children
              // Delivery Alert / Savings
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.green.withOpacity(0.1),
                child: Row(
                  children: [
                    const Text('🎉'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You saved ₹10 with Gold', // Placeholder from screenshot
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cart Items List
              if (items.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ...items.map((item) => _buildCartItemRow(item, theme)),

                      // Add more items button
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.add,
                                    color: Colors.deepOrange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add more items',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(height: 1),

                      // Note and Cutlery
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.note_alt_outlined,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        "Add a note",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.cut_outlined,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        "No cutlery",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Product Suggestions
              if (_isLoadingSuggestions)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_suggestedProducts.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Complete your meal with",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: AnimatedList(
                        key: _listKey,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        initialItemCount: _suggestedProducts.length,
                        itemBuilder: (context, index, animation) {
                          // Ideally handle out of bounds if removing fast, but AnimatedList usually handles indices well
                          if (index >= _suggestedProducts.length)
                            return const SizedBox.shrink();

                          return SlideTransition(
                            position: animation.drive(
                              Tween(
                                begin: const Offset(1, 0),
                                end: const Offset(0, 0),
                              ),
                            ),
                            child: _buildSuggestionCard(
                              _suggestedProducts[index],
                              theme,
                              onTapAdd: () => _addSuggestedProduct(
                                _suggestedProducts[index],
                                index,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

              // Coupons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.percent, color: Colors.blue),
                  title: const Text(
                    "View all coupons",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to coupons
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Bill Details
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bill Details",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Item Total
                    ...(_cartData!['cart_total'] as List).map<Widget>((e) {
                      if ((e['value'] as num) == 0)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e['title'],
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            Text('₹${(e['value'] as num).toStringAsFixed(2)}'),
                          ],
                        ),
                      );
                    }).toList(),

                    const Divider(),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Grand Total",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '₹${(_cartData!['grand_total'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Policy Text
              if (_cartData!['refund_policy'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Refund Policy",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cartData!['refund_policy'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Payment method icon/text
                        const Icon(
                          Icons.payment,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "PAY USING",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_up,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Google Pay UPI",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (_selectedOrderMethodId == null)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Text(
                        "Select Order Method",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.primary, // Primary color
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${(_cartData!['grand_total'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              "TOTAL",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: const [
                            Text(
                              "Place Order",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(Icons.arrow_right, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemRow(Map<String, dynamic> item, ThemeData theme) {
    final pricing = item['pricing_details'];
    final price = pricing != null
        ? (pricing['item_total'] as num? ?? 0.0)
        : 0.0;
    final unitPrice = pricing != null
        ? (pricing['selling_amount_including_tax'] as num? ?? 0.0)
        : 0.0;
    final qty = item['enquired_quantity'] as int? ?? 1;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Veg/Non-veg icon (Mocking for now as it's not in item detail explicitly in sample, or assuming standard)
          Container(
            margin: const EdgeInsets.only(top: 4, right: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.circle, size: 8, color: Colors.green),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('₹${unitPrice.toStringAsFixed(2)}'),
              ],
            ),
          ),

          // Quantity Control
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.primary.withOpacity(0.05),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _decrementCartItem(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 30, // Fixed width to prevent jumping
                  child: Center(
                    child:
                        _updatingItemIds.contains(
                          item['product_combination_id'] ?? item['id'],
                        )
                        ? Opacity(
                            opacity: 0.5,
                            child: Text(
                              '$qty',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : Text(
                            '$qty',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                  ),
                ),
                InkWell(
                  onTap: () => _incrementCartItem(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          Text(
            '₹${price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(
    Product product,
    ThemeData theme, {
    VoidCallback? onTapAdd,
    bool isRemoving = false,
  }) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: isRemoving
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CustomCachedNetworkImage(
              imgUrl: product.imgUrl,
              height: 90,
              width: 140,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (product.priceStartsFrom != null)
                      Text(
                        '₹${product.priceStartsFrom!.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12),
                      ),

                    // Add btn
                    InkWell(
                      onTap: onTapAdd,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.red,
                        ),
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

  Future<bool> _showRemoveConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Item?'),
            content: const Text(
              'Are you sure you want to remove this item from your cart?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Alert Skeleton
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Items Skeleton
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Suggestions
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Bill Details
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
