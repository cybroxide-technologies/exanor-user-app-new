import 'dart:async';
import 'dart:ui';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/api_service.dart';

import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/components/custom_cached_network_image.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String initialQuery;
  const GlobalSearchScreen({super.key, this.initialQuery = ''});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<dynamic> _stores = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasNextPage = false;
  String? _errorMessage;

  String _userAddressId = "";
  // double _userLat = 0.0;
  // double _userLng = 0.0;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _scrollController.addListener(_onScroll);
    _loadAddressAndInit();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAddressAndInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userAddressId =
          prefs.getString('saved_address_id') ??
          "e3d3142b-6065-4052-95f6-854a6bb039e9";

      // If initial query exists, trigger search immediately
      if (widget.initialQuery.isNotEmpty) {
        _performSearch(widget.initialQuery);
      }
    } catch (e) {
      print("Error loading address: $e");
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasNextPage) {
      _performSearch(_searchController.text, isLoadMore: true);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _stores = [];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query, {bool isLoadMore = false}) async {
    if (query.trim().isEmpty) return;

    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    }

    try {
      final requestBody = {
        "query": query,
        "user_address_id": _userAddressId,
        "page": isLoadMore ? _currentPage + 1 : 1,
      };

      final response = await ApiService.post(
        '/global-product-search/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final data = response['data'];
        final List<dynamic> rawStores = data['response'] ?? [];
        // Filter out stores with empty product list
        final List<dynamic> newStores = rawStores.where((store) {
          final products = store['search_result'];
          return products is List && products.isNotEmpty;
        }).toList();
        final pagination = data['pagination'];

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _stores.addAll(newStores);
              _currentPage++;
            } else {
              _stores = newStores;
              _currentPage = 1;
            }

            if (pagination != null) {
              _hasNextPage = pagination['has_next'] ?? false;
            } else {
              _hasNextPage = false;
            }

            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to search');
      }
    } catch (e) {
      print("Search error: $e");
      if (mounted) {
        setState(() {
          if (!isLoadMore) _errorMessage = "Failed to load results";
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Gradient Background logic from Orders/Home
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
              // Use Immersive Light logic: mix start with white for softer look
              Color.alphaBlend(
                _hexToColor(
                  FirebaseRemoteConfigService.getThemeGradientLightStart(),
                ).withOpacity(0.35),
                Colors.white,
              ),
              Colors.white,
            ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true, // Important for glassmorphism
      resizeToAvoidBottomInset: false, // Prevent background squish on keyboard
      body: Stack(
        children: [
          // 1. Background Gradient layer
          Container(decoration: BoxDecoration(gradient: bgGradient)),

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                // Header Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      // Back Button (Matches OrdersListScreen style)
                      // Back Button (Updated to match Search Bar)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.25)
                              : Colors.white.withOpacity(
                                  0.2,
                                ), // Matched search bar
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(
                                    0.5,
                                  ), // Matched search bar border
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.1)
                                  : const Color(0xFF1F4C6B).withOpacity(
                                      0.08,
                                    ), // Matched search bar shadow
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 22,
                                color: isDark
                                    ? Colors.grey[300]!.withOpacity(0.8)
                                    : const Color(
                                        0xFF1F4C6B,
                                      ).withOpacity(0.6), // Matched search icon
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Search Bar (Exact Home Screen Replica)
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              height: 50, // Matches back button height
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withOpacity(0.25)
                                    : Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.white.withOpacity(0.5),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withOpacity(0.1)
                                        : const Color(
                                            0xFF1F4C6B,
                                          ).withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.search,
                                    color: isDark
                                        ? Colors.grey[300]!.withOpacity(0.8)
                                        : const Color(
                                            0xFF1F4C6B,
                                          ).withOpacity(0.6),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: _onSearchChanged,
                                      autofocus: true,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : const Color(0xFF1F4C6B),
                                            fontSize: 16,
                                          ),
                                      cursorColor: isDark
                                          ? Colors.white
                                          : const Color(0xFF1F4C6B),
                                      decoration: InputDecoration(
                                        hintText: 'Search for food...',
                                        hintStyle: TextStyle(
                                          color: isDark
                                              ? Colors.grey[300]!.withOpacity(
                                                  0.6,
                                                )
                                              : const Color(
                                                  0xFF1F4C6B,
                                                ).withOpacity(0.5),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        filled: false,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      // Voice search logic if needed
                                    },
                                    child: Container(
                                      height: 40,
                                      width: 40,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.white.withOpacity(0.4),
                                      ),
                                      child: Icon(
                                        Icons.mic_rounded,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.9)
                                            : const Color(0xFF1F4C6B),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Body
                Expanded(child: _buildBody(theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            TranslatedText(_errorMessage!),
          ],
        ),
      );
    }

    if (_stores.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const TranslatedText("No results found"),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger fresh search
        await _performSearch(_searchController.text);
      },
      color: theme.colorScheme.primary,
      backgroundColor: theme.cardColor,
      child: ListView.builder(
        controller: _scrollController,
        physics:
            const AlwaysScrollableScrollPhysics(), // Ensure scroll for refresh
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
        itemCount: _stores.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _stores.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          return _buildStoreItem(theme, _stores[index]);
        },
      ),
    );
  }

  Widget _buildStoreItem(ThemeData theme, dynamic store) {
    final List<dynamic> products = store['search_result'] ?? [];
    final bool isDark = theme.brightness == Brightness.dark;

    // Define Distinct Colors for sections giving a grouped feel but separated visuals
    final Color headerColor = isDark
        ? const Color(0xFF252525)
        : const Color(0xFFF8F8F8); // Slightly grey for light mode header.
    final Color footerColor =
        headerColor; // Matching footer and header for bounding effect

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEAD SECTION (Distinct Color)
            Container(
              color: headerColor,
              child: Column(
                children: [
                  // Store Header
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StoreScreen(storeId: store['id']),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Store Logo
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.2),
                              border: Border.all(
                                color: theme.dividerColor.withOpacity(0.1),
                                width: 1,
                              ),
                              image: store['store_logo_img_url'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        store['store_logo_img_url'],
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: store['store_logo_img_url'] == null
                                ? Icon(
                                    Icons.store_rounded,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.5),
                                    size: 24,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),

                          // Store Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name
                                TranslatedText(
                                  store['store_name'] ?? 'Unknown Store',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),

                                // Badges
                                Row(
                                  children: [
                                    // Rating
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFFB800,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 12,
                                            color: Color(0xFFFFB800),
                                          ),
                                          const SizedBox(width: 4),
                                          TranslatedText(
                                            '${store['average_rating'] ?? 0.0}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFFE6A600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Time
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_filled_rounded,
                                            size: 12,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          TranslatedText(
                                            store['fulfillment_speed'] ?? 'N/A',
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
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

                          // Arrow
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Dashed Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildDashedDivider(
                      theme.brightness == Brightness.dark,
                    ),
                  ),
                ],
              ),
            ),

            // 2. BODY SECTION
            Container(
              color: theme.cardColor, // Unified
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (products.isNotEmpty)
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: products.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return _buildProductCard(
                            theme,
                            products[index],
                            store['id'],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // 3. FOOTER SECTION (Distinct Color)
            Container(
              color: footerColor,
              child: Column(
                children: [
                  // Divider
                  Container(
                    height: 1,
                    color: theme.dividerColor.withOpacity(0.05),
                  ),

                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StoreScreen(storeId: store['id']),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View all',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
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
    );
  }

  Widget _buildDashedDivider(bool isDark) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(
        color: isDark
            ? Colors.white.withOpacity(0.2)
            : Colors.black.withOpacity(0.1),
      ),
    );
  }

  Widget _buildProductCard(ThemeData theme, dynamic product, String storeId) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 135,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoreScreen(
                  storeId: storeId,
                  initialSearchQuery: product['product_name'],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Fixed Height Container
              SizedBox(
                height: 110,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: CustomCachedNetworkImage(
                    imgUrl: product['img_url'] ?? '',
                    width: double.infinity,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TranslatedText(
                        product['product_name'] ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Price & Add
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TranslatedText(
                            '₹${product['lowest_available_price']}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                          if (product['mrp'] != null &&
                              (product['mrp'] is num
                                      ? product['mrp']
                                      : double.tryParse(
                                              product['mrp'].toString(),
                                            ) ??
                                            0) >
                                  (product['lowest_available_price'] is num
                                      ? product['lowest_available_price']
                                      : double.tryParse(
                                              product['lowest_available_price']
                                                  .toString(),
                                            ) ??
                                            0))
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 1,
                              ),
                              child: Text(
                                '₹${product['mrp']}',
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
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
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
