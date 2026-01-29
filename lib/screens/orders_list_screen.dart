import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/order_details_screen.dart';
import 'package:exanor/screens/return_details_screen.dart';
import 'package:exanor/screens/order_rating_screen.dart';

import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/voice_search_sheet.dart';

class OrdersListScreen extends StatefulWidget {
  final String? storeId;

  const OrdersListScreen({super.key, this.storeId});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  // Tab State
  int _selectedTabIndex = 0; // 0: Processing, 1: Completed, 2: Others
  final List<String> _tabs = ['Processing', 'Completed', 'Others'];

  // Scroll & Data State
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _allOrders = []; // Store all fetched orders
  List<dynamic> _filteredOrders = []; // Store filtered orders
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSilentFetching =
      false; // For background auto-fetch without UI indicator
  bool _hasNextPage = false;
  int _currentPage = 1;
  String? _effectiveStoreId;
  String? _errorMessage;

  // Search State
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  // Header State
  bool _isScrolled = false;

  // Minimum number of visible items before auto-fetching more
  static const int _minVisibleItems = 6;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _init() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _effectiveStoreId = widget.storeId ?? args?['storeId'];
    _fetchOrders();
  }

  void _onScroll() {
    // Pagination Logic
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _hasNextPage) {
      _fetchOrders(isLoadMore: true);
    }

    // Header Logic
    final isScrolled =
        _scrollController.hasClients && _scrollController.offset > 10;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  Future<void> _fetchOrders({
    bool isLoadMore = false,
    bool silent = false,
  }) async {
    // Prevent concurrent fetches
    if (silent && _isSilentFetching) return;

    if (isLoadMore && !silent) {
      setState(() => _isLoadingMore = true);
    } else if (!isLoadMore) {
      setState(() => _isLoading = true);
    } else if (silent) {
      _isSilentFetching = true;
    }

    try {
      final requestBody = {
        "query": {},
        "page": isLoadMore ? _currentPage + 1 : 1,
      };

      final result = await ApiService.post(
        '/orders/',
        body: requestBody,
        useBearerToken: true,
      );

      if (result['data'] != null && result['data']['status'] == 200) {
        final data = result['data'];
        final List<dynamic> newOrders = data['response'] ?? [];
        final pagination = data['pagination'];

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _allOrders.addAll(newOrders);
              _currentPage++;
            } else {
              _allOrders = newOrders;
              _currentPage = 1;
            }

            _applyFilter(); // Update visible list

            if (pagination != null) {
              _hasNextPage = pagination['has_next'] ?? false;
            } else {
              _hasNextPage = false;
            }

            _isLoading = false;
            _isLoadingMore = false;
            _isSilentFetching = false;
            _errorMessage = null;
          });

          // Auto-fetch more if filtered list is too small and more pages exist
          // This ensures users can always scroll to trigger more loads
          _checkAndFetchMoreIfNeeded();
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to load orders');
      }
    } catch (e) {
      print('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          if (!isLoadMore) {
            _errorMessage = e.toString();
            _isLoading = false;
          }
          _isLoadingMore = false;
          _isSilentFetching = false;
        });
      }
    }
  }

  /// Checks if the current filtered list has too few items and fetches more if possible.
  /// This solves the issue where the server sends a page of orders but only a few
  /// match the current filter (e.g., "Completed" tab), leaving the user unable to scroll.
  void _checkAndFetchMoreIfNeeded() {
    // Only auto-fetch if:
    // 1. We have more pages available
    // 2. Current filtered list is smaller than threshold
    // 3. We're not already loading (including silent fetches)
    if (_hasNextPage &&
        _filteredOrders.length < _minVisibleItems &&
        !_isLoadingMore &&
        !_isLoading &&
        !_isSilentFetching) {
      // Small delay to prevent rapid-fire requests
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted &&
            _hasNextPage &&
            _filteredOrders.length < _minVisibleItems &&
            !_isSilentFetching) {
          // Use silent: true to avoid showing loading indicator
          _fetchOrders(isLoadMore: true, silent: true);
        }
      });
    }
  }

  void _applyFilter() {
    setState(() {
      if (_allOrders.isEmpty) {
        _filteredOrders = [];
        return;
      }

      final query = _searchController.text.toLowerCase();

      _filteredOrders = _allOrders.where((order) {
        // Status Filter
        final status = (order['status'] ?? '').toString().toLowerCase();
        bool statusMatch = false;
        switch (_selectedTabIndex) {
          case 0: // Processing - includes partially_paid and any in-progress statuses
            statusMatch =
                status == 'partially_paid' ||
                status == 'order_partially_paid' ||
                status == 'processing' ||
                status == 'pending' ||
                status == 'confirmed' ||
                status == 'preparing' ||
                status == 'ready' ||
                status == 'shipped' ||
                status == 'out_for_delivery' ||
                (status != 'order_completed' &&
                    status != 'delivered' &&
                    status != 'order_cancelled' &&
                    status != 'fully_cancelled' &&
                    status != 'cancelled' &&
                    status != 'partially_returned' &&
                    status != 'order_partially_returned' &&
                    status != 'order_returned');
            break;
          case 1: // Completed - only completed orders
            statusMatch = status == 'order_completed' || status == 'delivered';
            break;
          case 2: // Others - includes order_partially_returned, fully_cancelled and other cancelled statuses
            statusMatch =
                status == 'partially_returned' ||
                status == 'order_partially_returned' ||
                status == 'fully_cancelled' ||
                status == 'order_cancelled' ||
                status == 'cancelled' ||
                status == 'order_returned';
            break;
        }

        // Search Filter
        bool searchMatch = true;
        if (query.isNotEmpty) {
          final id = (order['id'] ?? '').toString().toLowerCase();
          final products = (order['product_names'] ?? '')
              .toString()
              .toLowerCase();
          final store = (order['store_name'] ?? '').toString().toLowerCase();
          searchMatch =
              id.contains(query) ||
              products.contains(query) ||
              store.contains(query);
        }

        return statusMatch && searchMatch;
      }).toList();
    });
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
      _applyFilter();
    });
    // After switching tabs, check if we need to fetch more for this filter
    _checkAndFetchMoreIfNeeded();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'order_placed':
      case 'processing':
        return Colors.blue;
      case 'order_confirmed':
        return Colors.orange;
      case 'order_preparing':
        return Colors.amber;
      case 'order_ready':
      case 'out_for_delivery':
        return Colors.cyan;
      case 'order_completed':
      case 'delivered':
        return Colors.green;
      case 'order_cancelled':
        return Colors.red;
      case 'order_returned':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0.00';
    return '₹${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? '0.00'}';
  }

  void _showRatingDialog(dynamic order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderRatingScreen(
          orderId: order['id']?.toString() ?? '',
          storeName: order['store_name'],
        ),
      ),
    ).then((result) {
      if (result != null) {
        if (result is Map) {
          if (result['action'] == 'auto_rate_products' ||
              result['action'] == 'rate_products') {
            final double rating = result['rating'] is double
                ? result['rating']
                : double.tryParse(result['rating'].toString()) ?? 5.0;
            final String review = result['review'] ?? '';

            // Rate products automatically
            _rateAllProducts(order, rating, review);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order rated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _fetchOrders(); // Refresh to update UI
          } else if (result['rating'] != null) {
            _fetchOrders();
          }
        } else if (result is double) {
          _fetchOrders();
        }
      }
    });
  }

  Future<void> _rateAllProducts(
    dynamic order,
    double rating,
    String review,
  ) async {
    final List items = order['product_details'] as List? ?? [];
    if (items.isEmpty) return;

    for (var item in items) {
      // Check if already rated to avoid overwrite/errors if backend enforces it
      if (item['is_rated'] == true) continue;

      try {
        await ApiService.post(
          '/review-product/',
          body: {
            "order_id": order['id'],
            "product_id": item['id'] ?? item['product_combination_id'],
            "rating": rating,
            "review":
                review, // Same review for all? Or empty? User said "just give the rating to veryt= prodt"
          },
          useBearerToken: true,
        );
      } catch (e) {
        debugPrint(
          "Failed to auto-rate product ${item['id']}: $e",
        ); // Silent fail
      }
    }
    // Refresh again after products are rated to show their status if needed
    if (mounted) _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define gradient locally to use in the scrollable header part
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
      stops: const [0.0, 1.0], // Extended to bottom of container
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: () async {
          _init();
          await _fetchOrders();
        },
        child: Stack(
          children: [
            // 1. Scrollable Content
            _isLoading
                ? _buildShimmerList(theme, bgGradient)
                : _buildOrderList(theme, isDark, bgGradient),

            // 2. Fixed Header (Pinned at top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: false,
                child: _buildHeader(theme, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(ThemeData theme, bool isDark, Gradient bgGradient) {
    // Header = StatusBar + TopBar(60) + Tabs(60) + Padding
    final topPadding = MediaQuery.of(context).padding.top;
    const headerContentHeight = 130.0;
    final totalHeaderHeight = topPadding + headerContentHeight;

    if (_filteredOrders.isEmpty) {
      return ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: totalHeaderHeight + 20),
          SizedBox(
            height:
                MediaQuery.of(context).size.height -
                (totalHeaderHeight + 20 + 50), // 50 for bottom nav/padding
            child: _allOrders.isNotEmpty
                ? _buildEmptyFilterState(theme)
                : _buildEmptyState(theme),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
      padding: EdgeInsets.only(top: totalHeaderHeight + 10, bottom: 30),
      itemCount: _filteredOrders.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        if (index == _filteredOrders.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildPremiumOrderCard(theme, _filteredOrders[index], isDark),
        );
      },
    );
  }

  Widget _buildPremiumOrderCard(ThemeData theme, dynamic order, bool isDark) {
    final status = order['status'] ?? 'Unknown';
    final isDelivered =
        status.toLowerCase() == 'order_completed' ||
        status.toLowerCase() == 'delivered';
    final isProcessing =
        !isDelivered &&
        !status.toLowerCase().contains('cancelled') &&
        !status.toLowerCase().contains('returned');

    // Store Info
    final storeName = order['store_name'] ?? 'Store Name';
    // Use store image if available, else fallback to first product image or icon
    final storeImage =
        order['store_image'] ??
        (order['product_details'] != null &&
                (order['product_details'] as List).isNotEmpty
            ? order['product_details'][0]['image_url']
            : null);

    // Items
    // Items: Try structured details first, fallback to parsing names string
    var items = [];
    if (order['product_details'] != null &&
        (order['product_details'] as List).isNotEmpty) {
      items = order['product_details'] as List;
    } else if (order['product_names'] != null) {
      // Fallback: Create items from comma-separated names string
      // This ensures we always show WHAT was ordered
      final names = order['product_names'].toString().split(',');
      items = names
          .where((n) => n.trim().isNotEmpty)
          .map(
            (name) => {
              'product_name': name.trim(),
              'quantity': 1, // Default assumption when detail is missing
              'image_url': null,
            },
          )
          .toList();
    }

    // Date & Total
    final timestamp = order['timestamp'] ?? order['created_at'];
    String date = 'Date Unknown';
    if (timestamp != null) {
      try {
        final DateTime parsed = DateTime.parse(timestamp.toString());
        date = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
      } catch (e) {
        date = timestamp.toString();
      }
    }
    final total = _formatCurrency(order['grand_total']);

    // Colors
    final cardBg = theme.cardColor;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Ambient Shadow (Soft, large spread)
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          // Key Shadow (Sharper, defines edge)
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
        // Removed border to avoid "whitish" outline; shadow provides definition now
      ),
      child: Column(
        children: [
          // 1. Header: Store Image + Name + Status
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Image (Large Square)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceContainerHighest,
                    image: storeImage != null
                        ? DecorationImage(
                            image: NetworkImage(storeImage),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: storeImage == null
                      ? Icon(
                          Icons.store_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                // Store Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 4.0,
                    ), // Push down slightly
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order['store_address'] ?? 'Location',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // Status Badge (Top Right)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      isDelivered ? 'COMPLETED' : status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _getStatusColor(status),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDashedLine(theme),
          ),

          // 2. Items List
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  ...items.take(3).map<Widget>((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          // Custom bullet point style
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.dividerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${item['quantity'] ?? 1} x ${item['product_name'] ?? item['name']}",
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 18),
                      child: Text(
                        "+ ${items.length - 3} more items",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDashedLine(theme),
          ),

          // 3. Ratings removed as per user request

          // 4. Footer: Date, Total, and Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Column (Date & Total)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Action Buttons
                if (isDelivered)
                  Row(
                    children: [
                      // Valid Details Button
                      SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () {
                            // Navigate to details (reusing OrderDetailsScreen which shows completed state)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderDetailsScreen(
                                  orderId: order['id'],
                                  storeId:
                                      order['store_id'] ??
                                      _effectiveStoreId ??
                                      '',
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.dividerColor),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "Details",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Rate Button or Rating Display
                      if (order['is_rated'] == true) ...[
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A), // Premium Dark
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // Rectangular
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${order['rating'] ?? 0}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () => _showRatingDialog(order),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Rate",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  // Processing / Other Status Button
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        if (status.toLowerCase().contains('returned')) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReturnDetailsScreen(
                                orderId: order['id'],
                                storeId:
                                    order['store_id'] ??
                                    _effectiveStoreId ??
                                    '',
                              ),
                            ),
                          );
                        } else {
                          // Track Order
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailsScreen(
                                orderId: order['id'],
                                storeId:
                                    order['store_id'] ??
                                    _effectiveStoreId ??
                                    '',
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        status.toLowerCase().contains('returned')
                            ? "View Return"
                            : "Track Order",
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildDashedLine(ThemeData theme) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 6.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.1), // Dimmer
                ),
              ),
            );
          }),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            "No Orders Yet",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 60, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            "No ${_tabs[_selectedTabIndex]} Orders",
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList(ThemeData theme, Gradient bgGradient) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    const headerContentHeight = 130.0;
    final totalHeaderHeight = topPadding + headerContentHeight;

    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.separated(
      padding: EdgeInsets.only(top: totalHeaderHeight + 10, bottom: 30),
      itemCount: 5,
      separatorBuilder: (_, index) => const SizedBox(height: 20),
      itemBuilder: (_, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              // Matching the premium card shadows
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
            // Removed border for consistency
          ),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Store Image + Name + Status
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Image
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Store Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              width: 140,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 90,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        width: 70,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: theme.dividerColor.withOpacity(0.2),
                    height: 1,
                  ),
                ),

                // 2. Items List Shimmer
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 10,
                                margin: const EdgeInsets.only(right: 60),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: theme.dividerColor.withOpacity(0.2),
                    height: 1,
                  ),
                ),

                // 3. Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Info Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 70,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 50,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      // Buttons - Dynamic based on tab
                      if (_selectedTabIndex == 1) // Completed -> 2 Buttons
                        Row(
                          children: [
                            Container(
                              width: 70,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 70,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        )
                      else // Processing/Cancelled -> 1 Button
                        Container(
                          width: 110,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;

    // Animate opacity/blur based on scroll
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: 0.0, end: _isScrolled ? 1.0 : 0.0),
      builder: (context, value, child) {
        final double blurSigma = value * 15.0;
        // Gradient is always visible (0.95) and becomes slightly more opaque when scrolled (1.0)
        final double opacity = 0.95 + (value * 0.05);

        // Calculate Light Mode Colors to match HomeScreen logic (Immersive Light)
        final lightStartBase = _hexToColor(
          FirebaseRemoteConfigService.getThemeGradientLightStart(),
        );
        final lightModeStart = Color.alphaBlend(
          lightStartBase.withOpacity(0.35),
          Colors.white,
        );
        const lightModeEnd = Colors.white;

        final startColor = isDark
            ? _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientDarkStart(),
              )
            : lightModeStart;
        final endColor = isDark
            ? _hexToColor(FirebaseRemoteConfigService.getThemeGradientDarkEnd())
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
                    : Colors.black.withOpacity(0.1),
                blurRadius: 25,
                offset: const Offset(0, 12),
                spreadRadius: -5,
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
                  height:
                      topPadding +
                      130, // Fixed height for pinned header including tabs
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        startColor.withOpacity(opacity),
                        endColor.withOpacity(opacity),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20), // Subtler curve
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withOpacity(value * 0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Bar
                        SizedBox(
                          height: 60,
                          child: Stack(
                            children: [
                              // Center Title
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _isSearchExpanded ? 0.0 : 1.0,
                                child: Center(
                                  child: TranslatedText(
                                    "My Orders",
                                    style: TextStyle(
                                      fontSize: 24, // Increased size
                                      fontWeight: FontWeight.w900, // Extra Bold
                                      color: theme.colorScheme.onSurface,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ),

                              // Left Back Button (Hidden when search expanded)
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _isSearchExpanded ? 0.0 : 1.0,
                                child: IgnorePointer(
                                  ignoring: _isSearchExpanded,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 20),
                                      child: _buildBackButton(theme, isDark),
                                    ),
                                  ),
                                ),
                              ),

                              // Right Search
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: _buildSearchButton(theme, isDark),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tabs
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSlidingTabs(theme, isDark),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedSearchBar(ThemeData theme) {
    return Container(
      key: const ValueKey('expanded'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 40,
                maxWidth: MediaQuery.of(context).size.width - 40,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = false;
                        _searchController.clear();
                        _applyFilter();
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search orders...",
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: theme.hintColor.withOpacity(0.6),
                        ),
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                      ),
                      onChanged: (val) => _applyFilter(),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final result = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const VoiceSearchSheet(),
                      );
                      if (result != null && result.isNotEmpty) {
                        _searchController.text = result;
                        _applyFilter();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _hexToColor(String hex, {Color defaultColor = Colors.transparent}) {
    try {
      String cleanHex = hex
          .trim()
          .toUpperCase()
          .replaceAll('#', '')
          .replaceAll('0X', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse('0x$cleanHex'));
    } catch (e) {
      return defaultColor;
    }
  }

  Widget _buildBackButton(ThemeData theme, bool isDark) {
    return Container(
      width: 48, // Increased size
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16), // Squircle
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
              size: 22, // Increased icon size
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton(ThemeData theme, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _isSearchExpanded
          ? MediaQuery.of(context).size.width - 40
          : 48, // Increased collapsed size
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16), // Squircle
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isSearchExpanded
                ? _buildExpandedSearchBar(theme)
                : IconButton(
                    key: const ValueKey('collapsed'),
                    icon: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.onSurface,
                      size: 26,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = true;
                      });
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingTabs(ThemeData theme, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.white.withOpacity(0.3), // More visible glass effect
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.5),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / _tabs.length;
          return Stack(
            children: [
              // Sliding Pills Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves
                    .easeInOutCubic, // Smooth transition without overshoot
                left: _selectedTabIndex * tabWidth,
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

              // Tab Text
              Row(
                children: List.generate(_tabs.length, (index) {
                  final isSelected = _selectedTabIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onTabSelected(index),
                      child: Container(
                        color: Colors.transparent, // Hit test
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
                          child: TranslatedText(_tabs[index]),
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
}
