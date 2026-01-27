import 'dart:async';
import 'dart:ui' as ui;

import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/screens/saved_addresses_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exanor/models/store_model.dart';
import 'package:exanor/models/product_model.dart';

import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/components/product_variant_sheet.dart';
import 'package:exanor/components/ticket_painter.dart'; // Added
import 'package:exanor/screens/order_details_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/peel_button.dart';
import 'package:exanor/components/swipe_to_pay_button.dart';

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
  final ScrollController _suggestionsScrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Infinite Scroll State
  int _suggestionPage = 1;
  bool _hasMoreSuggestions = true;
  bool _isFetchingMoreSuggestions = false;

  // Payment Methods State
  List<dynamic> _paymentMethods = [];
  Map<String, dynamic>? _selectedPaymentMethod;
  bool _isLoadingPaymentMethods = false;

  // Order Initialization State
  bool _isOrderPlaceable = false;
  bool _isInitializingOrder = false;
  String _orderInitMessage = "";

  // Coupons State
  List<Coupon> _storeCoupons = [];
  bool _isLoadingCoupons = false;
  String? _selectedCouponCode;

  // Countdown Timer State
  bool _isCountingDown = false;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;

  // Location Data
  String? _addressTitle;
  String? _addressSubtitle;
  late String _currentAddressId;
  late double _currentLat;
  late double _currentLng;

  // Scroll State
  bool _isScrolled = false;

  // Inline Payment Selector State
  bool _isPaymentSelectorOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _currentAddressId = widget.userAddressId;
    _currentLat = widget.lat.toDouble();
    _currentLng = widget.lng.toDouble();

    // Log initial values for debugging
    print("🚀 CartScreen initState:");
    print("   Address ID: $_currentAddressId");
    print("   Lat/Lng: $_currentLat, $_currentLng");
    print("   Store ID: ${widget.storeId}");

    // Check if lat/lng are invalid (null or 0) and navigate to address selection if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndNavigateToAddressSelection();
    });

    _initializeCartScreen();
  }

  Future<void> _checkAndNavigateToAddressSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLat = prefs.getDouble('latitude');
      final savedLng = prefs.getDouble('longitude');

      // Check if coordinates are invalid (0 or null)
      final bool hasInvalidCoordinates =
          (_currentLat == 0.0 || _currentLng == 0.0) &&
          (savedLat == null ||
              savedLng == null ||
              savedLat == 0.0 ||
              savedLng == 0.0);

      if (hasInvalidCoordinates) {
        print(
          "⚠️ CartScreen: Invalid coordinates detected, opening SavedAddressesScreen",
        );

        if (!mounted) return;

        // Navigate to SavedAddressesScreen
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (context) => const SavedAddressesScreen()),
        );

        // If user selected an address, update the cart with new coordinates
        if (result != null && result['addressSelected'] == true && mounted) {
          print("✅ CartScreen: Address selected, updating cart data");

          // Reload address details from SharedPreferences
          await _updateLocationFromPrefs();

          // Refresh cart data with new coordinates
          await _fetchCartData(forceLoading: true);

          // Re-initialize order with new address
          await _initializeOrder();
        } else if (result == null && mounted) {
          // User dismissed without selecting - show warning
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a delivery address to continue'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Error checking address: $e");
    }
  }

  Future<void> _loadAddressDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _addressTitle =
              prefs.getString('address_title') ?? "Selected Location";
          _addressSubtitle = prefs.getString('address_subtitle') ?? "";

          // If lat/lng are 0 (invalid), try to load from SharedPreferences
          if (_currentLat == 0.0 || _currentLng == 0.0) {
            final savedLat = prefs.getDouble('latitude');
            final savedLng = prefs.getDouble('longitude');
            final savedAddressId = prefs.getString('saved_address_id');

            if (savedLat != null &&
                savedLng != null &&
                savedAddressId != null) {
              print(
                "⚠️ Widget lat/lng were 0.0, loading from SharedPreferences:",
              );
              print("   Saved Lat/Lng: $savedLat, $savedLng");
              print("   Saved Address ID: $savedAddressId");

              _currentLat = savedLat;
              _currentLng = savedLng;
              _currentAddressId = savedAddressId;
            } else {
              print("❌ ERROR: No valid coordinates available!");
              print("   Widget lat/lng: ${widget.lat}, ${widget.lng}");
              print("   SharedPreferences lat/lng: $savedLat, $savedLng");
            }
          }
        });
      }
    } catch (e) {
      print("Error loading address details: $e");
    }
  }

  Future<void> _updateLocationFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('saved_address_id');
      final lat = prefs.getDouble('latitude');
      final lng = prefs.getDouble('longitude');

      if (id != null && lat != null && lng != null) {
        if (mounted) {
          setState(() {
            _currentAddressId = id;
            _currentLat = lat;
            _currentLng = lng;
          });
          await _loadAddressDetails();
        }
      }
    } catch (e) {
      print("Error updating location from prefs: $e");
    }
  }

  Future<void> _initializeCartScreen() async {
    // Fetch order methods and payment methods FIRST
    await Future.wait([
      _fetchOrderMethods(),
      _fetchPaymentMethods(),
      _loadAddressDetails(),
      _fetchStoreCoupons(),
    ]);

    // Then fetch cart data
    await _fetchCartData();

    // Finally initialize order validation and fetch suggestions
    if (mounted) {
      _fetchProductSuggestions();
      _initializeOrder();
    }
  }

  Future<void> _initializeOrder() async {
    // Comprehensive validation of all required fields
    if (_selectedPaymentMethod == null ||
        _selectedOrderMethodId == null ||
        _currentAddressId.isEmpty) {
      print("⚠️ Cannot initialize order - missing required data:");
      print(
        "   Payment Method: ${_selectedPaymentMethod != null ? 'Set' : 'Missing'}",
      );
      print("   Order Method ID: ${_selectedOrderMethodId ?? 'Missing'}");
      print(
        "   Address ID: ${_currentAddressId.isEmpty ? 'Missing/Empty' : _currentAddressId}",
      );

      if (mounted) {
        setState(() {
          _isOrderPlaceable = false;
          _orderInitMessage = "Please select Order Method and Address";
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializingOrder = true;
      });
    }

    try {
      final requestBody = {
        "coupon_code": _selectedCouponCode ?? "",
        "lat": _currentLat,
        "lng": _currentLng,
        "order_method_id": _selectedOrderMethodId,
        "payment_method_id": _selectedPaymentMethod!['id'],
        "store_id": widget.storeId,
        "user_address_id": _currentAddressId,
      };

      print("🛒 Initializing Order with:");
      print("   Coupon: taco1");
      print("   Lat/Lng: $_currentLat, $_currentLng");
      print("   Order Method ID: $_selectedOrderMethodId");
      print("   Payment Method ID: ${_selectedPaymentMethod!['id']}");
      print("   Store ID: ${widget.storeId}");
      print("   Address ID: $_currentAddressId");

      final response = await ApiService.post(
        '/order-init/',
        body: requestBody,
        useBearerToken: true,
      );

      if (mounted) {
        if (response['data'] != null && response['data']['status'] == 200) {
          final respData = response['data']['response'];
          final message = respData['message'];

          final isOk = message == "All OK." || message == "ALL OK";

          setState(() {
            _isOrderPlaceable = isOk;
            _orderInitMessage = respData['message_for_user'] ?? "";

            // Optionally update cart data from this response as it contains fresh pricing/availability
            // _cartData = respData;
            // Using specific fields might be safer to avoid overwriting UI state not present in this response

            _isInitializingOrder = false;
          });

          print("✅ Order initialization successful - Order placeable: $isOk");
        } else {
          // Handle 400 or other error statuses
          final respData = response['data']?['response'];
          final errorMessage =
              respData?['message_for_user'] ??
              respData?['message'] ??
              "Unable to initialize order";

          print(
            "❌ Order initialization failed: ${response['data']?['status']}",
          );
          print("   Message: $errorMessage");

          setState(() {
            _isOrderPlaceable = false;
            _orderInitMessage = errorMessage;
            _isInitializingOrder = false;
          });
        }
      }
    } catch (e) {
      print("❌ Error initializing order: $e");
      if (mounted) {
        setState(() {
          _isOrderPlaceable = false;
          _orderInitMessage = "Unable to validate order";
          _isInitializingOrder = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _suggestionsScrollController.dispose();
    _countdownTimer?.cancel();
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
        "coupon_code": _selectedCouponCode ?? "",
        "store_id": widget.storeId,
        "order_method_id": _selectedOrderMethodId ?? "",
        "user_address_id": _currentAddressId,
        "lat": _currentLat,
        "lng": _currentLng,
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

  Future<void> _fetchProductSuggestions({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (!_hasMoreSuggestions || _isFetchingMoreSuggestions) return;
      setState(() {
        _isFetchingMoreSuggestions = true;
      });
    } else {
      _suggestionPage = 1;
      _hasMoreSuggestions = true;
      if (mounted) setState(() => _isLoadingSuggestions = true);
    }

    try {
      final requestBody = {
        "store_id": widget.storeId,
        "query": {},
        "page": _suggestionPage,
      };

      final response = await ApiService.post(
        '/product/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final rawList = response['data']['response'] as List? ?? [];
        final list = rawList.map((e) => Product.fromJson(e)).toList();

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              // Append to list using animated list insert could be tricky for bulk,
              // but normal list append works if we update the model list.
              // For AnimatedList, we need to insert items one by one or rebuild.
              // Since simple infinite scroll, let's just insert them.
              final startindex = _suggestedProducts.length;
              _suggestedProducts.addAll(list);
              for (int i = 0; i < list.length; i++) {
                _listKey.currentState?.insertItem(startindex + i);
              }
            } else {
              _suggestedProducts = list; // Reset
              // Ideally we should tell AnimatedList to reset, but since page 1 reloads typically on refresh/init
              // _listKey = GlobalKey? no can't change key easily.
              // Assuming init state handles initial build.
              // If refreshing, we might need to clear and re-add?
              // For simplicity in this context, just updating list for refresh is okay if widget rebuilds.
              // But AnimatedList holds state.
            }

            _hasMoreSuggestions = list.isNotEmpty;
            if (_hasMoreSuggestions) _suggestionPage++;

            _isLoadingSuggestions = false;
            _isFetchingMoreSuggestions = false;

            // Filter new batch
            _filterSuggestions(animate: false);
          });
        }
      } else {
        if (mounted) setState(() => _isFetchingMoreSuggestions = false);
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      if (mounted)
        setState(() {
          _isLoadingSuggestions = false;
          _isFetchingMoreSuggestions = false;
        });
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

  Future<void> _fetchPaymentMethods() async {
    setState(() => _isLoadingPaymentMethods = true);
    try {
      final requestBody = {
        "store_id": widget.storeId,
        "query": {},
        "order_by": "payment_method_template_id",
        "view": true,
      };

      final response = await ApiService.post(
        '/payment-method/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final list = response['data']['response'] as List? ?? [];
        if (mounted) {
          setState(() {
            _paymentMethods = list;
            // Default select first enabled one
            if (_selectedPaymentMethod == null && _paymentMethods.isNotEmpty) {
              _selectedPaymentMethod = _paymentMethods.firstWhere(
                (m) => m['is_enabled'] == true,
                orElse: () => _paymentMethods.first,
              );
            }
            _isLoadingPaymentMethods = false;

            // Re-initialize order as payment method might have changed (or set to default)
            _initializeOrder();
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingPaymentMethods = false);
      }
    } catch (e) {
      print("Error fetching payment methods: $e");
      if (mounted) setState(() => _isLoadingPaymentMethods = false);
    }
  }

  Future<void> _fetchStoreCoupons() async {
    if (mounted) setState(() => _isLoadingCoupons = true);
    try {
      // Use get-stores to fetch store details including coupons
      // Since we have storeId, we can filter by it or just use the same call as StoreScreen
      // However, /get-stores/ usually returns a list. We need to find our store.
      // StoreScreen uses: user_address_id, store_id, page=1.

      // Wait for address to be loaded if possible, otherwise use widget.userAddressId
      final addressId = _currentAddressId.isNotEmpty
          ? _currentAddressId
          : widget.userAddressId;

      final requestBody = {
        "user_address_id": addressId,
        "store_id": widget.storeId,
        "page": 1,
      };

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

        if (storesList.isNotEmpty) {
          final store = storesList.first;
          if (mounted) {
            setState(() {
              _storeCoupons = store.coupons;
              _isLoadingCoupons = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingCoupons = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingCoupons = false);
      }
    } catch (e) {
      print("Error fetching coupons: $e");
      if (mounted) setState(() => _isLoadingCoupons = false);
    }
  }

  // Removed duplicate declaration

  void _showPaymentMethodSelector() {
    setState(() {
      _isPaymentSelectorOpen = !_isPaymentSelectorOpen;
    });
  }

  Future<void> _placeOrderImmediate() async {
    // Validate all required parameters
    if (_selectedPaymentMethod == null ||
        _selectedOrderMethodId == null ||
        _currentAddressId.isEmpty) {
      print("⚠️ Cannot place order - missing required data");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText(
            'Please ensure all order details are selected',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        setState(() {
          _isInitializingOrder = true;
        });
      }

      final requestBody = {
        "coupon_code": _selectedCouponCode ?? "",
        "lat": _currentLat,
        "lng": _currentLng,
        "order_method_id": _selectedOrderMethodId,
        "payment_method_id": _selectedPaymentMethod!['id'],
        "store_id": widget.storeId,
        "user_address_id": _currentAddressId,
      };

      print("📦 Placing Order with:");
      print("   Coupon Code: (empty)");
      print("   Lat/Lng: $_currentLat, $_currentLng");
      print("   Order Method ID: $_selectedOrderMethodId");
      print("   Payment Method ID: ${_selectedPaymentMethod!['id']}");
      print("   Store ID: ${widget.storeId}");
      print("   Address ID: $_currentAddressId");

      final response = await ApiService.post(
        '/place-order/',
        body: requestBody,
        useBearerToken: true,
      );

      if (mounted) {
        setState(() {
          _isInitializingOrder = false;
        });

        if (response['data'] != null && response['data']['status'] == 200) {
          print("✅ Order placed successfully!");

          // Extract order_id from the response
          final responseData = response['data']['response'];
          final executeOrderData = responseData?['execute_order_data'];
          final orderId = executeOrderData?['order_id'];

          print("📋 Response data: $responseData");
          print("📋 Execute order data: $executeOrderData");
          print("🆔 Extracted order_id: $orderId");

          if (orderId != null) {
            print("🚀 Navigating to OrderDetailsScreen with orderId: $orderId");
            // Navigate to Order Details Screen
            if (mounted) {
              // Add small delay to ensure bottom sheet is fully closed
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsScreen(
                      orderId: orderId,
                      storeId: widget.storeId,
                    ),
                  ),
                );
              }
            }
          } else {
            print("⚠️ orderId is null, showing snackbar instead");
            // Fallback if order_id is not found
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: TranslatedText('Order placed successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          // Handle error
          final errorMessage =
              response['data']?['response']?['message'] ??
              response['data']?['message'] ??
              'Failed to place order';

          print("❌ Order placement failed: $errorMessage");

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Error placing order: $e");

      if (mounted) {
        setState(() {
          _isInitializingOrder = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error placing order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startOrderCountdown() {
    // Validate all required parameters
    if (_selectedPaymentMethod == null ||
        _selectedOrderMethodId == null ||
        _currentAddressId.isEmpty) {
      print("⚠️ Cannot place order - missing required data");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText(
            'Please ensure all order details are selected',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show beautiful bottom sheet instead of inline countdown
    _showOrderCountdownBottomSheet();
  }

  void _showOrderCountdownBottomSheet() {
    final theme = Theme.of(context);

    // Start countdown
    setState(() {
      _isCountingDown = true;
      _countdownSeconds = 5;
    });

    // Store the modal state setter to update bottom sheet
    late StateSetter modalStateSetter;

    // Create periodic timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownSeconds--;
      });

      // IMPORTANT: Also update the bottom sheet UI
      try {
        modalStateSetter(() {
          // This triggers rebuild of the bottom sheet content
        });
      } catch (e) {
        // Bottom sheet might be closed
      }

      if (_countdownSeconds <= 0) {
        timer.cancel();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Close bottom sheet only
        }
        _placeOrderImmediate();
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button dismiss
        child: StatefulBuilder(
          builder: (context, setModalState) {
            // Capture the state setter for use in timer
            modalStateSetter = setModalState;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withOpacity(0.95),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Animated circular progress
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow effect
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.3 * value,
                                  ),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Progress circle
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: _countdownSeconds / 5,
                              strokeWidth: 12,
                              backgroundColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          // Center content
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Animated countdown number
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: TranslatedText(
                                  '$_countdownSeconds',
                                  key: ValueKey<int>(_countdownSeconds),
                                  style: TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TranslatedText(
                                'seconds',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Title and description
                  TranslatedText(
                    'Placing Your Order',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TranslatedText(
                    'Your order will be placed automatically',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Order summary card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          theme,
                          Icons.shopping_bag_outlined,
                          'Items',
                          '${_cartData?['total_products_in_cart'] ?? 0}',
                        ),
                        const Divider(height: 16),
                        _buildSummaryRow(
                          theme,
                          Icons.payments_outlined,
                          'Total',
                          '₹${(_cartData?['grand_total'] ?? 0.0).toStringAsFixed(2)}',
                        ),
                        const Divider(height: 16),
                        _buildSummaryRow(
                          theme,
                          Icons.payment_rounded,
                          'Payment',
                          _selectedPaymentMethod?['payment_method_name'] ??
                              'N/A',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _cancelOrderCountdown,
                      icon: const Icon(Icons.close_rounded),
                      label: const TranslatedText('Cancel Order'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).then((_) {
      // Cleanup when bottom sheet is dismissed (don't call _cancelOrderCountdown to avoid double pop)
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _isCountingDown = false;
          _countdownSeconds = 5;
        });
      }
    });
  }

  Widget _buildSummaryRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        TranslatedText(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const Spacer(),
        TranslatedText(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _cancelOrderCountdown() {
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _isCountingDown = false;
        _countdownSeconds = 5;
      });
      // Close bottom sheet ONLY - don't pop the cart screen
      Navigator.of(context, rootNavigator: false).pop();
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

  void _showCouponsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // 1. Artistic Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange[300]!, Colors.red[300]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_activity_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                "Unlock Exclusive Savings",
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              TranslatedText(
                                "Tap a ticket to claim your offer",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Coupons List
              Expanded(
                child: _storeCoupons.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.confirmation_number_outlined,
                              size: 64,
                              color: theme.disabledColor.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            TranslatedText(
                              "No coupons available yet",
                              style: TextStyle(
                                color: theme.disabledColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _storeCoupons.length,
                        itemBuilder: (context, index) {
                          final coupon = _storeCoupons[index];
                          final isSelected =
                              _selectedCouponCode == coupon.couponCode;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildArtisticCouponTicket(
                              context,
                              coupon,
                              isSelected,
                              theme,
                              isDark,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtisticCouponTicket(
    BuildContext context,
    dynamic coupon,
    bool isSelected,
    ThemeData theme,
    bool isDark,
  ) {
    // Ticket Colors
    final bgColor = theme.cardColor;
    final accentColor = isSelected ? Colors.green : theme.colorScheme.primary;
    final borderColor = isSelected
        ? Colors.green
        : theme.dividerColor.withOpacity(0.6);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCouponCode = coupon.couponCode;
        });
        Navigator.pop(context);
        _fetchCartData(forceLoading: true);
        _initializeOrder();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Coupon "${coupon.couponCode}" applied!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 110,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Precise split calculation used by painter
            final double splitX = constraints.maxWidth * (2 / 3);

            return CustomPaint(
              painter: TicketPainter(
                color: bgColor,
                borderColor: borderColor,
                borderWidth: isSelected ? 2.0 : 1.0,
                holeRadius: 10,
                cornerRadius: 16,
                splitX: splitX,
              ),
              child: Row(
                children: [
                  // LEFT SIDE (Info)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        16,
                        24,
                        16,
                      ), // Extra right padding for dash clearance
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    coupon.couponCode.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: accentColor,
                                      letterSpacing: 1.0,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.green,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          TranslatedText(
                            coupon.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              height: 1.3,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // RIGHT SIDE (Action)
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        12,
                        12,
                        12,
                      ), // Extra left padding for dash clearance
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TranslatedText(
                            "Save up to",
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.disabledColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "₹${coupon.minimumAmount}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isSelected ? "APPLIED" : "APPLY",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.green
                                  : theme.colorScheme.primary,
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
      ),
    );
  }

  Color _hexToColor(String? hex, {Color? defaultColor}) {
    if (hex == null || hex.isEmpty) {
      return defaultColor ?? Colors.transparent;
    }
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return defaultColor ?? Colors.transparent;
    }
  }

  Widget _buildBackButton(ThemeData theme, bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 22,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  void _onScroll() {
    final isScrolled =
        _scrollController.hasClients && _scrollController.offset > 10;
    if (isScrolled != _isScrolled) {
      setState(() => _isScrolled = isScrolled);
    }
  }

  Widget _buildSlidingTabs(ThemeData theme, bool isDark) {
    if (_orderMethods.isEmpty) return const SizedBox();

    int selectedIndex = 0;
    for (int i = 0; i < _orderMethods.length; i++) {
      if (_orderMethods[i]['id'] == _selectedOrderMethodId) {
        selectedIndex = i;
        break;
      }
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.5),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 0) return const SizedBox();
          final tabWidth = constraints.maxWidth / _orderMethods.length;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                left: selectedIndex * tabWidth,
                top: 4,
                bottom: 4,
                width: tabWidth,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(_orderMethods.length, (index) {
                  final method = _orderMethods[index];
                  final isSelected = selectedIndex == index;
                  final title =
                      method['order_method_name'] ??
                      method['title'] ??
                      method['name'] ??
                      'Method';
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (method['id'] != _selectedOrderMethodId) {
                          setState(() {
                            _selectedOrderMethodId = method['id'];
                          });
                          _fetchCartData(forceLoading: true);
                          // Re-initialize to validate for new method
                          _initializeOrder();
                        }
                      },
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13,
                          ),
                          child: TranslatedText(title),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    final totalHeaderHeight = topPadding + 130;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween<double>(begin: 0.0, end: _isScrolled ? 1.0 : 0.0),
      builder: (context, value, child) {
        final double blurSigma = value * 15.0;
        final double opacity = 0.95 + (value * 0.05);

        // Calculate Light Mode Colors to match HomeScreen logic (Immersive Light)
        final lightStartBase = _hexToColor(
          FirebaseRemoteConfigService.getThemeGradientLightStart(),
        );
        final lightModeStart = Color.alphaBlend(
          lightStartBase.withOpacity(0.35),
          Colors.white,
        );
        final lightModeEnd = Colors.white;

        final startColor = isDark
            ? _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientDarkStart(),
                defaultColor: const Color(0xFF1A1A1A),
              )
            : lightModeStart;
        final endColor = isDark
            ? _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientDarkEnd(),
                defaultColor: Colors.black,
              )
            : lightModeEnd;

        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.black.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: Container(
                  height: totalHeaderHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        startColor.withOpacity(opacity),
                        endColor.withOpacity(opacity),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withOpacity(value * 0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Watermark Background Icon
                      Positioned(
                        right: -40,
                        top: 40,
                        child: Transform.rotate(
                          angle: -0.2,
                          child: Opacity(
                            opacity: 0.05,
                            child: Icon(
                              Icons.shopping_cart_rounded,
                              size: 150,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),

                      SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 60,
                              child: Stack(
                                children: [
                                  Center(
                                    child: TranslatedText(
                                      "My Cart",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.onSurface,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 20),
                                      child: _buildBackButton(theme, isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: _buildSlidingTabs(theme, isDark),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading && _cartData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: _buildSkeletonLoader(),
      );
    }

    if (_cartData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: TranslatedText('Failed to load cart')),
      );
    }

    final items = _cartData!['items_available'] as List? ?? [];

    double totalSavings = 0.0;
    try {
      if (_cartData!['cart_total'] != null) {
        for (var e in (_cartData!['cart_total'] as List)) {
          if ((e['value'] as num) < 0) totalSavings += (e['value'] as num);
        }
      }
      if (_cartData!['platform_fees'] != null) {
        for (var e in (_cartData!['platform_fees'] as List)) {
          if ((e['value'] as num) < 0) totalSavings += (e['value'] as num);
        }
      }
    } catch (e) {
      debugPrint('Error calculating savings: $e');
    }

    // Premium Gradient from Firebase Remote Config
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientDarkStart(),
                defaultColor: const Color(0xFF1A1A1A),
              ),
              _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientDarkEnd(),
                defaultColor: Colors.black,
              ),
            ]
          : [
              _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientLightStart(),
                defaultColor: const Color(0xFFE3F2FD),
              ),
              Colors.white,
            ],
    );

    final topPadding = MediaQuery.of(context).padding.top;
    final headerTotalHeight = topPadding + 130;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main Content
          RefreshIndicator(
            onRefresh: () async {
              await Future.wait([_fetchCartData(), _fetchProductSuggestions()]);
            },
            edgeOffset: headerTotalHeight + 10,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Spacer for fixed header
                SliverToBoxAdapter(
                  child: SizedBox(height: headerTotalHeight + 10),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (_isLoading && _cartData != null)
                        const LinearProgressIndicator(minHeight: 2),

                      // Cart Items List (Big Main Card)
                      if (items.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.3 : 0.08,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.1 : 0.05,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Modern Title with Accent
                                    Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TranslatedText(
                                          "Order Summary",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.onSurface,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Innovative Pill Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.15),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.shopping_basket_rounded,
                                            size: 12,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          TranslatedText(
                                            "${items.length} Items",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: theme.dividerColor.withOpacity(0.3),
                              ),

                              // Items
                              ...items.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                final isLast = index == items.length - 1;
                                return _buildCartItemContent(
                                  item,
                                  theme,
                                  isLast: isLast,
                                );
                              }),

                              // Aesthetic "Add More" Footer
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  border: Border(
                                    top: BorderSide(
                                      color: theme.dividerColor.withOpacity(
                                        0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(24),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(24),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 20,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.add,
                                                size: 16,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            TranslatedText(
                                              "Add more items",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 12,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Add method to show coupon sheet
                      // Placement here is invalid, it must be outside build or inside _showCouponsBottomSheet definition

                      // Continuing inside Column children...
                      /* ... */

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
                            const SizedBox(height: 16), // Reduced spacing
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: TranslatedText(
                                "You might love to try this",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 230, // Compact height
                              child: NotificationListener<ScrollNotification>(
                                onNotification:
                                    (ScrollNotification scrollInfo) {
                                      if (!_isFetchingMoreSuggestions &&
                                          _hasMoreSuggestions &&
                                          scrollInfo.metrics.pixels >=
                                              scrollInfo
                                                      .metrics
                                                      .maxScrollExtent -
                                                  200) {
                                        _fetchProductSuggestions(
                                          isLoadMore: true,
                                        );
                                      }
                                      return false;
                                    },
                                child: AnimatedList(
                                  key: _listKey,
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  initialItemCount:
                                      _suggestedProducts.length +
                                      (_hasMoreSuggestions ? 1 : 0),
                                  itemBuilder: (context, index, animation) {
                                    if (index >= _suggestedProducts.length) {
                                      // Loader at end
                                      if (_hasMoreSuggestions) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      } else {
                                        return const SizedBox.shrink();
                                      }
                                    }

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
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // Coupons Section (God Tier Revamp)
                      if (!_isLoadingCoupons && _storeCoupons.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 76,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _selectedCouponCode != null
                                      ? Colors.green.withOpacity(0.2)
                                      : theme.colorScheme.primary.withOpacity(
                                          0.15,
                                        ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showCouponsBottomSheet,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  // The "Card"
                                  padding: const EdgeInsets.all(
                                    2,
                                  ), // Border width
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: _selectedCouponCode != null
                                        ? LinearGradient(
                                            colors: [
                                              Colors.green[400]!,
                                              Colors.green[700]!,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary,
                                              theme.colorScheme.tertiary,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _selectedCouponCode != null
                                          ? Colors
                                                .green[50] // Light green surface for applied
                                          : theme.cardColor,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Artistic Abstract Blobs
                                        if (_selectedCouponCode == null) ...[
                                          Positioned(
                                            top: -20,
                                            right: -20,
                                            child: Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.05),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: -30,
                                            right: 30,
                                            child: Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: theme
                                                    .colorScheme
                                                    .secondary
                                                    .withOpacity(0.05),
                                              ),
                                            ),
                                          ),
                                        ],

                                        // Content
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: Row(
                                            children: [
                                              // 1. Premium Icon
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      _selectedCouponCode !=
                                                          null
                                                      ? const LinearGradient(
                                                          colors: [
                                                            Color(0xFF43A047),
                                                            Color(0xFF2E7D32),
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        )
                                                      : LinearGradient(
                                                          colors: [
                                                            theme
                                                                .colorScheme
                                                                .primary
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                            theme
                                                                .colorScheme
                                                                .primary
                                                                .withOpacity(
                                                                  0.2,
                                                                ),
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _selectedCouponCode != null
                                                      ? Icons.verified_rounded
                                                      : Icons.percent_rounded,
                                                  color:
                                                      _selectedCouponCode !=
                                                          null
                                                      ? Colors.white
                                                      : theme
                                                            .colorScheme
                                                            .primary,
                                                  size: 24,
                                                ),
                                              ),

                                              const SizedBox(width: 14),

                                              // 2. Texts
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    TranslatedText(
                                                      _selectedCouponCode !=
                                                              null
                                                          ? "Code Applied!"
                                                          : "Apply Coupon",
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            _selectedCouponCode !=
                                                                null
                                                            ? Colors.green[800]
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                        letterSpacing: -0.2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    if (_selectedCouponCode !=
                                                        null)
                                                      Row(
                                                        children: [
                                                          Text(
                                                            _selectedCouponCode!,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              color: Colors
                                                                  .green[700],
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Icon(
                                                            Icons.check_circle,
                                                            size: 10,
                                                            color: Colors
                                                                .green[700],
                                                          ),
                                                        ],
                                                      )
                                                    else
                                                      TranslatedText(
                                                        "Save more on this order",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface
                                                              .withOpacity(0.5),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),

                                              // 3. Action Button
                                              if (_selectedCouponCode != null)
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedCouponCode =
                                                          null;
                                                    });
                                                    _fetchCartData(
                                                      forceLoading: true,
                                                    );
                                                    _initializeOrder();
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.red
                                                            .withOpacity(0.2),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const TranslatedText(
                                                          "REMOVE",
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        const Icon(
                                                          Icons.close,
                                                          size: 12,
                                                          color: Colors.red,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              else
                                                Row(
                                                  children: [
                                                    TranslatedText(
                                                      "View",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons
                                                          .arrow_forward_ios_rounded,
                                                      size: 12,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Location Details Card
                      if (_addressTitle != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TranslatedText(
                              "Your Address",
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.3 : 0.08,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.1 : 0.05,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TranslatedText(
                                      _addressTitle!,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (_addressSubtitle?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 4),
                                      TranslatedText(
                                        _addressSubtitle!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withOpacity(0.7),
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final result =
                                      await Navigator.push<
                                        Map<String, dynamic>
                                      >(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SavedAddressesScreen(),
                                        ),
                                      );

                                  if (result != null &&
                                      result['addressSelected'] == true) {
                                    await _updateLocationFromPrefs();
                                    await _fetchCartData(forceLoading: true);
                                    _initializeOrder();
                                  }
                                },
                                child: const TranslatedText("Change"),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Bill Details (Premium Design)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.08,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.1 : 0.05,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                16,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TranslatedText(
                                    "Payment Summary",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Divider(
                              height: 1,
                              color: theme.dividerColor.withOpacity(0.2),
                            ),

                            // Items
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // Cart Total Items
                                  ...(_cartData!['cart_total'] as List).map<
                                    Widget
                                  >((e) {
                                    final val = (e['value'] as num);
                                    if (val == 0)
                                      return const SizedBox.shrink();
                                    final isDiscount = val < 0;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TranslatedText(
                                            e['title'],
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.6),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          TranslatedText(
                                            '₹${val.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: isDiscount
                                                  ? Colors.green[700]
                                                  : theme.colorScheme.onSurface,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),

                                  // Platform Fees
                                  if (_cartData!['platform_fees'] != null)
                                    ...(_cartData!['platform_fees'] as List)
                                        .map<Widget>((e) {
                                          final val = (e['value'] as num);
                                          if (val == 0 &&
                                              !(e['title']
                                                  .toString()
                                                  .toLowerCase()
                                                  .contains('coupon'))) {
                                            return const SizedBox.shrink();
                                          }
                                          final isDiscount = val < 0;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                TranslatedText(
                                                  e['title'],
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.6),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                TranslatedText(
                                                  '₹${val.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: isDiscount
                                                        ? Colors.green[700]
                                                        : theme
                                                              .colorScheme
                                                              .onSurface,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        })
                                        .toList(),

                                  const SizedBox(height: 16),
                                  // Dashed Line
                                  CustomPaint(
                                    size: const Size(double.infinity, 1),
                                    painter: DashedLinePainter(
                                      color: theme.dividerColor.withOpacity(
                                        0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Grand Total
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TranslatedText(
                                        "Grand Total",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      TranslatedText(
                                        '₹${(_cartData!['grand_total'] as num).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.primary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Total Savings
                                  if (totalSavings < 0) ...[
                                    const SizedBox(height: 20),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF4CAF50,
                                            ).withOpacity(0.1),
                                            const Color(
                                              0xFF81C784,
                                            ).withOpacity(0.05),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF4CAF50,
                                          ).withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.stars_rounded,
                                            color: Colors.green[700],
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TranslatedText(
                                              "You saved ₹${totalSavings.abs().toStringAsFixed(2)} on this order!",
                                              style: TextStyle(
                                                color: Colors.green[800],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
                                const TranslatedText(
                                  "Refund Policy",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TranslatedText(
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
              ],
            ),
          ),

          // Fixed Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(theme, isDark),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor, // Use card color for bottom bar
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Inline Payment Selector
              if (_selectedPaymentMethod != null)
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutQuart, // Smooth, no bounce
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20.0),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isPaymentSelectorOpen
                            ? theme.colorScheme.primary.withOpacity(0.2)
                            : theme.dividerColor.withOpacity(0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header / Toggle Row
                        InkWell(
                          onTap: _showPaymentMethodSelector,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const TranslatedText(
                                  "Pay using",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isPaymentSelectorOpen
                                      ? const SizedBox.shrink()
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_selectedPaymentMethod!['img_url'] !=
                                                null)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 8.0,
                                                ),
                                                width: 24,
                                                height: 24,
                                                child: Image.network(
                                                  _selectedPaymentMethod!['img_url'],
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (c, e, s) =>
                                                      const Icon(
                                                        Icons.payment,
                                                        size: 20,
                                                        color: Colors.grey,
                                                      ),
                                                ),
                                              ),
                                            TranslatedText(
                                              _selectedPaymentMethod!['payment_method_name'] ??
                                                  '',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedRotation(
                                  duration: const Duration(milliseconds: 300),
                                  turns: _isPaymentSelectorOpen ? 0.5 : 0,
                                  child: Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    size: 24,
                                    color: _isPaymentSelectorOpen
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                              .withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expanded Content (The List)
                        if (_isPaymentSelectorOpen) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Divider(
                              height: 1,
                              color: theme.dividerColor.withOpacity(0.3),
                            ),
                          ),
                          if (_isLoadingPaymentMethods)
                            const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: _paymentMethods.map((method) {
                                    final isSelected =
                                        _selectedPaymentMethod?['id'] ==
                                        method['id'];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedPaymentMethod = method;
                                              _isPaymentSelectorOpen = false;
                                            });
                                            _initializeOrder();
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? theme.colorScheme.primary
                                                        .withOpacity(0.04)
                                                  : theme
                                                        .scaffoldBackgroundColor
                                                        .withOpacity(0.5),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : theme.dividerColor
                                                          .withOpacity(0.5),
                                                width: isSelected ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: theme.cardColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: theme.dividerColor
                                                          .withOpacity(0.2),
                                                    ),
                                                  ),
                                                  child:
                                                      method['img_url'] != null
                                                      ? Image.network(
                                                          method['img_url'],
                                                          fit: BoxFit.contain,
                                                          errorBuilder:
                                                              (c, e, s) => Icon(
                                                                Icons.payment,
                                                                size: 18,
                                                                color: theme
                                                                    .disabledColor,
                                                              ),
                                                        )
                                                      : Icon(
                                                          Icons.payment,
                                                          size: 18,
                                                          color: theme
                                                              .disabledColor,
                                                        ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      TranslatedText(
                                                        method['payment_method_name'] ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                      ),
                                                      if (isSelected)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                top: 2,
                                                              ),
                                                          child: TranslatedText(
                                                            "Tap to close",
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: theme
                                                                  .colorScheme
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isSelected
                                                        ? theme
                                                              .colorScheme
                                                              .primary
                                                        : Colors.transparent,
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : theme.disabledColor
                                                                .withOpacity(
                                                                  0.5,
                                                                ),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: isSelected
                                                      ? const Icon(
                                                          Icons.check,
                                                          size: 12,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Total and Action Button
              if (_selectedOrderMethodId == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.disabledColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: theme.disabledColor.withOpacity(0.2),
                    ),
                  ),
                  child: Center(
                    child: TranslatedText(
                      "Select Order Method",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.disabledColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_orderInitMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TranslatedText(
                          _orderInitMessage,
                          style: TextStyle(
                            color: _isOrderPlaceable
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: SwipeToPayButton(
                        onSwipeCompleted: _startOrderCountdown,
                        text:
                            (_selectedPaymentMethod != null &&
                                (_selectedPaymentMethod!['payment_method_name'] ??
                                        '')
                                    .toString()
                                    .toLowerCase()
                                    .contains('pay on delivery'))
                            ? 'Swipe to place order'
                            : 'Swipe to pay',
                        amount:
                            (_selectedPaymentMethod != null &&
                                (_selectedPaymentMethod!['payment_method_name'] ??
                                        '')
                                    .toString()
                                    .toLowerCase()
                                    .contains('pay on delivery'))
                            ? null
                            : '₹${((_cartData!['grand_total'] ?? 0) as num).toStringAsFixed(2)}',
                        isLoading: _isInitializingOrder || _isCountingDown,
                        isEnabled:
                            _isOrderPlaceable &&
                            !_isInitializingOrder &&
                            !_isCountingDown,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemContent(
    Map<String, dynamic> item,
    ThemeData theme, {
    bool isLast = false,
  }) {
    final pricing = item['pricing_details'];
    final unitPrice = pricing != null
        ? (pricing['selling_amount_including_tax'] as num? ?? 0.0)
        : 0.0;
    final qty = item['enquired_quantity'] as int? ?? 1;

    // Use item_total if available, else fallback to unit * qty
    final displayPrice = (pricing != null && pricing['item_total'] != null)
        ? (pricing['item_total'] as num? ?? 0.0)
        : (unitPrice * qty);

    final imageUrl = item['img_url'] as String? ?? '';
    final variantName = item['variant_name'] as String? ?? '';
    final productName = item['product_name'] ?? 'Unknown';

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isLast ? null : theme.dividerColor.withOpacity(0.0),
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.4),
                  width: 0.5,
                ),
              ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.6),
                width: 0.5,
              ),
              color: isDark ? Colors.grey[800] : Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: imageUrl.isNotEmpty
                  ? CustomCachedNetworkImage(
                      imgUrl: imageUrl,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      Icons.image_not_supported_outlined,
                      size: 24,
                      color: theme.disabledColor,
                    ),
            ),
          ),

          const SizedBox(width: 14),

          // 2. Info Grid (Quadrant Layout)
          Expanded(
            child: Column(
              children: [
                // Top Row: Name vs Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TranslatedText(
                        productName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TranslatedText(
                      '₹${displayPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Bottom Row: Variant vs Counter
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: variantName.isNotEmpty
                          ? TranslatedText(
                              variantName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const SizedBox(),
                    ),
                    Container(
                      height: 30, // Compact height
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSymmetricalButton(
                            theme,
                            Icons.remove,
                            () =>
                                _updatingItemIds.contains(
                                  item['product_combination_id'] ?? item['id'],
                                )
                                ? null
                                : _decrementCartItem(item),
                          ),
                          Container(
                            width: 24,
                            alignment: Alignment.center,
                            child:
                                _updatingItemIds.contains(
                                  item['product_combination_id'] ?? item['id'],
                                )
                                ? Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : TranslatedText(
                                    '$qty',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                          ),
                          _buildSymmetricalButton(
                            theme,
                            Icons.add,
                            () =>
                                _updatingItemIds.contains(
                                  item['product_combination_id'] ?? item['id'],
                                )
                                ? null
                                : _incrementCartItem(item),
                          ),
                        ],
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

  Widget _buildSymmetricalButton(
    ThemeData theme,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: onTap == null
                ? theme.disabledColor.withOpacity(0.3)
                : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(
    Product product,
    ThemeData theme, {
    VoidCallback? onTapAdd,
    bool isRemoving = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 150, // Smaller, compacted width
      margin: const EdgeInsets.only(right: 16, bottom: 8, top: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isRemoving
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Placeholder for navigation
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image Area (Compact)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: CustomCachedNetworkImage(
                  imgUrl: product.imgUrl,
                  height: 110, // Reduced height for squarish look
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Dotted Line Separator
              CustomPaint(
                size: const Size(double.infinity, 1),
                painter: DashedLinePainter(
                  color: theme.dividerColor.withOpacity(0.3),
                  dashWidth: 4,
                  dashSpace: 3,
                ),
              ),

              // 3. Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title
                      TranslatedText(
                        product.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.1,
                        ),
                      ),

                      // Footer: Price & ADD Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Price
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: TranslatedText(
                              '₹${product.priceStartsFrom?.toStringAsFixed(0) ?? "0"}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),

                          // ADD Button (Compact)
                          SizedBox(
                            width: 74,
                            child: PeelButton(
                              height: 28,
                              borderRadius: 8,
                              onTap: onTapAdd,
                              text: "ADD",
                              color: theme.colorScheme.primary,
                              isEnabled: true,
                            ),
                          ),
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

  Future<bool> _showRemoveConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const TranslatedText('Remove Item?'),
            content: const TranslatedText(
              'Are you sure you want to remove this item from your cart?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const TranslatedText(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const TranslatedText(
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
    // Determine theme brightness for base colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFE0E0E0);
    final highlightColor = isDark
        ? const Color(0xFF3D3D3D)
        : const Color(0xFFF5F5F5);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 140, // Match header offset
        left: 16,
        right: 16,
        bottom: 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Order Summary Skeleton (MOVED TO TOP)
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 140,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: 70,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

                // Items List (Simulate 3 items)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Column(
                      children: List.generate(
                        3,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            children: [
                              // Item Image
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 80,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Price
                              Container(
                                width: 50,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 120,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 2. Suggestions Skeleton
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 200,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      return Container(
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Coupon Skeleton
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Address Card Skeleton (MOVED FROM TOP)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 200,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 5. Bill Details Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 150,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Bill Rows
                  ...List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 100,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white),
                  const SizedBox(height: 20),
                  // Grand Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 100,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
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
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedLinePainter({
    required this.color,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
