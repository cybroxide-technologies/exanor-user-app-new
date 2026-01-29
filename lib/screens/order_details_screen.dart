import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/screens/order_rating_screen.dart';

import 'package:exanor/screens/product_rating_screen.dart'; // Add import

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String storeId;
  final bool autoTriggerProductRating;
  final double? initialOverallRating;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.storeId,
    this.autoTriggerProductRating = false,
    this.initialOverallRating,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingOrder = true;
  bool _isLoadingProducts = true;
  bool _isLoadingStatuses = true;
  bool _isScrolled = false;
  bool _hasTriggeredRatingFlow = false;

  Map<String, dynamic>? _orderData;
  List<dynamic> _products = [];
  List<dynamic> _orderStatuses = [];
  String? _errorMessage;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      duration: const Duration(seconds: 3), // Smooth continuous rotation
      vsync: this,
    )..repeat();
    _scrollController.addListener(_onScroll);
    _fetchOrderDetails();
    _fetchOrderProducts().then((_) {
      if (widget.autoTriggerProductRating && !_hasTriggeredRatingFlow) {
        _triggerProductRatingFlow();
      }
    });
    _startStatusPolling();
  }

  Future<void> _triggerProductRatingFlow() async {
    _hasTriggeredRatingFlow = true;
    if (!mounted) return;

    // Wait a brief moment for UI to settle if valid
    await Future.delayed(const Duration(milliseconds: 500));

    // Iterate through unrated products
    for (int i = 0; i < _products.length; i++) {
      final product = _products[i];
      if (product['is_rated'] != true) {
        // Show rating screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductRatingScreen(
              orderId: widget.orderId,
              productId:
                  product['id']?.toString() ??
                  product['product_combination_id']?.toString() ??
                  '',
              productName: product['product_name'] ?? 'Item',
              productImage:
                  product['image'] ??
                  product['product_image'] ??
                  product['image_url'],
              initialRating: widget.initialOverallRating,
            ),
          ),
        );

        if (result != null && result is double) {
          // Update local state to show rated immediately
          setState(() {
            _products[i]['is_rated'] = true;
            _products[i]['rating'] = result;
          });

          // Small delay before next
          await Future.delayed(const Duration(milliseconds: 300));
        } else {
          // User cancelled rating this product.
          // Optional: Break loop? Or continue to next?
          // Usually if user cancels one, they might want to stop.
          // Let's ask or just break. For now, we continue to give them chance to rate others?
          // No, usually "close" means stop flow.
          break;
        }
      }
    }

    // Refresh details at the end to ensure sync with server
    _fetchOrderDetails();
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _scrollController.dispose();
    _stopStatusPolling();
    super.dispose();
  }

  void _onScroll() {
    final isScrolled =
        _scrollController.hasClients && _scrollController.offset > 10;
    if (isScrolled != _isScrolled) {
      setState(() => _isScrolled = isScrolled);
    }
  }

  void _startStatusPolling() {
    _fetchOrderStatuses();
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchOrderStatuses();
    });
  }

  void _stopStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> _fetchOrderStatuses() async {
    try {
      final requestBody = {"order_id": widget.orderId, "query": {}};
      final response = await ApiService.post(
        '/order-status/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null &&
          response['data']['status'] == 200 &&
          mounted) {
        final List<dynamic> statuses = response['data']['response'] ?? [];
        setState(() {
          _orderStatuses = statuses;
          _isLoadingStatuses = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching order statuses: $e");
    }
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoadingOrder = true;
      _errorMessage = null;
    });

    try {
      final requestBody = {
        "page": 1,
        "query": {"id": widget.orderId},
        "store_id": widget.storeId,
      };

      final response = await ApiService.post(
        '/orders/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final orders = response['data']['response'] as List;
        if (orders.isNotEmpty) {
          if (mounted) {
            setState(() {
              _orderData = orders.first;
              _isLoadingOrder = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = "Order not found";
            _isLoadingOrder = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Failed to fetch order details";
          _isLoadingOrder = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading order details";
          _isLoadingOrder = false;
        });
      }
    }
  }

  Future<void> _fetchOrderProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final requestBody = {"order_id": widget.orderId, "query": {}};

      final response = await ApiService.post(
        '/orderdata-products/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        if (mounted) {
          setState(() {
            _products = response['data']['response'] as List? ?? [];
            _isLoadingProducts = false;
          });
        }
      } else {
        setState(() => _isLoadingProducts = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Future<void> _launchInvoice() async {
    if (_orderData?['invoice_url'] != null) {
      final url = Uri.parse(_orderData!['invoice_url']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Could not open invoice')),
          );
        }
      }
    }
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return status;
    return status
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Scrollable Content
          RefreshIndicator(
            onRefresh: () async {
              await Future.wait([_fetchOrderDetails(), _fetchOrderProducts()]);
            },
            edgeOffset: 120, // Push refresh circle down below header
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Content or Loading/Error States
                if (_errorMessage != null)
                  SliverFillRemaining(child: _buildErrorView(theme))
                else if (_isLoadingOrder && _orderData == null)
                  SliverFillRemaining(child: _buildLoadingView(theme))
                else ...[
                  // Rest of the content
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 100,
                      16,
                      40,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. Status Banner (Floating above)
                        _buildStatusBanner(theme, isDark),

                        const SizedBox(height: 24),

                        // 2. Order ID & Date Card
                        _buildOrderIdCard(theme, isDark),

                        const SizedBox(height: 24),

                        // 3. Items Section
                        _buildItemsSection(theme, isDark),

                        const SizedBox(height: 24),

                        // 4. Payment Details
                        _buildPaymentSlip(theme, isDark),

                        const SizedBox(height: 24),

                        // 5. Fulfillment Details (Store/Method)
                        _buildFulfillmentDetails(theme, isDark),

                        const SizedBox(height: 120), // Bottom padding
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. Fixed Sticky Header (Always Visible Title)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(theme, isDark),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    // Determine Gradient Colors based on Theme (Matching OrdersListScreen logic)
    final topPadding = MediaQuery.of(context).padding.top;

    // Fixed opacity, unlike scrollable header in list
    const double opacity = 1.0;

    // Calculate Light Mode Colors (Immersive Light: Theme + White Blend)
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
      decoration: const BoxDecoration(
        color: Colors.transparent, // Ensure container itself is transparent
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        // No Shadow on Header
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: topPadding + 80,
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
                  color: theme.dividerColor.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Stack(
              children: [
                // Flowing Background Image (Watermark)
                Positioned(
                  right: -30,
                  bottom: -20,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 100,
                      color: theme.colorScheme.onSurface.withOpacity(0.05),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 15,
                    left: 20,
                    right: 20,
                    bottom: 10,
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      Container(
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
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 22,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),
                      // Title (Always Visible)
                      Expanded(
                        child: TranslatedText(
                          "Order Details",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const SizedBox(
                        width: 48,
                      ), // Balance back button (48 width)
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

  Widget _buildStatusBanner(ThemeData theme, bool isDark) {
    String title = 'Processing';
    String description = 'Order is being processed';

    // Priority: Check main Order Data first for final states
    if (_orderData != null) {
      final mainStatus = _orderData!['status']?.toString().toLowerCase() ?? '';
      final mainTitle = _orderData!['order_status_title']?.toString() ?? '';

      if (mainStatus.contains('delivered') ||
          mainStatus.contains('completed') ||
          mainStatus.contains('cancelled') ||
          mainStatus.contains('failed') ||
          mainStatus.contains('returned')) {
        title = _formatStatus(mainStatus);
        if (mainTitle.isNotEmpty && mainTitle != 'Unknown') title = mainTitle;
      }
    }

    // If title is still default 'Processing', check history for granular updates
    if (title == 'Processing' && _orderStatuses.isNotEmpty) {
      final latest = _orderStatuses.first;
      title = latest['order_status_title'] ?? title;
      description = latest['order_status_description'] ?? description;

      if (title == 'Unknown' || title.isEmpty) {
        final raw = latest['order_status'];
        if (raw != null) title = _formatStatus(raw.toString());
      }
    } else if (title == 'Processing' && _orderData != null) {
      // Fallback to order data if statuses are empty
      final mainStatus = _orderData!['status'];
      if (mainStatus != null) title = _formatStatus(mainStatus.toString());
    }

    Color statusColor;
    IconData statusIcon = Icons.hourglass_top_rounded;

    final processingColorHex =
        FirebaseRemoteConfigService.getOrderProcessingStatusColor();
    final processingColor = _hexToColor(
      processingColorHex,
      defaultColor: theme.colorScheme.primary,
    );

    if (title.toLowerCase().contains('cancelled') ||
        title.toLowerCase().contains('failed')) {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.cancel_rounded;
    } else if (title.toLowerCase().contains('delivered') ||
        title.toLowerCase().contains('completed')) {
      statusColor = const Color(0xFF00C853);
      statusIcon = Icons.check_circle_rounded;
    } else if (title.toLowerCase().contains('ready') ||
        title.toLowerCase().contains('prepared')) {
      statusColor = Colors.orange.shade700;
      statusIcon = Icons.restaurant_rounded;
    } else {
      statusColor = processingColor;
    }

    // New "Timeline" Style Banner
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                24,
                24,
                24,
              ), // Adjusted padding left
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toUpperCase(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (description.isNotEmpty &&
                                description != 'Order is being processed')
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Visual Timeline Bar (Simulated)
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildTimelineStep(theme, true, statusColor),
                      _buildTimelineLine(theme, true, statusColor),
                      _buildTimelineStep(
                        theme,
                        !title.toLowerCase().contains('pending'),
                        statusColor,
                      ),
                      _buildTimelineLine(
                        theme,
                        title.toLowerCase().contains('out_for_delivery') ||
                            title.toLowerCase().contains('delivered') ||
                            title.toLowerCase().contains('completed'),
                        statusColor,
                      ),
                      _buildTimelineStep(
                        theme,
                        title.toLowerCase().contains('delivered') ||
                            title.toLowerCase().contains('completed'),
                        statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Placed", style: _timelineTextStyle(theme)),
                      Text("Processing", style: _timelineTextStyle(theme)),
                      Text("Completed", style: _timelineTextStyle(theme)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(ThemeData theme, bool isActive, Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: isActive ? color : theme.dividerColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: isActive ? Border.all(color: Colors.white, width: 2) : null,
        // No shadow to match user request
      ),
    );
  }

  Widget _buildTimelineLine(ThemeData theme, bool isActive, Color color) {
    return Expanded(
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: isActive ? color : theme.dividerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }

  TextStyle _timelineTextStyle(ThemeData theme) {
    return TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface.withOpacity(0.4),
      letterSpacing: 0.5,
    );
  }

  // 2. Order ID & Date Widget (Refined Sizing & Shadows)
  Widget _buildOrderIdCard(ThemeData theme, bool isDark) {
    String dateStr = "Date not available";
    if (_orderData != null) {
      final timestamp = _orderData!['timestamp'] ?? _orderData!['created_at'];
      if (timestamp != null) {
        try {
          final DateTime parsed = DateTime.parse(timestamp.toString());
          dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
        } catch (e) {
          dateStr = timestamp.toString();
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20), // Reduced loading
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
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
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Order #${_orderData?['order_id'] ?? widget.orderId}",
                  style: TextStyle(
                    fontSize: 16, // Smaller, professional size
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Items Section (Systematic Layout with Images)
  Widget _buildItemsSection(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              "ITEMS ORDERED",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingProducts)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  "No items found",
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: _products.length,
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: theme.dividerColor.withOpacity(0.15)),
              ),
              itemBuilder: (context, index) {
                final product = _products[index];
                final quantity = product['quantity'] ?? 0;
                double total =
                    double.tryParse(
                      product['amount_including_tax']?.toString() ?? '0',
                    ) ??
                    0.0;

                // Fallback: If amount_including_tax is 0, check for other keys or assume it was unit price if needed?
                // But usually 'amount' implies total.
                // Let's also check if 'total' is available directly.
                if (total == 0) {
                  final p =
                      double.tryParse(product['price']?.toString() ?? '0') ??
                      0.0;
                  if (p != 0) total = p * quantity;
                }

                final unitPrice = quantity > 0 ? total / quantity : 0.0;
                final variant = product['variant_name'];
                // Check multiple keys for image, or default to null
                final imageUrl =
                    product['image'] ??
                    product['product_image'] ??
                    product['image_url'];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Image with Quantity Badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            image:
                                imageUrl != null &&
                                    imageUrl.toString().isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.1),
                            ),
                          ),
                          child:
                              (imageUrl == null || imageUrl.toString().isEmpty)
                              ? Icon(
                                  Icons.fastfood_rounded,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.2),
                                  size: 24,
                                )
                              : null,
                        ),
                        // Quantity Badge
                        if (quantity > 1)
                          Positioned(
                            bottom: -6,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                "${quantity}x",
                                style: TextStyle(
                                  color: theme.colorScheme.surface,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            product['product_name'] ?? 'Item Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: theme.colorScheme.onSurface,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Systematic Description lines
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (variant != null &&
                                  variant.toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    variant.toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              Text(
                                "₹${unitPrice.toStringAsFixed(0)} / unit",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              // Rating Badge (New Addition)
                              if (product['is_rated'] == true)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.35),
                                      width: 0.5,
                                    ),
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
                                        "${product['rating'] ?? 0}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          "₹${total.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // 4. Payment Slip (Clean Professional Layout)
  Widget _buildPaymentSlip(ThemeData theme, bool isDark) {
    final cartTotal = _orderData != null && _orderData!['cart_total'] is List
        ? _orderData!['cart_total'] as List
        : [];
    final platformFees =
        _orderData != null && _orderData!['platform_fees'] is List
        ? _orderData!['platform_fees'] as List
        : [];

    // Build all line items
    List<Map<String, dynamic>> lineItems = [];

    if (cartTotal.isNotEmpty) {
      lineItems.addAll(
        cartTotal.map(
          (item) => {'title': item['title'] ?? '', 'value': item['value'] ?? 0},
        ),
      );
    }
    if (cartTotal.isEmpty && _orderData != null) {
      lineItems.add({
        'title': 'Subtotal',
        'value': _orderData!['sub_total'] ?? 0,
      });
      lineItems.add({
        'title': 'Tax',
        'value': _orderData!['total_tax_amount'] ?? 0,
      });
      lineItems.add({
        'title': 'Delivery Charges',
        'value': _orderData!['delivery_charges'] ?? 0,
      });
    }
    if (platformFees.isNotEmpty) {
      lineItems.addAll(
        platformFees.map(
          (item) => {'title': item['title'] ?? '', 'value': item['value'] ?? 0},
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "PAYMENT BREAKDOWN",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withOpacity(0.08),
          ),

          // Line Items
          ...lineItems.asMap().entries.map((entry) {
            // final isLast = entry.key == lineItems.length - 1; // Unused for clean cart style
            final item = entry.value;

            String displayValue = "₹0.00";
            final value = item['value'];
            double parsedValue = 0.0;

            if (value is num) {
              parsedValue = value.toDouble();
            } else if (value != null) {
              // Robust parsing: remove non-numeric chars except dot and minus
              final cleaned = value.toString().replaceAll(
                RegExp(r'[^0-9.-]'),
                '',
              );
              parsedValue = double.tryParse(cleaned) ?? 0.0;
            }

            displayValue = "₹${parsedValue.abs().toStringAsFixed(2)}";

            final isDiscount =
                parsedValue < 0 || (value.toString().contains('-'));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['title'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDiscount
                            ? Colors.green
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDiscount
                          ? Colors.green
                          : theme.colorScheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Bold Divider before Total
          Container(height: 2, color: theme.dividerColor.withOpacity(0.1)),

          // Total Paid Section with Gradient
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.12),
                  theme.colorScheme.primary.withOpacity(0.04),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "TOTAL PAID",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Inclusive of all taxes",
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  "₹${double.tryParse(_orderData?['grand_total']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: theme.colorScheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Fulfillment & Store Details (Symmetrical Layout)
  Widget _buildFulfillmentDetails(ThemeData theme, bool isDark) {
    if (_orderData == null) return const SizedBox.shrink();

    final storeName = _orderData!['store_name'] ?? 'Store';
    final storeAddress = _orderData!['store_address'] ?? 'No Address';
    final storeImage = _orderData!['store_image_url'];

    // Payment & Type
    final paymentData = _orderData?['payment_details'];
    String paymentMethod = 'Unknown';
    if (paymentData is Map) {
      paymentMethod = paymentData['payment_method_name'] ?? 'Unknown';
    } else {
      paymentMethod = _orderData?['payment_method'] ?? 'Unknown';
    }

    // Attempt to determine order Type generically
    final orderType =
        _orderData?['order_method_name'] ??
        _orderData?['order_type'] ??
        'Order';

    final isPaid =
        _orderData?['payment_status'] == 'paid' ||
        _orderData?['payment_status'] == 'Paid';

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
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
      child: Column(
        children: [
          // Added Header for Symmetry
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "ORDER FULFILLMENT",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor.withOpacity(0.4)),

          // Store Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                          Icons.store_mall_directory_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        storeAddress,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor.withOpacity(0.4)),

          // Info Grid - Symmetrical Boxes
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildDetailBox(
                  theme,
                  "METHOD",
                  paymentMethod.toUpperCase(),
                  Icons.payment_rounded,
                ),
                const SizedBox(width: 12),
                _buildDetailBox(
                  theme,
                  "TYPE",
                  orderType.toString().toUpperCase(),
                  Icons.category_rounded,
                ),
                const SizedBox(width: 12),
                _buildDetailBox(
                  theme,
                  "STATUS",
                  (() {
                    final status =
                        _orderData?['order_status_title'] ??
                        _orderData?['status'] ??
                        '';
                    final isDelivered =
                        status.toString().toLowerCase().contains('delivered') ||
                        status.toString().toLowerCase().contains('completed');
                    if (isDelivered) return "COMPLETED";
                    return isPaid ? "PAID" : "PENDING";
                  })(),
                  (() {
                    final status =
                        _orderData?['order_status_title'] ??
                        _orderData?['status'] ??
                        '';
                    final isDelivered =
                        status.toString().toLowerCase().contains('delivered') ||
                        status.toString().toLowerCase().contains('completed');
                    if (isDelivered) return Icons.check_circle_rounded;
                    return isPaid
                        ? Icons.check_circle_rounded
                        : Icons.pending_rounded;
                  })(),
                  valueColor: (() {
                    final status =
                        _orderData?['order_status_title'] ??
                        _orderData?['status'] ??
                        '';
                    final isDelivered =
                        status.toString().toLowerCase().contains('delivered') ||
                        status.toString().toLowerCase().contains('completed');
                    if (isDelivered) return Colors.green;
                    return isPaid ? Colors.green : Colors.orange;
                  })(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for symmetrical Detail Boxes
  Widget _buildDetailBox(
    ThemeData theme,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        height: 100, // Fixed height for perfect symmetry
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    if (_orderData == null) return const SizedBox.shrink();

    final status =
        _orderData!['order_status_title'] ?? _orderData!['status'] ?? '';
    final isDelivered =
        status.toString().toLowerCase().contains('delivered') ||
        status.toString().toLowerCase().contains('completed');
    final hasInvoice = _orderData!['invoice_url'] != null;

    if (!isDelivered && !hasInvoice) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (hasInvoice)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _launchInvoice,
                  icon: Icon(
                    Icons.download_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    "Invoice",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (hasInvoice && isDelivered) const SizedBox(width: 12),
            if (isDelivered)
              Expanded(
                child: _orderData!['is_rated'] == true
                    ? Container(
                        height: 52, // Match standard button height
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A), // Premium Dark
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "RATED",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 16,
                              width: 1,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${_orderData!['rating'] ?? 0}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderRatingScreen(
                                orderId: widget.orderId,
                                storeName: _orderData!['store_name'],
                              ),
                            ),
                          ).then((result) {
                            if (result is Map &&
                                (result['action'] == 'auto_rate_products' ||
                                    result['action'] == 'rate_products')) {
                              final double rating = result['rating'] is double
                                  ? result['rating']
                                  : double.tryParse(
                                          result['rating'].toString(),
                                        ) ??
                                        5.0;
                              final String review = result['review'] ?? '';

                              _rateAllProducts(rating, review);
                            } else if (result != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Order rated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _fetchOrderDetails();
                            }
                          });
                        },
                        icon: const Icon(Icons.star_rounded, size: 20),
                        label: const Text(
                          "Rate Order",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 60,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          TranslatedText(
            _errorMessage ?? "Error",
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _fetchOrderDetails();
              _fetchOrderProducts();
            },
            child: const TranslatedText("Retry"),
          ),
        ],
      ),
    );
  }

  Future<void> _rateAllProducts(double rating, String review) async {
    if (_products.isEmpty) return;

    for (var item in _products) {
      if (item['is_rated'] == true) continue;

      try {
        await ApiService.post(
          '/review-product/',
          body: {
            "order_id": widget.orderId,
            "product_id": item['id'] ?? item['product_combination_id'],
            "rating": rating,
            "review": review,
          },
          useBearerToken: true,
        );
      } catch (e) {
        debugPrint("Failed to auto-rate product ${item['id']}: $e");
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order and products rated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchOrderDetails();
      _fetchOrderProducts();
    }
  }

  Widget _buildLoadingView(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 100,
        16,
        40,
      ),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 1. Status Banner Skeleton
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
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
                            width: 180,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 2. Order ID Skeleton
        Container(
          height: 88,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 3. Items Skeleton
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
