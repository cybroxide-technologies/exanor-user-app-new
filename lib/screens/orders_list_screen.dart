import 'dart:ui' as ui;
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/order_details_screen.dart';
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
  int _selectedTabIndex = 0; // 0: Processing, 1: Delivered, 2: Cancelled
  final List<String> _tabs = ['Processing', 'Delivered', 'Cancelled'];

  // Scroll & Data State
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _allOrders = []; // Store all fetched orders
  List<dynamic> _filteredOrders = []; // Store filtered orders
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  String? _effectiveStoreId;
  String? _errorMessage;

  // Search State
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  // Header State
  bool _isScrolled = false;

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

  Future<void> _fetchOrders({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
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
            _errorMessage = null;
          });
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
        });
      }
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
                 status != 'order_returned');
            break;
          case 1: // Delivered - only completed orders
            statusMatch = status == 'order_completed' || status == 'delivered';
            break;
          case 2: // Cancelled - includes partially_returned, fully_cancelled and other cancelled statuses
            statusMatch =
                status == 'partially_returned' ||
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

  String _formatStatusLabel(String status, String statusTitle) {
    final lowerStatus = status.toLowerCase();
    
    // Special formatting for specific statuses
    if (lowerStatus == 'partially_paid') {
      return 'PARTIAL PAYMENT';
    } else if (lowerStatus == 'partially_returned') {
      return 'PARTIAL RETURN';
    } else if (lowerStatus == 'fully_cancelled') {
      return 'CANCELLED';
    } else if (lowerStatus == 'order_completed') {
      return 'COMPLETED';
    } else if (lowerStatus == 'out_for_delivery') {
      return 'OUT FOR DELIVERY';
    }
    
    return statusTitle.toUpperCase();
  }

  void _showRatingDialog(dynamic order) {
    int rating = 0;
    final TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            const Color(0xFF1E293B),
                            const Color(0xFF0F172A),
                          ]
                        : [
                            Colors.white,
                            const Color(0xFFF8FAFC),
                          ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 60,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Rate Your Experience',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order #${order['id']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 40,
                              color: index < rating
                                  ? Colors.amber
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write your review (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.1),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: rating > 0
                                ? () {
                                    // TODO: Submit rating to backend
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Thank you for rating! $rating stars',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text(
                              'Submit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    final headerContentHeight = 130.0;
    final totalHeaderHeight = topPadding + headerContentHeight;

    if (_filteredOrders.isEmpty) {
      return ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: totalHeaderHeight + 20),
          if (_allOrders.isNotEmpty)
            _buildEmptyFilterState(theme)
          else
            _buildEmptyState(theme),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
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
    final statusTitle = order['order_status_title'] ?? status;
    final isDelivered =
        status.toLowerCase() == 'order_completed' ||
        status.toLowerCase() == 'delivered';

    String? imageUrl;
    if (order['product_details'] != null &&
        (order['product_details'] as List).isNotEmpty) {
      imageUrl = order['product_details'][0]['image_url'];
    }

    // Da Vinci Button: Glass + Gradient + Gloss Overlay
    Widget buildArtisticButton({
      required VoidCallback onTap,
      required String label,
      required IconData icon,
      required List<Color> baseColors,
      required Color glowColor,
    }) {
      return Container(
        height: 52, // Slightly more compact
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14), // Reduced curve
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // 1. Base Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: baseColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // 2. Glass Overlay
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.0),
                        Colors.black.withOpacity(0.05),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // 3. Inner Border
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              // 4. Content
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: Colors.white.withOpacity(0.2),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20), // Reduced from 32
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.5)
                : const Color(0xFF2C3E50).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Upper Visuals
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Window
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16), // Reduced from 24
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: imageUrl == null
                    ? Icon(
                        Icons.restaurant_menu_rounded,
                        color: theme.colorScheme.onSurface.withOpacity(0.15),
                        size: 36,
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Typographic Details - Symmetric Layout
              Expanded(
                child: SizedBox(
                  height: 88, // Match image height for symmetry
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween, // Pin top/bottom
                    children: [
                      // Product Name (Top)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          order['product_names'] ?? 'Gourmet Order',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600, // Reduced from w800
                            fontSize: 17,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Price & Status (Bottom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Text(
                              _formatCurrency(order['grand_total']),
                              style: TextStyle(
                                fontFamily:
                                    theme.textTheme.bodyLarge?.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: () {
                                  final isDark =
                                      Theme.of(context).brightness ==
                                      Brightness.dark;
                                  final hexColor = isDark
                                      ? FirebaseRemoteConfigService.getThemeGradientDarkStart()
                                      : FirebaseRemoteConfigService.getThemeGradientLightStart();
                                  final baseColor = _hexToColor(hexColor);
                                  return _lightenColor(baseColor, 0.15);
                                }(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: () {
                                    final isDark = Theme.of(context).brightness == Brightness.dark;
                                    final hexColor = isDark
                                        ? FirebaseRemoteConfigService.getThemeGradientDarkStart()
                                        : FirebaseRemoteConfigService.getThemeGradientLightStart();
                                    final baseColor = _hexToColor(hexColor);
                                    return baseColor.withOpacity(0.15);
                                  }(),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: () {
                                      final isDark = Theme.of(context).brightness == Brightness.dark;
                                      final hexColor = isDark
                                          ? FirebaseRemoteConfigService.getThemeGradientDarkStart()
                                          : FirebaseRemoteConfigService.getThemeGradientLightStart();
                                      return _hexToColor(hexColor).withOpacity(0.3);
                                    }(),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _formatStatusLabel(status, statusTitle),
                                  style: TextStyle(
                                    color: () {
                                      final isDark = Theme.of(context).brightness == Brightness.dark;
                                      final hexColor = isDark
                                          ? FirebaseRemoteConfigService.getThemeGradientDarkStart()
                                          : FirebaseRemoteConfigService.getThemeGradientLightStart();
                                      return _hexToColor(hexColor);
                                    }(),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action Button
          if (isDelivered)
            buildArtisticButton(
              onTap: () {
                _showRatingDialog(order);
              },
              label: "Rate Experience",
              icon: Icons.star_rate_rounded,
              baseColors: [
                _hexToColor(
                  FirebaseRemoteConfigService.getRateExperienceButtonColor(),
                  defaultColor: const Color(0xFFFF8C00),
                ),
                _lightenColor(
                  _hexToColor(
                    FirebaseRemoteConfigService.getRateExperienceButtonColor(),
                    defaultColor: const Color(0xFFFF8C00),
                  ),
                  0.1,
                ),
              ],
              glowColor: _hexToColor(
                FirebaseRemoteConfigService.getRateExperienceButtonColor(),
                defaultColor: const Color(0xFFFF8C00),
              ),
            )
          else
            buildArtisticButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsScreen(
                      orderId: order['id'],
                      storeId: order['store_id'] ?? _effectiveStoreId ?? '',
                    ),
                  ),
                );
              },
              label: "Track Live Order",
              icon: Icons.near_me_rounded,
              baseColors: [
                () {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final hexColor = isDark
                      ? FirebaseRemoteConfigService.getThemeGradientDarkStart()
                      : FirebaseRemoteConfigService.getThemeGradientLightStart();
                  print(
                    '🎨 Track Order Button - Mode: ${isDark ? "DARK" : "LIGHT"}, Hex: $hexColor',
                  );
                  final baseColor = _hexToColor(hexColor);
                  return _lightenColor(baseColor, 0.2);
                }(),
                () {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final hexColor = isDark
                      ? FirebaseRemoteConfigService.getThemeGradientDarkStart()
                      : FirebaseRemoteConfigService.getThemeGradientLightStart();
                  final baseColor = _hexToColor(hexColor);
                  return _lightenColor(baseColor, 0.35);
                }(),
              ],
              glowColor: () {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final hexColor = isDark
                    ? FirebaseRemoteConfigService.getThemeGradientDarkStart()
                    : FirebaseRemoteConfigService.getThemeGradientLightStart();
                return _hexToColor(hexColor);
              }(),
            ),
        ],
      ),
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
    final headerContentHeight = 130.0;
    final totalHeaderHeight = topPadding + headerContentHeight;

    return ListView.separated(
      padding: EdgeInsets.only(top: totalHeaderHeight + 10, bottom: 30),
      itemCount: 5,
      separatorBuilder: (_, index) => const SizedBox(height: 20),
      itemBuilder: (_, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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

        final startColor = isDark
            ? _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientDarkStart(),
              )
            : _hexToColor(
                FirebaseRemoteConfigService.getThemeGradientLightStart(),
              );
        final endColor = isDark
            ? _hexToColor(FirebaseRemoteConfigService.getThemeGradientDarkEnd())
            : Colors.white;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                  spreadRadius: 3,
                ),
              ],
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

  /// Creates a lighter shade of the given color by blending with white
  /// [amount] ranges from 0.0 (original color) to 1.0 (white)
  Color _lightenColor(Color color, [double amount = 0.3]) {
    assert(amount >= 0 && amount <= 1);
    return Color.lerp(color, Colors.white, amount)!;
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
