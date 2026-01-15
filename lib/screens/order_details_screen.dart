import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:shimmer/shimmer.dart';
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
  bool _isLoadingOrder = true;
  bool _isLoadingProducts = true;
  Map<String, dynamic>? _orderData;
  List<dynamic> _products = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _fetchOrderProducts();
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

      print("📦 Fetching order details for: ${widget.orderId}");

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
          print("✅ Order details fetched successfully");
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
      print("❌ Error fetching order details: $e");
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

      print("📦 Fetching order products for: ${widget.orderId}");

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
        print("✅ Order products fetched: ${_products.length} items");
      } else {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching order products: $e");
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
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
            const SnackBar(content: Text('Could not open invoice')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_orderData?['invoice_url'] != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _launchInvoice,
              tooltip: 'Download Invoice',
            ),
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorView(theme)
          : _isLoadingOrder
          ? _buildLoadingView(theme)
          : _buildOrderDetails(theme),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _fetchOrderDetails();
              _fetchOrderProducts();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      highlightColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails(ThemeData theme) {
    if (_orderData == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_fetchOrderDetails(), _fetchOrderProducts()]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success Banner
            _buildSuccessBanner(theme),
            const SizedBox(height: 16),

            // Order Status Card
            _buildOrderStatusCard(theme),
            const SizedBox(height: 16),

            // Store & Order Info
            _buildOrderInfoCard(theme),
            const SizedBox(height: 16),

            // Products Ordered
            _buildProductsSection(theme),
            const SizedBox(height: 16),

            // Billing Details
            if (_orderData!['billing_details'] != null)
              _buildBillingDetailsCard(theme),
            const SizedBox(height: 16),

            // Payment Details
            if (_orderData!['payment_details'] != null)
              _buildPaymentDetailsCard(theme),
            const SizedBox(height: 16),

            // Price Breakdown
            _buildPriceBreakdownCard(theme),
            const SizedBox(height: 16),

            // Invoice Button
            if (_orderData!['invoice_url'] != null) _buildInvoiceButton(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Placed Successfully!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order #${_orderData!['order_number'] ?? widget.orderId}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(theme).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _orderData!['order_status_title'] ?? 'Order Placed',
                  style: TextStyle(
                    color: _getStatusColor(theme),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _orderData!['order_status_subtitle'] ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                _orderData!['timestamp'] ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            theme,
            'Store',
            _orderData!['store_name'] ?? 'N/A',
            Icons.store_rounded,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            theme,
            'Order Method',
            _orderData!['order_method_name'] ?? 'N/A',
            Icons.delivery_dining_rounded,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            theme,
            'Total Items',
            '${_orderData!['total_items'] ?? 0}',
            Icons.shopping_bag_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Products Ordered',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingProducts)
            const Center(child: CircularProgressIndicator())
          else if (_products.isEmpty)
            Center(
              child: Text(
                'No products found',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final product = _products[index];
                return _buildProductItem(theme, product);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProductItem(ThemeData theme, Map<String, dynamic> product) {
    final quantity = product['quantity'] ?? 0;
    final itemTotal =
        double.tryParse(product['item_total']?.toString() ?? '0') ?? 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${quantity}x',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['product_name'] ?? 'Unknown Product',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${itemTotal.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Text(
          '₹${itemTotal.toStringAsFixed(2)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildBillingDetailsCard(ThemeData theme) {
    final billing = _orderData!['billing_details'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing Address',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      billing['area'] ?? 'N/A',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${billing['state'] ?? ''} - ${billing['pincode'] ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard(ThemeData theme) {
    final payment = _orderData!['payment_details'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            theme,
            'Payment Method',
            payment['payment_method_name'] ?? 'N/A',
            Icons.payment_rounded,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            theme,
            'Status',
            payment['payment_status'] ?? 'N/A',
            Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard(ThemeData theme) {
    final cartTotal = _orderData!['cart_total'] as List? ?? [];
    final platformFees = _orderData!['platform_fees'] as List? ?? [];
    final grandTotal = _orderData!['grand_total'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Cart Total Items
          ...cartTotal.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['title'] ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    '₹${(item['value'] ?? 0.0).toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          // Platform Fees
          if (platformFees.isNotEmpty) ...[
            const Divider(height: 24),
            ...platformFees.map((item) {
              // Only show numeric platform fees
              if (item['value'] is num ||
                  (item['value'] is String &&
                      double.tryParse(item['value']) != null)) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['title'] ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        '₹${(double.tryParse(item['value'].toString()) ?? 0.0).toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],

          const Divider(height: 24),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${grandTotal.toStringAsFixed(2)}',
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

  Widget _buildInvoiceButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _launchInvoice,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Download Invoice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(ThemeData theme) {
    final status = _orderData!['status']?.toString().toLowerCase() ?? '';
    if (status.contains('placed') || status.contains('confirmed')) {
      return Colors.green;
    } else if (status.contains('preparing') || status.contains('processing')) {
      return Colors.orange;
    } else if (status.contains('ready') || status.contains('completed')) {
      return Colors.blue;
    } else if (status.contains('cancelled') || status.contains('rejected')) {
      return Colors.red;
    }
    return theme.colorScheme.primary;
  }
}
