import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/home_screen_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Added for ScrollDirection
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/models/store_model.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/custom_sliver_app_bar.dart';
import 'package:exanor/components/professional_bottom_nav.dart';
import 'package:exanor/screens/store_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // User Data
  String? userName;
  bool _isLoadingUserData = true;

  // Navigation
  int _bottomNavIndex = 0;

  // Store Data & Pagination
  List<Store> _stores = [];
  bool _isLoading = true;
  bool _isMoreLoading = false;
  int _page = 1;
  bool _hasNextPage = true;

  late ScrollController _scrollController;

  // Default constant ID
  final String _constAddressId = "e3d3142b-6065-4052-95f6-854a6bb039e9";
  String _userAddressId = "e3d3142b-6065-4052-95f6-854a6bb039e9";

  String _addressTitle = "Home";
  String _addressSubtitle = "Phagwara, Punjab";

  String _selectedCategoryId = '';

  bool _isBottomNavVisible = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _loadAddressData();
  }

  Future<void> _loadAddressData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddressId = prefs.getString('saved_address_id');

      setState(() {
        if (savedAddressId != null && savedAddressId.isNotEmpty) {
          _userAddressId = savedAddressId;
          _addressTitle = prefs.getString('address_title') ?? "Home";
          _addressSubtitle =
              prefs.getString('address_subtitle') ?? "Phagwara, Punjab";
        } else {
          _userAddressId = _constAddressId;
          // Keep default title/subtitle or set to constants
        }
      });

      // Fetch stores after address is loaded
      // Reset pagination
      _page = 1;
      _fetchStores();
    } catch (e) {
      print('❌ Home: Error loading address data: $e');
      // Fallback to const ID and fetch
      _userAddressId = _constAddressId;
      _page = 1;
      _fetchStores();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _hasNextPage) {
        _fetchStores(loadMore: true);
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('first_name') ?? '';
      final lastName = prefs.getString('last_name') ?? '';

      setState(() {
        userName = '$firstName $lastName'.trim();
        _isLoadingUserData = false;
      });
    } catch (e) {
      print('❌ Home: Error loading user data: $e');
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  Future<void> _fetchStores({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        _isMoreLoading = true;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final requestBody = {
        "user_address_id": _userAddressId,
        "radius": 20000,
        "page": _page,
        if (_selectedCategoryId.isNotEmpty)
          "store_category_id": _selectedCategoryId,
      };

      print('🏪 Fetching stores: Page $_page');

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

        final pagination = responseData['pagination'];
        final hasNext = pagination['has_next'] ?? false;

        if (mounted) {
          setState(() {
            if (loadMore) {
              _stores.addAll(storesList);
            } else {
              _stores = storesList;
            }

            _hasNextPage = hasNext;
            _page++;
            _isLoading = false;
            _isMoreLoading = false;
          });
        }
      } else {
        print('❌ Failed to fetch stores: ${response['data']}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isMoreLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching stores: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMoreLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBody: true, // Allows content to go under the glass bottom nav
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            if (notification.direction == ScrollDirection.reverse &&
                _isBottomNavVisible) {
              setState(() {
                _isBottomNavVisible = false;
              });
            } else if (notification.direction == ScrollDirection.forward &&
                !_isBottomNavVisible) {
              setState(() {
                _isBottomNavVisible = true;
              });
            }
          }
          return true;
        },
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadAddressData,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Custom Sliver App Bar
                  CustomSliverAppBar(
                    addressTitle: _addressTitle,
                    addressSubtitle: _addressSubtitle,
                    userName: userName,
                    isLoadingUserData: _isLoadingUserData,
                    onAddressUpdated: () {
                      print("Address updated callback received");
                      _loadAddressData();
                    },
                    onUserDataUpdated: _loadUserData,
                  ),

                  // 2. Store Categories Sticky Header
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StoreCategoriesDelegate(
                      selectedCategoryId: _selectedCategoryId,
                      topPadding: MediaQuery.of(context).padding.top,
                      onCategorySelected: (categoryId) {
                        setState(() {
                          _selectedCategoryId = categoryId;
                          _page = 1;
                        });
                        _fetchStores();
                      },
                    ),
                  ),

                  // 2. Content Body
                  if (_isLoading)
                    const HomeScreenSkeleton()
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 4, // Reduced from 16
                        bottom: 80,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _stores.length) {
                              return _isMoreLoading
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: _buildStoreCard(_stores[index], theme),
                            );
                          },
                          childCount: _stores.length + (_isMoreLoading ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Animated Bottom Navigation
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart,
              left: 0,
              right: 0,
              bottom: _isBottomNavVisible
                  ? 0
                  : -200, // Move completely off-screen
              child: SafeArea(
                child: ProfessionalBottomNav(
                  currentIndex: _bottomNavIndex,
                  onTap: (index) {
                    setState(() {
                      _bottomNavIndex = index;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(Store store, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => StoreScreen(storeId: store.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image Section with Prominent Overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: AspectRatio(
                      aspectRatio: 21 / 10, // Slightly improved aspect ratio
                      child: Image.network(
                        store.storeBannerImgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Gradient Overlay for Text Visibility
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Sponsored Tag
                  if (store.isSponsored)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 0.5,
                          ),
                        ),
                        child: const Text(
                          'Ad',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // featured Tag
                  if (store.isFeatured)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'FEATURED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Time & Distance Pill (Bottom Right of Image)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_filled_rounded,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            store.fulfillmentSpeed,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Content Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and Categories
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                store.storeName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.green[700],
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.star,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    store.averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${store.category} • ${store.area}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 3. Offers Section (Compact & Premium)
                    if (store.coupons.isNotEmpty &&
                        store.coupons.any((c) => c.amount > 0)) ...[
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.discount_rounded,
                            size: 18,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final validCoupons = store.coupons
                                    .where((c) => c.amount > 0)
                                    .toList();
                                if (validCoupons.isEmpty)
                                  return const SizedBox();
                                final coupon =
                                    validCoupons.first; // Show main offer

                                final isPercent = coupon.isPercentDiscountType;
                                final amount = coupon.amount.toInt();
                                final offerText = isPercent
                                    ? '$amount% OFF'
                                    : 'Save ₹$amount';

                                String subText = "";
                                if (isPercent &&
                                    coupon.maximumDiscountAmountLimit > 0) {
                                  subText =
                                      "up to ₹${coupon.maximumDiscountAmountLimit.toInt()}";
                                } else if (coupon.minimumAmount > 0) {
                                  subText =
                                      "on orders above ₹${coupon.minimumAmount.toInt()}";
                                }

                                return RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontFamily: theme
                                          .textTheme
                                          .bodyMedium
                                          ?.fontFamily,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 12,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: offerText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                      if (subText.isNotEmpty)
                                        TextSpan(text: " $subText"),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else if (store.bottomOfferTitle.isNotEmpty) ...[
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              store.bottomOfferTitle,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
