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
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. STATUS CARD FIRST (Top priority)
                        SizedBox(
                          height: MediaQuery.of(context).padding.top + 90,
                        ),
                        // 1. STATUS CARD (Top priority)
                        _buildStatusCard(theme),
                        const SizedBox(height: 24),
                        const SizedBox(height: 20),

                        // 2. Order Quick Info (ID, Date)
                        _buildOrderMetadataCard(theme),
                        const SizedBox(height: 32),

                        // Products List
                        _buildSectionHeader(
                          theme,
                          "Your Items",
                          Icons.shopping_bag_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildProductsList(theme),
                        const SizedBox(height: 32),

                        // Bill Summary (Receipt Style)
                        _buildSectionHeader(
                          theme,
                          "Payment Summary",
                          Icons.receipt_long_outlined,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildBillSummary(theme),
                        ),
                        const SizedBox(height: 32),

                        // Combined Store & Order Info
                        _buildSectionHeader(
                          theme,
                          "Order Details",
                          Icons.info_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildCombinedOrderInfo(theme),
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

  Widget _buildOrderMetadataCard(ThemeData theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SelectableText(
          "Ref: #${_orderData?['order_id'] ?? widget.orderId}",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    String title = 'Processing';
    String description = 'Your order is being processed';

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

    Color statusColor = theme.colorScheme.primary;
    if (title.toLowerCase().contains('cancelled') ||
        title.toLowerCase().contains('failed')) {
      statusColor = theme.colorScheme.error;
    } else if (title.toLowerCase().contains('delivered') ||
        title.toLowerCase().contains('completed')) {
      statusColor = const Color(0xFF00C853); // Vibrant Green
    } else if (title.toLowerCase().contains('ready') ||
        title.toLowerCase().contains('prepared')) {
      statusColor = Colors.orange.shade700;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          TranslatedText(
            title,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TranslatedText(
            description,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 0.5,
              minHeight: 4,
              backgroundColor: statusColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          TranslatedText(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(ThemeData theme) {
    if (_isLoadingProducts) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }
    if (_products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              size: 40,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 12),
            TranslatedText(
              "No items found",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _products.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.5,
          color: theme.dividerColor.withOpacity(0.3),
          indent: 16,
          endIndent: 16,
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
          final imageUrl = product['image_url'];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Image (Small & Rounded)
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.6),
                      width: 0.5,
                    ),
                    color: isDark ? Colors.grey[800] : Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : Icon(
                            Icons.image_outlined,
                            size: 20,
                            color: theme.disabledColor,
                          ),
                  ),
                ),

                const SizedBox(width: 16),

                // 2. Name & Variant (Left Aligned)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TranslatedText(
                        product['product_name'] ?? 'Item',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (variant != null && variant.toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            variant.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // 3. Price & Qty (Right Aligned - Symmetrical)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "₹${total.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "x$quantity",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillSummary(ThemeData theme) {
    // Data Loading
    final cartTotal = _orderData != null && _orderData!['cart_total'] is List
        ? _orderData!['cart_total'] as List
        : [];
    final platformFees =
        _orderData != null && _orderData!['platform_fees'] is List
        ? _orderData!['platform_fees'] as List
        : [];
    final grandTotal = _orderData?['grand_total'] != null
        ? double.tryParse(_orderData!['grand_total'].toString()) ?? 0.0
        : 0.0;

    Widget buildRow(
      String label,
      dynamic value, {
      bool isBold = false,
      Color? color,
      double? fontSize,
    }) {
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TranslatedText(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(
                  isBold ? 1.0 : 0.6,
                ),
                fontSize: fontSize ?? (isBold ? 16 : 14),
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                color:
                    color ??
                    theme.colorScheme.onSurface.withOpacity(isBold ? 1.0 : 0.8),
                fontSize: fontSize ?? (isBold ? 16 : 14),
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontFamily: isBold ? null : 'RobotoMono',
              ),
            ),
          ],
        ),
      );
    }

    // Simplified Modern Bill Card
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            "Payment Summary",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),

          // Items
          if (cartTotal.isNotEmpty)
            ...cartTotal.map(
              (item) => buildRow(item['title'] ?? '', item['value'] ?? 0),
            ),

          if (cartTotal.isEmpty && _orderData != null) ...[
            buildRow("Item Total", _orderData!['sub_total'] ?? 0),
            buildRow("Tax", _orderData!['total_tax_amount'] ?? 0),
            buildRow("Delivery", _orderData!['delivery_charges'] ?? 0),
          ],

          if (platformFees.isNotEmpty)
            ...platformFees.map(
              (item) => buildRow(item['title'] ?? '', item['value'] ?? 0),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(
                "Order Total",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                "₹${grandTotal.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "${_orderData?['payment_method'] ?? 'Card'}".toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method removed as it is now inside _buildBillSummary for better local scope or we can keep it if needed.
  // I'll replace _buildBillRow with nothing (or if other things use it, I should keep it but I think only summary uses it).
  // Checking file usage: _buildBillSummary calls it. Since I overwrote _buildBillSummary to use local helper or I can implement it there.
  // The replacement above uses a local 'buildRow'. So I should remove the old _buildBillRow to avoid duplication/confusion,
  // or I can just update _buildBillRow and use it.
  // I will replace _buildBillRow with a dummy or empty widget if it's not used, OR I'll just map the space.
  // Actually, I'll just replace the whole block of functions.

  Widget _buildStoreInfo(ThemeData theme) {
    if (_orderData == null) return const SizedBox.shrink();

    final storeName = _orderData!['store_name'] ?? 'Store';
    final storeAddress = _orderData!['store_address'] ?? 'No Address Provided';
    final storeImage = _orderData!['store_image_url'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
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
                    Icons.store,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  storeAddress,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Action Button
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              onPressed: () {
                // Navigate to store
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderMetaGrid(ThemeData theme) {
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

    Widget buildTile(String label, String value, IconData icon, Color accent) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        buildTile(
          "Payment Method",
          _formatStatus(paymentMethod),
          Icons.payment_rounded,
          Colors.purple,
        ),
        buildTile(
          "Order Type",
          _formatStatus(orderType),
          Icons.category_rounded,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildCombinedOrderInfo(ThemeData theme) {
    if (_orderData == null) return const SizedBox.shrink();

    final storeName = _orderData!['store_name'] ?? 'Store';
    final storeAddress = _orderData!['store_address'] ?? 'No Address';
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Order from",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      storeAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.payment_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Payment",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatStatus(paymentMethod),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.directions_bike_outlined,
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Type",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatStatus(orderType),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
