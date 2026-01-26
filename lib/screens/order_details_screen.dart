import 'dart:async';
import 'dart:ui' as ui;
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
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
    _scrollController.addListener(_onScroll);
    _fetchOrderDetails();
    _fetchOrderProducts();
    _startStatusPolling();
  }

  @override
  void dispose() {
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

    // Premium Gradient (Unused now, simplified for other usages if needed, or removed)
    // removed bgGradient definition

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
                else if (_isLoadingOrder)
                  SliverFillRemaining(child: _buildLoadingView(theme))
                else ...[
                  // Rest of the content
                  // Unified Receipt Layout
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. Status Banner (Floating above receipt)
                        _buildStatusBanner(theme),

                        const SizedBox(height: 24),

                        // 2. The Great Receipt
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                                spreadRadius: -10,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Receipt Header (Shop & Order ID)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.3),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "ORDER ID",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.5,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.4),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SelectableText(
                                              "#${_orderData?['order_id'] ?? widget.orderId}",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontFamily: 'monospace',
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Store Icon or Logo Placeholder
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.store_mall_directory_rounded,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    // Date
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 14,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.5),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _orderData?['created_at'] ??
                                              "Date not available",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Separator (ZigZag or Dashed)
                              _buildDashedSeparator(theme),

                              // Items List
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Text(
                                        "YOUR ITEMS",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.4),
                                        ),
                                      ),
                                    ),
                                    _buildProductsListUnified(theme),
                                  ],
                                ),
                              ),

                              // Separator
                              _buildDashedSeparator(theme),

                              // Bill Summary
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Text(
                                        "PAYMENT SUMMARY",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.4),
                                        ),
                                      ),
                                    ),
                                    _buildBillSummaryUnified(theme),
                                  ],
                                ),
                              ),

                              // Total Footer
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(24),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "TOTAL PAID",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      "₹${double.tryParse(_orderData?['grand_total']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. Shipping Info Card (Separate)
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_shipping_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Delivery Details",
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildCombinedOrderInfoUnified(theme),
                            ],
                          ),
                        ),

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
      bottomNavigationBar:
          _orderData != null && _orderData!['invoice_url'] != null
          ? _buildBottomBar(theme)
          : null,
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    // Persistent Header
    final startColor = isDark
        ? _hexToColor(
            FirebaseRemoteConfigService.getThemeGradientDarkStart(),
            defaultColor: const Color(0xFF1A1A1A),
          )
        : _hexToColor(
            FirebaseRemoteConfigService.getThemeGradientLightStart(),
            defaultColor: const Color(0xFFE3F2FD),
          );
    final endColor = isDark
        ? _hexToColor(
            FirebaseRemoteConfigService.getThemeGradientDarkEnd(),
            defaultColor: Colors.black,
          )
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 18, // Softer blur
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: MediaQuery.of(context).padding.top + 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  startColor.withOpacity(0.95),
                  endColor.withOpacity(0.95),
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

  Widget _buildStatusBanner(ThemeData theme) {
    String title = 'Processing';
    String description = 'Order is being processed';

    if (_orderStatuses.isNotEmpty) {
      final latest = _orderStatuses.first;
      title = latest['order_status_title'] ?? title;
      description = latest['order_status_description'] ?? description;
      if (title == 'Unknown' || title.isEmpty) {
        final raw = latest['order_status'];
        if (raw != null) title = _formatStatus(raw.toString());
      }
    } else if (_orderData != null) {
      final mainStatus = _orderData!['status'];
      if (mainStatus != null) title = _formatStatus(mainStatus.toString());
    }

    // Determine Color & Icon
    Color statusColor = theme.colorScheme.primary;
    IconData statusIcon = Icons.hourglass_top_rounded;

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
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedSeparator(ThemeData theme) {
    return SizedBox(
      height: 20,
      child: Center(
        child: CustomPaint(
          painter: DottedLinePainter(
            color: theme.dividerColor.withOpacity(0.2),
          ),
          size: const Size(double.infinity, 1),
        ),
      ),
    );
  }

  Widget _buildProductsListUnified(ThemeData theme) {
    if (_isLoadingProducts) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
          strokeWidth: 2,
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: Text(
          "No items found",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantity Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              ),
              child: Text(
                "${quantity}x",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['product_name'] ?? 'Item',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                  if (variant != null && variant.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        variant.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price
            Text(
              "₹${total.toStringAsFixed(0)}",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBillSummaryUnified(ThemeData theme) {
    final cartTotal = _orderData != null && _orderData!['cart_total'] is List
        ? _orderData!['cart_total'] as List
        : [];
    final platformFees =
        _orderData != null && _orderData!['platform_fees'] is List
        ? _orderData!['platform_fees'] as List
        : [];

    Widget buildRow(String key, dynamic value, {bool isLarge = false}) {
      String displayValue = "₹0.00";
      if (value is num) {
        displayValue = "₹${value.toStringAsFixed(2)}";
      } else if (value is String) {
        if (double.tryParse(value) != null) {
          displayValue = "₹${double.parse(value).toStringAsFixed(2)}";
        } else {
          displayValue = value;
        }
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              key,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.9),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (cartTotal.isNotEmpty)
          ...cartTotal.map(
            (item) => buildRow(item['title'] ?? '', item['value'] ?? 0),
          ),
        if (cartTotal.isEmpty && _orderData != null) ...[
          buildRow("Subtotal", _orderData!['sub_total'] ?? 0),
          buildRow("Tax", _orderData!['total_tax_amount'] ?? 0),
          buildRow("Delivery", _orderData!['delivery_charges'] ?? 0),
        ],
        if (platformFees.isNotEmpty)
          ...platformFees.map(
            (item) => buildRow(item['title'] ?? '', item['value'] ?? 0),
          ),
      ],
    );
  }

  Widget _buildCombinedOrderInfoUnified(ThemeData theme) {
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

    final orderType =
        _orderData?['order_method_name'] ??
        _orderData?['order_type'] ??
        'Delivery';

    final isPaid =
        _orderData?['payment_status'] == 'paid' ||
        _orderData?['payment_status'] == 'Paid';

    return Column(
      children: [
        // Store Row
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
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
                      Icons.store,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    storeAddress,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Info Grid
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "METHOD",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      paymentMethod.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "STATUS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPaid ? "PAID" : "PENDING",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isPaid ? Colors.green : Colors.orange,
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
  }

  Widget _buildBottomBar(ThemeData theme) {
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
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _launchInvoice,
            icon: Icon(
              Icons.download_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            label: Text(
              "Download Invoice",
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

  Widget _buildLoadingView(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );
  }
}

// Custom receipt clipper
class ReceiptClipper extends CustomClipper<Path> {
  final int holeCount;

  ReceiptClipper({this.holeCount = 20});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);

    final double d = size.width / holeCount;

    // Zigzag/Triangle bottom
    for (int i = 0; i < holeCount; i++) {
      // Creates a sawtooth pattern
      double x = i * d;
      // The midpoint of the tooth
      path.lineTo(x + d / 2, size.height - 10);
      // The end of the tooth (back to full height)
      path.lineTo(x + d, size.height);
    }

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class DottedLinePainter extends CustomPainter {
  final Color color;

  DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
