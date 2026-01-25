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

    // Premium Gradient
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
                // 1. CREATIVE HERO SECTION
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: bgGradient,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                    ),
                    // Padding top ensures content starts below the fixed header
                    padding: EdgeInsets.fromLTRB(
                      24,
                      MediaQuery.of(context).padding.top + 70,
                      24,
                      40,
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Watermark Icon
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Transform.rotate(
                            angle: -0.2,
                            child: Icon(
                              Icons.receipt_long_rounded,
                              size: 140,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.05,
                              ),
                            ),
                          ),
                        ),

                        // Content
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // "Order" Label
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                "ORDER RECEIPT",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ID
                            Text(
                              _orderData?['order_id'] != null
                                  ? '#${_orderData!['order_id']}'
                                  : 'Loading...',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: theme.colorScheme.onSurface,
                                height: 1.0,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Date Row
                            if (_orderData?['created_at'] != null)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.event_note_rounded,
                                      size: 16,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Placed On",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.5),
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      TranslatedText(
                                        _orderData!['created_at']
                                            .toString()
                                            .split('T')[0],
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.8),
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

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
                        // Status Card (Vertical Gradient)
                        _buildStatusCard(theme),
                        const SizedBox(height: 30),

                        // Products List
                        _buildSectionHeader(
                          theme,
                          "Items Ordered",
                          Icons.fastfood_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildProductsList(theme),
                        const SizedBox(height: 30),

                        // Bill Summary
                        _buildSectionHeader(
                          theme,
                          "Bill Summary",
                          Icons.receipt_long_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildBillSummary(theme),
                        const SizedBox(height: 30),

                        // Store Info (Revamped)
                        _buildSectionHeader(
                          theme,
                          "Store Details",
                          Icons.store_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildStoreInfo(theme),
                        const SizedBox(height: 30),

                        // Order Details Grid
                        _buildOrderMetaGrid(theme),
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
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      tween: Tween<double>(begin: 0.0, end: _isScrolled ? 1.0 : 0.0),
      builder: (context, value, child) {
        final double blurSigma = value * 20.0;
        final double opacity = value;

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

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              height:
                  MediaQuery.of(context).padding.top + 70, // Increased height
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    startColor.withOpacity(opacity * 0.95),
                    endColor.withOpacity(opacity * 0.95),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withOpacity(opacity * 0.1),
                    width: 0.5,
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 10,
                left: 20,
                right: 20,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
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
                    ),
                  ),

                  // Title (Always Visible)
                  TranslatedText(
                    "Order Details",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

    // Determine status flavor color for accents, but card will use main theme gradient
    Color statusAccentColor = theme.colorScheme.primary;
    if (title.toLowerCase().contains('cancelled') ||
        title.toLowerCase().contains('failed')) {
      statusAccentColor = theme.colorScheme.error;
    } else if (title.toLowerCase().contains('delivered') ||
        title.toLowerCase().contains('completed')) {
      statusAccentColor = Colors.green;
    }

    final isDark = theme.brightness == Brightness.dark;
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24), // Increased padding
          decoration: BoxDecoration(
            // Vertical Gradient as requested
            gradient: LinearGradient(
              colors: [startColor.withOpacity(0.9), endColor.withOpacity(0.9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statusAccentColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: statusAccentColor.withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.timelapse_rounded,
                      color: theme.colorScheme.onSurface,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatedText(
                          title,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TranslatedText(
                          description,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Modern Progress Bar
              Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusAccentColor,
                            statusAccentColor.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: statusAccentColor.withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
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

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        TranslatedText(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList(ThemeData theme) {
    if (_isLoadingProducts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: TranslatedText("No items found")),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final product = _products[index];
          final quantity = product['quantity'] ?? 0;
          final price =
              double.tryParse(
                product['amount_including_tax']?.toString() ?? '0',
              ) ??
              0.0;
          final total = price * quantity;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  image: product['image_url'] != null
                      ? DecorationImage(
                          image: NetworkImage(product['image_url']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product['image_url'] == null
                    ? Icon(
                        Icons.fastfood,
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      product['product_name'] ?? 'Item',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${quantity}x',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBillSummary(ThemeData theme) {
    final cartTotal = _orderData!['cart_total'] as List? ?? [];
    final platformFees = _orderData!['platform_fees'] as List? ?? [];
    final grandTotal = _orderData!['grand_total'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ...cartTotal.map(
            (item) => _buildBillRow(theme, item['title'] ?? '', item['value']),
          ),
          if (platformFees.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...platformFees.map(
              (item) => _buildBillRow(
                theme,
                item['title'] ?? '',
                item['value'],
                isFee: true,
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: theme.dividerColor.withOpacity(0.5)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(
                "Grand Total",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "₹${grandTotal.toStringAsFixed(2)}",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(
    ThemeData theme,
    String label,
    dynamic value, {
    bool isFee = false,
  }) {
    if (value == null) return const SizedBox.shrink();
    double numericValue = 0.0;
    if (value is num) {
      numericValue = value.toDouble();
    } else if (value is String) {
      numericValue = double.tryParse(value) ?? 0.0;
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TranslatedText(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isFee
                  ? theme.colorScheme.onSurface.withOpacity(0.6)
                  : theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: isFee ? 13 : 14,
            ),
          ),
          Text(
            "₹${numericValue.toStringAsFixed(2)}",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: isFee ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfo(ThemeData theme) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Can add navigation to store functionality here later
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Store Logo / Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(
                        _orderData!['store_name'] ?? 'Store Name',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          TranslatedText(
                            "Verified Partner",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TranslatedText(
                    "View",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderMetaGrid(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildMetaCard(
            theme,
            "Payment",
            _orderData!['payment_details']?['payment_method_name'] ?? 'N/A',
            Icons.payment_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetaCard(
            theme,
            "Type",
            _orderData!['order_method_name'] ?? 'N/A',
            Icons.delivery_dining_rounded,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          TranslatedText(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          TranslatedText(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        child: ElevatedButton.icon(
          onPressed: _launchInvoice,
          icon: const Icon(Icons.download_rounded),
          label: const TranslatedText("Download Invoice"),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
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
