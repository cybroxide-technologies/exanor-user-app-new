import 'dart:async';
import 'dart:ui' as ui;
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exanor/screens/order_rating_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String storeId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.storeId,
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
    _fetchOrderProducts();
    _startStatusPolling();
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
      bottomNavigationBar: _orderData != null ? _buildBottomBar(theme) : null,
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
        color: Colors.transparent, // Ensure container itself is transparent
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
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

    // Determine Colors
    Color statusColor;
    final processingColorHex =
        FirebaseRemoteConfigService.getOrderProcessingStatusColor();
    final processingColor = _hexToColor(
      processingColorHex,
      defaultColor: theme.colorScheme.primary,
    );

    bool isCancelled =
        title.toLowerCase().contains('cancelled') ||
        title.toLowerCase().contains('failed');
    bool isDelivered =
        title.toLowerCase().contains('delivered') ||
        title.toLowerCase().contains('completed');

    if (isCancelled) {
      statusColor = theme.colorScheme.error;
    } else if (isDelivered) {
      statusColor = const Color(0xFF00C853);
    } else if (title.toLowerCase().contains('ready') ||
        title.toLowerCase().contains('prepared') ||
        title.toLowerCase().contains('out')) {
      statusColor = Colors.orange.shade700;
    } else {
      statusColor = processingColor;
    }

    // Tracker Logic
    // Step 1: Placed (Always true unless empty, which shouldn't happen)
    bool step1 = true;
    // Step 2: Preparing (Active if not just placed/pending)
    bool step2 =
        !title.toLowerCase().contains('pending') &&
        !title.toLowerCase().contains('placed');
    // Step 4: Delivered
    bool step4 = isDelivered;

    // If cancelled, simplified view
    if (isCancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cancel_rounded,
              color: theme.colorScheme.error,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Standard Premium Tracker
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status Text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (description.isNotEmpty &&
                        description != 'Order is being processed')
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Status Icon Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isDelivered
                      ? Icons.check_circle_rounded
                      : (title.toLowerCase().contains('out') ||
                            title.toLowerCase().contains('shipped'))
                      ? Icons.local_shipping_rounded
                      : Icons.inventory_2_rounded,
                  color: statusColor,
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 4-Step Tracker
          Row(
            children: [
              _buildTrackerItem(
                theme,
                Icons.receipt_long_rounded,
                "Placed",
                step1,
                step1, // Placed is always passed if active
                statusColor,
              ),
              _buildTrackerLine(theme, step2, statusColor),
              _buildTrackerItem(
                theme,
                Icons.inventory_2_rounded,
                "Processing",
                step2,
                step4, // If step 4 (Delivered) is active, Step 2 is completed
                statusColor,
              ),
              _buildTrackerLine(theme, step4, statusColor),
              _buildTrackerItem(
                theme,
                Icons.home_rounded,
                "Delivered",
                step4,
                step4,
                statusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerItem(
    ThemeData theme,
    IconData icon,
    String label,
    bool isActive,
    bool isCompleted,
    Color activeColor,
  ) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? activeColor
                  : theme.dividerColor.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            // If completed (and not just active current step), show check?
            // Actually, keep distinctive icons for clarity as requested.
            // But maybe outline vs filled?
            icon,
            color: isActive
                ? Colors.white
                : theme.colorScheme.onSurface.withOpacity(0.4),
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackerLine(ThemeData theme, bool isActive, Color color) {
    return Expanded(
      child: Container(
        height: 3,
        // Move line up to align with center of circle (40 height -> center 20)
        // With Column, it's tricky. Best to just center in Row.
        // But wrapped in Column(Icon + Text) makes centering hard.
        // Actually, the transform logic or just spacing can work.
        // Let's use simple Container margin.
        margin: const EdgeInsets.only(bottom: 20, left: 2, right: 2),
        decoration: BoxDecoration(
          color: isActive ? color : theme.dividerColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }

  // 2. Order ID & Date Widget (Refined Sizing & Shadows)
  Widget _buildOrderIdCard(ThemeData theme, bool isDark) {
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
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
                  (() {
                    final timestamp =
                        _orderData?['timestamp'] ?? _orderData?['created_at'];
                    if (timestamp != null) {
                      try {
                        final DateTime parsed = DateTime.parse(
                          timestamp.toString(),
                        );
                        return DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(parsed);
                      } catch (e) {
                        return timestamp.toString();
                      }
                    }
                    return "Date not available";
                  })(),
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
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
                final price =
                    double.tryParse(
                      product['amount_including_tax']?.toString() ?? '0',
                    ) ??
                    0.0;
                final total = price * quantity;
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
                                "₹${price.toStringAsFixed(0)} / unit",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
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
                        if (product['rating'] != null ||
                            product['user_rating'] != null ||
                            product['is_rated'] == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.5),
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
                                    product['rating']?.toString() ??
                                        product['user_rating']?.toString() ??
                                        "Rated",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
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
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
            if (value is num) {
              displayValue = "₹${value.toStringAsFixed(2)}";
            } else if (value is String && double.tryParse(value) != null) {
              displayValue = "₹${double.parse(value).toStringAsFixed(2)}";
            }

            final isDiscount =
                (value is num && value < 0) ||
                (value is String && value.startsWith('-'));

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
                          (() {
                            // Determine Payment Method Name
                            final paymentData = _orderData?['payment_details'];
                            String paymentMethod = '';
                            if (paymentData is Map) {
                              paymentMethod =
                                  (paymentData['payment_method_name'] ?? '')
                                      .toString()
                                      .toLowerCase();
                            } else {
                              paymentMethod =
                                  (_orderData?['payment_method'] ?? '')
                                      .toString()
                                      .toLowerCase();
                            }

                            // Determine Status
                            final status = (_orderData?['status'] ?? '')
                                .toString()
                                .toLowerCase();

                            // Use negation of final states to capture all processing states (placed, confirmed, shipped, etc.)
                            final isFinalState =
                                status.contains('delivered') ||
                                status.contains('completed') ||
                                status.contains('cancelled') ||
                                status.contains('failed') ||
                                status.contains('returned');

                            final isProcessing = !isFinalState;

                            final isCashOrUpi =
                                paymentMethod.contains('cash') ||
                                paymentMethod.contains('cod') ||
                                paymentMethod.contains('pay on delivery') ||
                                paymentMethod.contains('upi');

                            if (isProcessing && isCashOrUpi) {
                              return "AMOUNT TO BE PAID";
                            }
                            return "TOTAL PAID";
                          })(),
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
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
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

          Divider(
            height: 1,
            thickness: 1.5,
            color: theme.dividerColor.withOpacity(0.4),
          ),

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

          Divider(
            height: 1,
            thickness: 1.5,
            color: theme.dividerColor.withOpacity(0.4),
          ),

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
          border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
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
    // Check status for Rating Button
    final status = (_orderData?['status'] ?? '').toString().toLowerCase();
    final isDelivered =
        status.contains('delivered') || status.contains('completed');

    // Check availability for Invoice Button
    final hasInvoice = _orderData!['invoice_url'] != null;

    // If neither is valid, hide bar
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
            // Invoice Button (Left Side)
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

            // Spacer if both elements exist
            if (isDelivered && hasInvoice) const SizedBox(width: 12),

            // Rate Order Button or Badge (Right Side)
            if (isDelivered)
              if (_orderData?['is_rated'] != true)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRatingDialog(_orderData),
                    icon: Icon(
                      Icons.star_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      "Rate Order",
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
                )
              else
                // Rating Badge (Same Size as Button)
                Expanded(
                  child: Container(
                    height:
                        52, // Match button height with border (16*2 padding + 20 icon approx ~ 52-56)
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
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 24,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${_orderData?['rating'] ?? 0}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(dynamic order) {
    if (order == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderRatingScreen(
          orderId: order['id']?.toString() ?? widget.orderId,
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
                content: TranslatedText('Order rated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _fetchOrderDetails();
            _fetchOrderProducts();
          } else if (result['rating'] != null) {
            _fetchOrderDetails();
            _fetchOrderProducts();
          }
        } else if (result is double) {
          _fetchOrderDetails();
          _fetchOrderProducts();
        }
      }
    });
  }

  Future<void> _rateAllProducts(
    dynamic order,
    double rating,
    String review,
  ) async {
    final List items = _products; // Use local products list
    if (items.isEmpty) return;

    for (var item in items) {
      if (item['is_rated'] == true) continue;

      try {
        await ApiService.post(
          '/review-product/',
          body: {
            "order_id": order['id'] ?? widget.orderId,
            "product_id": item['id'] ?? item['product_combination_id'],
            "rating": rating,
            "review": review,
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
    if (mounted) {
      _fetchOrderDetails();
      _fetchOrderProducts();
    }
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

  Widget _buildLoadingView(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );
  }
}
