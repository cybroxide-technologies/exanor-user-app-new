import 'dart:async';
import 'dart:ui' as ui;
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/models/store_model.dart';
import 'package:exanor/models/product_model.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/screens/cart_screen.dart';
import 'package:exanor/components/product_variant_sheet.dart';
import 'package:exanor/components/voice_search_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAddressAndFetchStore();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
      // Trigger early (after scrolling just 50px) so banner content appears immediately
      final showTitleThreshold = 50.0;

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
      final requestBody = {
        "store_id": widget.storeId,
        "query": {},
        "page": loadMore ? _currentPage + 1 : _currentPage,
      };

      print(
        '🛍️ Fetching products: Page ${loadMore ? _currentPage + 1 : _currentPage}',
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

  Future<void> _handleAddToCart(int index) async {
    final product = _isSearching ? _searchResults[index] : _products[index];

    try {
      final requestBody = {
        "order_by": "variation_name",
        "query": {"store_id": widget.storeId, "product_id": product.id},
      };

      print('🛒 Adding to cart: ${product.productName} (${product.id})');

      // Show loading indicator here if needed in future

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
          // Case A: Added successfully (No variants)
          // Update quantity to 1
          _updateProductQuantity(index, 1);
          _fetchCartDetails(); // Refresh cart summary
        } else {
          // Case B: Has variants
          final variants = responseData['response'];
          if (variants is List) {
            _showVariantsBottomSheet(variants, product, (addedQty) {
              // Update local quantity on success
              _updateProductQuantity(index, addedQty);
              _fetchCartDetails(); // Refresh cart summary
              Navigator.pop(context); // Close sheet
            });
          }
        }
      } else {
        print('❌ Failed to add to cart: ${response['data']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Failed to add to cart')),
        );
      }
    } catch (e) {
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

      final response = await ApiService.post(
        '/decrement-product-in-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200) {
        final responseData = response['data'];
        if (responseData != null && responseData['status'] == 200) {
          // Success
          _updateProductQuantity(index, -1); // Update local state count

          // Update cart totals from this response
          _updateCartFromResponse(responseData); // Pass the whole data object
        }
      }
    } catch (e) {
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
                  expandedHeight: MediaQuery.of(context).size.height * 0.35,
                  toolbarHeight: 150,
                  pinned: true,
                  stretch: true,
                  backgroundColor: theme.colorScheme.surface,
                  elevation: 0,
                  automaticallyImplyLeading:
                      false, // Handle back button manually via Stack
                  titleSpacing: 0,
                  title: _store != null && _showTitle
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 8,
                            ), // Top padding to align with back button
                            // Centered store name
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 60,
                              ), // Space for back button
                              child: Text(
                                _store!.storeName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Centered compact search bar
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: SizedBox(
                                height: 50,
                                child: _buildSearchBarInput(
                                  theme,
                                  isCompact: true,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ), // Bottom padding to extend banner
                          ],
                        )
                      : null,
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
                              0.55, // Taller to prevent overflow (0.58 -> 0.55)
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
                            0.55, // Taller to prevent overflow (0.58 -> 0.55)
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

          // Floating Back Button (Top Left) - Matches Order List Screen exactly
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            left: 16,
            child: _buildBackButton(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummaryBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatedText(
                '$_cartItemCount item${_cartItemCount != 1 ? 's' : ''} added',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_cartGrandTotal != null)
                TranslatedText(
                  '₹${_cartGrandTotal!.toStringAsFixed(2)}', // Total directly from API
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          InkWell(
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
                // Refresh state when returning from cart
                _fetchCartDetails();
                // Optionally refresh products if quantities changed
                // _fetchProducts();
              });
            },
            child: Row(
              children: [
                TranslatedText(
                  'View cart',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_right, color: Colors.white, size: 20),
              ],
            ),
          ),
        ],
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
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Logo Card
                  Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CustomCachedNetworkImage(
                        imgUrl: _store!.storeLogoImgUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title & Chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_store!.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FEATURED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        TranslatedText(
                          _store!.storeName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        TranslatedText(
                          _store!.category,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Image
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
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
                      if (product.priceStartsFrom != null)
                        Text(
                          '₹${product.priceStartsFrom!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        )
                      else
                        Text('N/A', style: theme.textTheme.bodySmall),

                      product.quantity == 0
                          ? _buildZeptoAddButton(
                              accentColor,
                              () => _handleAddToCart(index),
                            )
                          : _buildZeptoQtyControl(
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
      ),
    );
  }

  Widget _buildZeptoAddButton(Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 80, // Fixed width pill
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white, // White background
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            "ADD",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZeptoQtyControl(Color color, int qty, int index) {
    return Container(
      width: 80,
      height: 32, // Match ADD button height
      decoration: BoxDecoration(
        color: color, // Solid color for qty
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InkWell(
            onTap: () => _decrementCartItem(index),
            child: const Icon(Icons.remove, color: Colors.white, size: 16),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          InkWell(
            onTap: () => _handleAddToCart(index),
            child: const Icon(Icons.add, color: Colors.white, size: 16),
          ),
        ],
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

  Widget _buildBackButton(ThemeData theme, bool isDark) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: theme.colorScheme.onSurface,
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

  Widget _buildSearchBarInput(ThemeData theme, {bool isCompact = false}) {
    // Determine background color based on theme brightness to ensure visibility
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isCompact
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
        : (isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.white.withOpacity(0.8));

    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);

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
                setState(() {
                  _searchQuery = query;
                  if (query.isEmpty) {
                    _isSearching = false;
                  }
                });
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
} // End of State class
