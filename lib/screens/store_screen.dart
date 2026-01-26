import 'dart:async';
import 'dart:ui' as ui;
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/models/store_model.dart';
import 'package:exanor/models/product_model.dart';
import 'package:exanor/models/category_model.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/screens/cart_screen.dart';
import 'package:exanor/components/product_variant_sheet.dart';
import 'package:exanor/components/voice_search_sheet.dart';
import 'package:exanor/components/peel_button.dart';

class StoreScreen extends StatefulWidget {
  final String storeId;
  final String? initialSearchQuery;
  // ignore: unused_field
  final String? _ignored = null; // Forces rebuild for UI refresh

  const StoreScreen({
    super.key,
    required this.storeId,
    this.initialSearchQuery,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Store? _store;
  bool _isLoadingStore = true;
  String? _errorMessage;

  // Products
  List<Product> _products = [];
  bool _isLoadingProducts = false;
  bool _isLoadingMoreProducts = false;
  int _currentPage = 1;
  bool _hasMoreProducts = true;

  // Search
  String _searchQuery = '';
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingSearchResults = false;
  bool _isLoadingMoreSearchResults = false;
  int _searchPage = 1;
  bool _hasMoreSearchResults = false;
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  // Categories
  List<ProductCategory> _categories = [];
  bool _isLoadingCategories = false;
  String? _selectedCategoryId;

  // Default constant ID for user address
  final String _constAddressId = "e3d3142b-6065-4052-95f6-854a6bb039e9";
  String _userAddressId = "e3d3142b-6065-4052-95f6-854a6bb039e9";
  double _userLat = 0.0;
  double _userLng = 0.0;

  late ScrollController _scrollController;

  // Cart logic
  double? _cartGrandTotal;
  int _cartItemCount = 0;
  bool _isCartVisible = false;

  // Header State
  bool _showTitle = false;
  bool _isHeaderSearchActive = false; // Toggle for header search bar

  // State for menu refresh (fixes popup not updating)
  final ValueNotifier<int> _menuUpdateNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _loadAddressAndFetchStore();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _menuUpdateNotifier.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      // 1. Handle Title Visibility
      // Show title/search in banner when user scrolls down
      // Adjusted threshold to 150 for balanced appearance
      final showTitleThreshold = 145.0;

      if (currentScroll > showTitleThreshold && !_showTitle) {
        setState(() => _showTitle = true);
      } else if (currentScroll <= showTitleThreshold && _showTitle) {
        setState(() => _showTitle = false);
      }

      // 2. Pagination Logic
      final threshold = maxScroll * 0.75; // Trigger at 75%
      if (currentScroll >= threshold) {
        if (_isSearching) {
          if (!_isLoadingMoreSearchResults && _hasMoreSearchResults) {
            _searchProducts(widget.storeId, _searchQuery, loadMore: true);
          }
        } else {
          if (!_isLoadingMoreProducts && _hasMoreProducts) {
            _fetchProducts(loadMore: true);
          }
        }
      }
    }
  }

  Future<void> _searchProducts(
    String storeId,
    String query, {
    bool loadMore = false,
  }) async {
    if (query.trim().length < 3) return;

    if (loadMore && _isLoadingMoreSearchResults) return;
    if (!loadMore && _isLoadingSearchResults) return;

    if (!mounted) return;

    setState(() {
      if (loadMore) {
        _isLoadingMoreSearchResults = true;
      } else {
        _isLoadingSearchResults = true;
        _isSearching = true;
        _searchPage = 1;
      }
    });

    try {
      final requestBody = {
        "query": query,
        "store_id": storeId,
        "lat": _userLat, // Using fetched user latitude
        "lng": _userLng, // Using fetched user longitude
        "is_store": false,
        "page": loadMore ? _searchPage + 1 : _searchPage,
      };

      print(
        '🔍 Searching products: $query, Page ${loadMore ? _searchPage + 1 : _searchPage}',
      );

      final response = await ApiService.post(
        '/search-in-store/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final productsList = (responseData['response'] as List)
            .map((item) => Product.fromJson(item))
            .toList();

        final hasNext = responseData['has_next'] ?? false;

        if (mounted) {
          setState(() {
            if (loadMore) {
              _searchResults.addAll(productsList);
              _searchPage++;
            } else {
              _searchResults = productsList;
            }
            _hasMoreSearchResults = hasNext;
            _isLoadingSearchResults = false;
            _isLoadingMoreSearchResults = false;
          });
        }
      } else {
        print('❌ Failed to search products: ${response['data']}');
        if (mounted) {
          setState(() {
            _isLoadingSearchResults = false;
            _isLoadingMoreSearchResults = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error searching products: $e');
      if (mounted) {
        setState(() {
          _isLoadingSearchResults = false;
          _isLoadingMoreSearchResults = false;
        });
      }
    }
  }

  Future<void> _loadAddressAndFetchStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddressId = prefs.getString('saved_address_id');

      // Try to get coordinates as double first, then as string if needed
      double? lat;
      double? lng;

      // Try to get latitude
      lat = prefs.getDouble('latitude');
      if (lat == null) {
        final latStr =
            prefs.getString('lat_string') ?? prefs.getString('user_latitude');
        if (latStr != null) {
          lat = double.tryParse(latStr);
        }
      }

      // Try to get longitude
      lng = prefs.getDouble('longitude');
      if (lng == null) {
        final lngStr =
            prefs.getString('lng_string') ?? prefs.getString('user_longitude');
        if (lngStr != null) {
          lng = double.tryParse(lngStr);
        }
      }

      final finalLat = lat ?? 0.0;
      final finalLng = lng ?? 0.0;

      print('📍 StoreScreen - Loaded coordinates from SharedPreferences:');
      print(
        '   Lat: $finalLat (from ${lat != null ? 'double' : 'string/default'})',
      );
      print(
        '   Lng: $finalLng (from ${lng != null ? 'double' : 'string/default'})',
      );
      print('   Address ID: ${savedAddressId ?? _constAddressId}');

      setState(() {
        if (savedAddressId != null && savedAddressId.isNotEmpty) {
          _userAddressId = savedAddressId;
        } else {
          _userAddressId = _constAddressId;
        }
        _userLat = finalLat;
        _userLng = finalLng;
      });

      // Handle initial search if provided
      if (widget.initialSearchQuery != null &&
          widget.initialSearchQuery!.isNotEmpty) {
        _searchController.text = widget.initialSearchQuery!;
        _searchQuery = widget.initialSearchQuery!;
        _searchProducts(widget.storeId, _searchQuery);
      }

      await _fetchStoreDetails();
      // Only fetch default products if NOT searching (or fetch anyway, but UI will show search results)
      // It's better to fetch default products too so if user closes search, they see something.
      await _fetchProducts();
      await _fetchCategories();
      await _fetchCartDetails();
    } catch (e) {
      print('❌ StoreScreen: Error loading address data: $e');
      _userAddressId = _constAddressId;
      await _fetchStoreDetails();
      await _fetchProducts();
      await _fetchCartDetails();
    }
  }

  Future<void> _fetchStoreDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoadingStore = true;
      _errorMessage = null;
    });

    try {
      final requestBody = {
        "user_address_id": _userAddressId,
        "store_id": widget.storeId,
        "page": 1,
      };

      print('🏪 Fetching store details for: ${widget.storeId}');

      final response = await ApiService.post(
        '/get-stores/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final storesList = (responseData['response'] as List)
            .map((item) => Store.fromJson(item))
            .toList();

        if (mounted) {
          setState(() {
            if (storesList.isNotEmpty) {
              _store = storesList.first;
              _isLoadingStore = false;
            } else {
              _errorMessage = 'Store not found';
              _isLoadingStore = false;
            }
          });
        }
      } else {
        print('❌ Failed to fetch store details: ${response['data']}');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load store details';
            _isLoadingStore = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching store details: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
          _isLoadingStore = false;
        });
      }
    }
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (loadMore && _isLoadingMoreProducts) return;
    if (!loadMore && _isLoadingProducts) return;

    if (!mounted) return;

    setState(() {
      if (loadMore) {
        _isLoadingMoreProducts = true;
      } else {
        _isLoadingProducts = true;
        _currentPage = 1;
      }
    });

    try {
      final Map<String, dynamic> queryMap = {};
      if (_selectedCategoryId != null) {
        queryMap["parent_category_id"] = _selectedCategoryId;
      }

      final requestBody = {
        "store_id": widget.storeId,
        "query": queryMap,
        "page": loadMore ? _currentPage + 1 : _currentPage,
      };

      print(
        '🛍️ Fetching products: Page ${loadMore ? _currentPage + 1 : _currentPage}, Category: $_selectedCategoryId',
      );

      final response = await ApiService.post(
        '/product/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final productsList = (responseData['response'] as List)
            .map((item) => Product.fromJson(item))
            .toList();

        final pagination = responseData['pagination'];
        final hasNext = pagination['has_next'] ?? false;

        if (mounted) {
          setState(() {
            if (loadMore) {
              _products.addAll(productsList);
              _currentPage++;
              _fetchCartDetails(); // Refresh cart on paging? Maybe not strictly needed but good for sync.
            } else {
              _products = productsList;
            }
            _hasMoreProducts = hasNext;
            _isLoadingProducts = false;
            _isLoadingMoreProducts = false;
          });
        }
      } else {
        print('❌ Failed to fetch products: ${response['data']}');
        if (mounted) {
          setState(() {
            _isLoadingProducts = false;
            _isLoadingMoreProducts = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching products: $e');
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _isLoadingMoreProducts = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await _fetchStoreDetails();
    await _fetchProducts();
    await _fetchCartDetails();
  }

  Future<void> _fetchCartDetails() async {
    // Only fetch if we have valid address and store info
    if (widget.storeId.isEmpty) return;

    try {
      final requestBody = {
        "coupon_code": "",
        "store_id": widget.storeId,
        "order_method_id": "",
        "user_address_id": _userAddressId,
        "lat": _userLat,
        "lng": _userLng,
      };

      final response = await ApiService.post(
        '/auto-validate-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      // Handle response regardless of status 200 or 400, if data is present
      // The user wants to ignore status checks if data is there
      if (response['data'] != null && response['data']['response'] != null) {
        final responseData = response['data']['response'];

        setState(() {
          // Extract cart totals
          // Prioritize 'grand_total'
          if (responseData['grand_total'] != null) {
            _cartGrandTotal = (responseData['grand_total'] as num).toDouble();
          } else {
            // Fallback to iterating cart_total array if needed or default 0
            _cartGrandTotal = 0.0;
          }

          // Extract count
          if (responseData['total_products_in_cart'] != null) {
            _cartItemCount = (responseData['total_products_in_cart'] as num)
                .toInt();
          } else if (responseData['items_available'] != null) {
            _cartItemCount = (responseData['items_available'] as List).length;
          } else {
            _cartItemCount = 0;
          }

          _isCartVisible = _cartItemCount > 0;
        });
      }
    } catch (e) {
      print('❌ Error fetching cart details: $e');
      if (e is ApiException && e.response != null) {
        // Attempt to parse data from the exception response (e.g. for 400 Bad Request which still has cart data)
        final response = e.response!;
        if (response['data'] != null && response['data']['response'] != null) {
          final responseData = response['data']['response'];
          if (mounted) {
            setState(() {
              // Extract cart totals
              if (responseData['grand_total'] != null) {
                _cartGrandTotal = (responseData['grand_total'] as num)
                    .toDouble();
              } else {
                _cartGrandTotal = 0.0;
              }

              // Extract count
              if (responseData['total_products_in_cart'] != null) {
                _cartItemCount = (responseData['total_products_in_cart'] as num)
                    .toInt();
              } else if (responseData['items_available'] != null) {
                _cartItemCount =
                    (responseData['items_available'] as List).length;
              } else {
                _cartItemCount = 0;
              }

              _isCartVisible = _cartItemCount > 0;
            });
          }
        }
      }
    }
  }

  Future<void> _fetchCategories() async {
    if (widget.storeId.isEmpty) return;

    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final requestBody = {"store_id": widget.storeId};

      print('📂 Fetching categories for store: ${widget.storeId}');

      final response = await ApiService.post(
        '/get-linked-product-categories/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final categoriesList = (responseData['response'] as List)
            .map((item) => ProductCategory.fromJson(item))
            .toList();

        if (mounted) {
          setState(() {
            _categories = categoriesList;
            _isLoadingCategories = false;
          });
        }
      } else {
        print('❌ Failed to fetch categories: ${response['data']}');
        if (mounted) {
          setState(() {
            _isLoadingCategories = false;
          });
        }
      }

      // Notify whatever happened (success or partial failure handled above)
      if (mounted) {
        print('🔄 Notifying menu to update...');
        _menuUpdateNotifier.value++;
      }
    } catch (e) {
      print('❌ Error fetching categories: $e');
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
        _menuUpdateNotifier.value++;
      }
    }
  }

  void _showMenuPopup(BuildContext context) {
    if (_categories.isEmpty && !_isLoadingCategories) {
      _fetchCategories();
    }

    // Dynamic position: Button is at bottom 24 (normally) or 100 (if cart visible)
    // Align bottom edge of menu with bottom edge of button for "morph" effect
    final double buttonBottom = _isCartVisible ? 100 : 24;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (ctx, anim1, anim2) {
          return Stack(
            children: [
              // Tap anywhere to close
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

              // The Menu Content expanding from button position
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(bottom: buttonBottom, right: 16),
                  child: Hero(
                    tag: 'menu_fab',
                    createRectTween: (begin, end) {
                      return MaterialRectCenterArcTween(begin: begin, end: end);
                    },
                    child: ValueListenableBuilder<int>(
                      valueListenable: _menuUpdateNotifier,
                      builder: (context, value, child) {
                        return _buildMenuDialogContent(ctx);
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuDialogContent(BuildContext context) {
    final theme = Theme.of(context); // Define theme for usage below
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 260,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.95), // Bright whitish start
                Colors.white.withOpacity(0.85), // Slightly transparent end
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black.withOpacity(
                0.08,
              ), // Darker border as requested
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: OverflowBox(
              minWidth: 260,
              maxWidth: 260,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 260,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header for the "Table"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "CATEGORIES",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.black.withOpacity(0.05)),

                    if (!_isLoadingCategories && _categories.isNotEmpty)
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedCategoryId = null; // Clear selection = All
                            _products.clear();
                            _currentPage = 1;
                            _isSearching = false;
                            _searchController.clear();
                          });
                          _fetchProducts();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedCategoryId == null
                                ? theme.colorScheme.primary.withOpacity(0.08)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.black.withOpacity(0.03),
                              ),
                              left: _selectedCategoryId == null
                                  ? BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 3,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "All Products",
                                style: TextStyle(
                                  color: _selectedCategoryId == null
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withOpacity(
                                          0.8,
                                        ),
                                  fontSize: 14,
                                  fontWeight: _selectedCategoryId == null
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (_selectedCategoryId == null)
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),

                    if (_isLoadingCategories && _categories.isEmpty)
                      Container(
                        height: 100,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      )
                    else if (_categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "No categories",
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                                fontSize: 13,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _isLoadingCategories = true);
                                _fetchCategories();
                              },
                              child: Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_categories.length, (
                              index,
                            ) {
                              final category = _categories[index];
                              final isSelected =
                                  _selectedCategoryId == category.id;
                              final isLast = index == _categories.length - 1;

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                    _products.clear();
                                    _currentPage = 1;
                                    _isSearching = false;
                                    _searchController.clear();
                                  });
                                  _fetchProducts();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withOpacity(
                                            0.08,
                                          )
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: isLast
                                          ? BorderSide.none
                                          : BorderSide(
                                              color: Colors.black.withOpacity(
                                                0.03,
                                              ),
                                            ),
                                      left: isSelected
                                          ? BorderSide(
                                              color: theme.colorScheme.primary,
                                              width: 3,
                                            )
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          category.categoryName,
                                          style: TextStyle(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface
                                                      .withOpacity(0.8),
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: theme.colorScheme.primary,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddToCart(int index) async {
    final product = _isSearching ? _searchResults[index] : _products[index];

    try {
      final requestBody = {
        "order_by": "variation_name",
        "query": {"store_id": widget.storeId, "product_id": product.id},
      };

      print('🛒 Adding to cart: ${product.productName} (${product.id})');

      // Show loading indicator here if needed in future

      // OPTIMISTIC UPDATE: Assume success (quantity 1)
      _updateProductQuantity(index, 1);

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
          // Success: Keep optimistic update
          _fetchCartDetails(); // Refresh cart summary in bg
        } else {
          // Case B: Has variants (or other flow)
          // REVERT OPTIMISTIC UPDATE
          _updateProductQuantity(index, -1); // Back to 0

          final variants = responseData['response'];
          if (variants is List) {
            _showVariantsBottomSheet(variants, product, (addedQty) {
              // Valid update from sheet
              _updateProductQuantity(index, addedQty);
              _fetchCartDetails();
              Navigator.pop(context);
            });
          }
        }
      } else {
        // Failed
        _updateProductQuantity(index, -1); // Revert
        print('❌ Failed to add to cart: ${response['data']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Failed to add to cart')),
        );
      }
    } catch (e) {
      _updateProductQuantity(index, -1); // Revert
      print('❌ Error adding to cart: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TranslatedText('Error adding to cart')));
    }
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

  Future<void> _decrementCartItem(int index) async {
    final product = _isSearching ? _searchResults[index] : _products[index];
    if (product.quantity <= 0) return;

    // Optimistically update quantity
    // _updateProductQuantity(index, -1); // Let's wait for API response for robustness or do optimistic?
    // User asked to "call auto validate cart api", but the decrement endpoint returns cart total too?
    // Actually the logic is: - button calls /decrement-product-in-cart/
    // Response payload has cart_total etc? The sample response shows "cart_total" present.
    // So we can update everything from the response.

    try {
      final requestBody = {
        "product_combination_id":
            "", // Assuming empty if not variant specific logic known yet, or need to handle variants?
        // For simplicity using product_id as per basic flow, but if variants exist this might need more logic.
        // Given current flow for simple products:
        "product_id": product.id,
        "store_id": widget.storeId,
      };

      print('➖ Decrementing cart item: ${product.productName}');

      // OPTIMISTIC UPDATE: Decrement immediately
      _updateProductQuantity(index, -1);

      final response = await ApiService.post(
        '/decrement-product-in-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200) {
        final responseData = response['data'];
        if (responseData != null && responseData['status'] == 200) {
          // Success: Keep update
          // Update cart totals from this response
          _updateCartFromResponse(responseData);
        } else {
          // Failed logical check? Revert
          _updateProductQuantity(index, 1);
        }
      } else {
        // Network fail? Revert
        _updateProductQuantity(index, 1);
      }
    } catch (e) {
      _updateProductQuantity(index, 1); // Revert
      print('❌ Error decrementing cart item: $e');
    }
  }

  void _updateCartFromResponse(dynamic data) {
    if (data is! Map) return;

    if (mounted) {
      setState(() {
        if (data['grand_total'] != null) {
          _cartGrandTotal = (data['grand_total'] as num).toDouble();
        }
        if (data['total_products_in_cart'] != null) {
          _cartItemCount = (data['total_products_in_cart'] as num).toInt();
        }
        _isCartVisible = _cartItemCount > 0;
      });
    }
  }

  void _updateProductQuantity(int index, int delta) {
    setState(() {
      if (_isSearching) {
        if (index < _searchResults.length) {
          final currentQty = _searchResults[index].quantity;
          final newQty = (currentQty + delta).clamp(0, 99);
          _searchResults[index] = _searchResults[index].copyWith(
            quantity: newQty,
          );

          // Sync with main product list if the product exists there too
          final productId = _searchResults[index].id;
          final mainIndex = _products.indexWhere((p) => p.id == productId);
          if (mainIndex != -1) {
            _products[mainIndex] = _products[mainIndex].copyWith(
              quantity: newQty,
            );
          }
        }
      } else {
        if (index < _products.length) {
          final currentQty = _products[index].quantity;
          final newQty = (currentQty + delta).clamp(0, 99);
          _products[index] = _products[index].copyWith(quantity: newQty);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Remote settings for gradient
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientDarkStart(),
              ),
              _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientDarkEnd(),
              ),
            ]
          : [
              _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientLightStart(),
              ),
              Colors.white,
            ],
      stops: const [0.0, 1.0],
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            child: CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Custom App Bar with Store Header (35% of screen height for more impact)
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.height * 0.28,
                  toolbarHeight: 70, // Standard compact height
                  pinned: true,
                  stretch: true,
                  backgroundColor: theme.colorScheme.surface,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  leading: null,
                  actions: null,
                  titleSpacing: 0,
                  centerTitle: true,
                  title: SizedBox(
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 1. Back Button (Left) - Fades out when searching
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _isHeaderSearchActive ? 0.0 : 1.0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: _buildBackButton(
                                theme,
                                isDark,
                                isSticky: _showTitle,
                              ),
                            ),
                          ),
                        ),

                        // 2. Title (Center) - Fades out when searching
                        if (_store != null && _showTitle)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isHeaderSearchActive ? 0.0 : 1.0,
                            child: Center(
                              child: Text(
                                _store!.storeName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                        // 3. Animated Search Bar (Right -> Expands Left)
                        if (_showTitle || _isHeaderSearchActive)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutCubic,
                                width: _isHeaderSearchActive
                                    ? MediaQuery.of(context).size.width -
                                          32 // Full width minus padding
                                    : 48, // Collapsed size
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: _isHeaderSearchActive
                                          ? SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              child: Container(
                                                width:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.width -
                                                    32,
                                                child: Row(
                                                  key: const ValueKey(
                                                    'expanded',
                                                  ),
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.arrow_back,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface,
                                                        size: 20,
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          _isHeaderSearchActive =
                                                              false;
                                                          _searchController
                                                              .clear();
                                                          _isSearching = false;
                                                          _searchQuery = '';
                                                        });
                                                      },
                                                    ),
                                                    Expanded(
                                                      child:
                                                          _buildSearchBarInput(
                                                            theme,
                                                            isCompact: true,
                                                            isTransparent: true,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : IconButton(
                                              key: const ValueKey('collapsed'),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                setState(() {
                                                  _isHeaderSearchActive = true;
                                                });
                                              },
                                              icon: Icon(
                                                Icons.search_rounded,
                                                size: 24,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  shadowColor: Colors.black.withOpacity(0.5),
                  forceElevated: true,
                  flexibleSpace: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: bgGradient,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: FlexibleSpaceBar(
                        background: _isLoadingStore
                            ? _buildSkeletalStoreLoader(theme)
                            : _errorMessage != null
                            ? _buildErrorView(theme)
                            : _buildImmersiveStoreHeader(theme),
                        stretchModes: const [
                          StretchMode.zoomBackground,
                          StretchMode.blurBackground,
                        ],
                      ),
                    ),
                  ),
                ),

                // Initial Search Bar (Below the Store Header Image)
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showTitle
                        ? 0.0
                        : 1.0, // Fade out as it goes under
                    child: _buildStickySearchBar(theme),
                  ),
                ),

                // Products List or Search Results
                // Products List or Search Results (GRID VIEW)
                if (_isSearching)
                  if (_isLoadingSearchResults && _searchResults.isEmpty)
                    SliverFillRemaining(
                      child: _buildSkeletalProductsLoader(theme),
                    )
                  else if (_searchResults.isEmpty && !_isLoadingSearchResults)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 60,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              TranslatedText(
                                "No products found for '$_searchQuery'",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(
                        16,
                      ).copyWith(bottom: _isCartVisible ? 100 : 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio:
                              0.63, // Optimized aspect ratio (0.7 -> 0.63) for better fit
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index >= _searchResults.length) return null;
                          return _buildGridProductCard(
                            _searchResults[index],
                            index,
                            theme,
                          );
                        }, childCount: _searchResults.length),
                      ),
                    )
                else if (_isLoadingProducts && _products.isEmpty)
                  SliverFillRemaining(
                    child: _buildSkeletalProductsLoader(theme),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(
                      16,
                    ).copyWith(bottom: _isCartVisible ? 100 : 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio:
                            0.63, // Optimized aspect ratio (0.7 -> 0.63) for better fit
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index >= _products.length) return null;
                        return _buildGridProductCard(
                          _products[index],
                          index,
                          theme,
                        );
                      }, childCount: _products.length),
                    ),
                  ),

                // Separated Loader for Grid
                if ((_isSearching && _isLoadingMoreSearchResults) ||
                    (!_isSearching && _isLoadingMoreProducts))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),

          // Floating Cart Bar
          if (_isCartVisible)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildCartSummaryBar(theme),
            ),

          // Floating Back Button (Top Left) - REMOVED (Now in AppBar)

          // Floating Menu Button (Bottom Right - Swiggy Style)
          Positioned(
            bottom: _isCartVisible ? 130 : 24,
            right: 16,
            child: _buildMenuButton(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummaryBar(ThemeData theme) {
    // Innovative Design: "Floating Island" look
    // Using a solid, deep color for premium feel instead of the gradient
    final backgroundColor = const Color(0xFF1A1A1A);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 8),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CartScreen(
                  storeId: widget.storeId,
                  userAddressId: _userAddressId,
                  lat: _userLat,
                  lng: _userLng,
                ),
              ),
            ).then((_) {
              _fetchCartDetails();
            });
          },
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Section
                Expanded(
                  child: Row(
                    children: [
                      // Count Badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$_cartItemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Text Info
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            _cartItemCount == 1 ? 'ITEM ADDED' : 'ITEMS ADDED',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_cartGrandTotal != null)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  '₹',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _cartGrandTotal!.toStringAsFixed(0),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // View Cart Button (Pill)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TranslatedText(
                        'View Cart',
                        style: TextStyle(
                          color: Colors.black, // High contrast
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.black,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletalStoreLoader(ThemeData theme) {
    bool isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFE0E0E0);
    final highlightColor = isDark
        ? const Color(0xFF3D3D3D)
        : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1500),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner Skeleton
          Container(color: baseColor),

          // Info Overlay Skeleton
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Logo Skeleton
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Text Skeletons
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 20,
                        width: 150,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 100,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 20,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 50,
                            height: 20,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletalProductsLoader(ThemeData theme) {
    bool isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFE0E0E0);
    final highlightColor = isDark
        ? const Color(0xFF3D3D3D)
        : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1500),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Skeleton
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                // Text Skeleton
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 14,
                          width: 80,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 16,
                          width: 60,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            TranslatedText(
              _errorMessage ?? 'An error occurred',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _refreshAll, child: TranslatedText('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildImmersiveStoreHeader(ThemeData theme) {
    if (_store == null) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full Bleed Background Image with Curvy Bottom
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
          child: CustomCachedNetworkImage(
            imgUrl: _store!.storeBannerImgUrl,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.image_not_supported, size: 48),
              ),
            ),
          ),
        ),

        // 2. Heavy Gradient Overlay for Text Readability
        Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3), // Top darkening
                Colors.transparent,
                Colors.black.withOpacity(0.6), // Bottom heavy darkening
                Colors.black.withOpacity(0.95), // Seamless transition
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
        ),

        // 3. Content Content
        Positioned(
          bottom: 12, // Reduced bottom spacing
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 56, // Smaller logo
                    height: 56,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CustomCachedNetworkImage(
                        imgUrl: _store!.storeLogoImgUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_store!.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FEATURED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        TranslatedText(
                          _store!.storeName,
                          style: const TextStyle(
                            fontSize: 18, // Reduced from 20 to 18
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        TranslatedText(
                          _store!.category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ratings & Info Badges (Translucent Glass style)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_store!.averageRating > 0) ...[
                      _buildGlassInfoChip(
                        Icons.star_rounded,
                        '${_store!.averageRating.toStringAsFixed(1)} (${_store!.ratingCount})',
                        Colors.amber,
                        // theme, // No theme needed for glass style
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildGlassInfoChip(
                      Icons.timer_outlined,
                      _store!.fulfillmentSpeed,
                      Colors.white,
                    ),
                    const SizedBox(width: 8),
                    _buildGlassInfoChip(
                      Icons.location_on_outlined,
                      _store!.city,
                      Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridProductCard(Product product, int index, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = const Color(0xFF1B4B66); // Dark Blue
    final isUnavailable = product.priceStartsFrom == null;

    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Image
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: CustomCachedNetworkImage(
                imgUrl: product.imgUrl,
                fit: BoxFit.cover,
              ),
            ),
            if (product.averageRating > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 10,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        product.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Unavailable Overlay
            if (isUnavailable)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.3),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Unavailable',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // 2. Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                        color: isUnavailable
                            ? theme.colorScheme.onSurface.withOpacity(0.6)
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.childCategory.isNotEmpty
                          ? product.childCategory
                          : '1 Unit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isUnavailable)
                      Text(
                        '₹${product.priceStartsFrom!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      )
                    else
                      Text(
                        '--',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),

                    if (isUnavailable)
                      Container(
                        width: 80,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "No Stock",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      )
                    else if (product.quantity == 0)
                      _buildZeptoAddButton(
                        accentColor,
                        () => _handleAddToCart(index),
                      )
                    else
                      _buildZeptoQtyControl(
                        accentColor,
                        product.quantity,
                        index,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.05),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: isUnavailable
          ? ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.grey,
                BlendMode.saturation,
              ),
              child: Opacity(opacity: 0.7, child: cardContent),
            )
          : cardContent,
    );
  }

  Widget _buildZeptoAddButton(Color color, VoidCallback onTap) {
    return SizedBox(
      width: 76,
      child: PeelButton(
        height: 32,
        borderRadius: 8,
        onTap: onTap,
        text: "ADD",
        color: color,
        isEnabled: true,
      ),
    );
  }

  Widget _buildZeptoQtyControl(Color color, int qty, int index) {
    return Container(
      width: 76,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTinyQtyBtn(
            icon: Icons.remove,
            onTap: () => _decrementCartItem(index),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          _buildTinyQtyBtn(
            icon: Icons.add,
            onTap: () => _handleAddToCart(index),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyQtyBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  // Updated signature to accept theme
  Widget _buildGlassInfoChip(
    IconData icon,
    String text,
    Color iconColor, [
    ThemeData? theme,
  ]) {
    final effectiveTheme = theme;

    if (effectiveTheme != null) {
      // New "Clean" style
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: effectiveTheme.colorScheme.surfaceContainerHighest.withOpacity(
            0.5,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: effectiveTheme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            TranslatedText(
              text,
              style: TextStyle(
                color: effectiveTheme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                TranslatedText(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Color _hexToColor(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Widget _buildBackButton(
    ThemeData theme,
    bool isDark, {
    bool isSticky = true,
  }) {
    // If NOT sticky (on image), simpler style.
    // If sticky (on banner), glass style.

    return Container(
      width: 48,
      height: 48,
      decoration: isSticky
          ? BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                width: 1,
              ),
            )
          : BoxDecoration(
              color: Colors.black.withOpacity(
                0.2,
              ), // Subtle dark circle for contrast on image
              shape: BoxShape.circle,
              // No border
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSticky ? 16 : 24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 22,
              color: isSticky ? theme.colorScheme.onSurface : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickySearchBar(ThemeData theme) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.center,
      child: _buildSearchBarInput(theme),
    );
  }

  Widget _buildSearchBarInput(
    ThemeData theme, {
    bool isCompact = false,
    bool isTransparent = false,
  }) {
    // Determine background color based on theme brightness to ensure visibility
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isTransparent
        ? Colors.transparent
        : (isCompact
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.8)));

    final borderColor = isTransparent
        ? Colors.transparent
        : (isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            size: 22,
          ),
          SizedBox(width: isCompact ? 8 : 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search in store...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                  fontSize: isCompact ? 13 : null,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isCompact ? 13 : null,
              ),
              onChanged: (query) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  final searchQuery = query.trim();
                  if (searchQuery.length >= 3) {
                    _searchProducts(widget.storeId, searchQuery);
                  } else if (searchQuery.isEmpty) {
                    setState(() {
                      _isSearching = false;
                      _searchResults.clear();
                    });
                  }
                });
                // Avoid setState for every char unless generic state like "isSearching" changes
                _searchQuery = query;

                if (query.isEmpty && _isSearching) {
                  setState(() {
                    _isSearching = false;
                  });
                } else if (query.isNotEmpty && !_isSearching) {
                  // Optional: Set isSearching true now or wait for debounce?
                  // Usually wait for debounce to populate results, but we can allow "searching state"
                  // But let's keep it minimal to avoid rebuilds.
                }
              },
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.cancel,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    size: 22,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    // Reset search
                    setState(() {
                      _searchQuery = '';
                      _isSearching = false;
                      _searchResults.clear();
                    });
                  },
                );
              }
              return InkWell(
                onTap: () async {
                  // Open Voice Search
                  final result = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const VoiceSearchSheet(),
                  );

                  if (result != null && result is String && result.isNotEmpty) {
                    _searchController.text = result;
                    // Trigger Search
                    _searchProducts(widget.storeId, result);
                    setState(() {
                      _searchQuery = result;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(ThemeData theme, bool isDark) {
    return Hero(
      tag: 'menu_fab',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black.withOpacity(0.08), // Darker border
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showMenuPopup(context),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      color: Colors.black87, // Dark icon for visibility
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MENU',
                      style: TextStyle(
                        color: Colors.black87, // Dark text for visibility
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ), // Material
          ), // Container
        ), // BackdropFilter
      ), // ClipRRect
    ); // Hero
  }
} // End of State class
