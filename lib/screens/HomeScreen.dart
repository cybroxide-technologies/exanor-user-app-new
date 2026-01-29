import 'dart:ui';
import 'dart:math' as math;
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:exanor/components/home_screen_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Added for ScrollDirection
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/models/store_model.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/custom_sliver_app_bar.dart';
import 'package:exanor/components/professional_bottom_nav.dart';
import 'package:exanor/screens/store_screen.dart';
import 'package:exanor/services/firebase_messaging_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // User Data
  String? userName;
  String? userImage;
  bool _isLoadingUserData = true;
  bool _showTokenSuccess = false;

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
  int _categoryRefreshTrigger = 0;

  // Scroll throttle for performance - limits setState calls during rapid scrolling
  DateTime? _lastScrollTime;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _loadAddressData();
    _sendNotificationData();
    _createNotificationToken();
  }

  Future<void> _loadAddressData() async {
    print(
      '🔄 Home: _loadAddressData called - refreshing address from SharedPreferences',
    );
    setState(() {
      _categoryRefreshTrigger++;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddressId = prefs.getString('saved_address_id');
      final savedTitle = prefs.getString('address_title');
      final savedSubtitle = prefs.getString('address_subtitle');

      print('📍 Home: Loaded from SharedPreferences:');
      print('   ID: $savedAddressId');
      print('   Title: $savedTitle');
      print('   Subtitle: $savedSubtitle');

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

      print(
        '✅ Home: State updated - Title: $_addressTitle, Subtitle: $_addressSubtitle',
      );

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
    // Throttle scroll events to reduce setState calls (max 60fps = 16ms)
    final now = DateTime.now();
    if (_lastScrollTime != null &&
        now.difference(_lastScrollTime!) < const Duration(milliseconds: 16)) {
      // Still check for pagination even if throttled
      _checkPagination();
      return;
    }
    _lastScrollTime = now;

    // Handle Bottom Nav Visibility
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isBottomNavVisible) setState(() => _isBottomNavVisible = false);
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isBottomNavVisible) setState(() => _isBottomNavVisible = true);
    }

    _checkPagination();
  }

  void _checkPagination() {
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
      final image = prefs.getString('user_image');

      setState(() {
        userName = '$firstName $lastName'.trim();
        userImage = image;
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

  Future<void> _sendNotificationData() async {
    try {
      final token = await FirebaseMessagingService.getStoredToken();
      if (token != null) {
        final platformData = {
          'is_android':
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
          'is_ios': !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
          'is_web': kIsWeb,
          'is_macos': !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS,
          'is_windows':
              !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
          'is_linux': !kIsWeb && defaultTargetPlatform == TargetPlatform.linux,
        };

        await ApiService.post(
          '/create-notification-data/',
          body: {'fcm_token': token, ...platformData},
          useBearerToken: true,
        );
        print('✅ Notification data sent successfully');
      }
    } catch (e) {
      print('❌ Error sending notification data: $e');
    }
  }

  Future<void> _createNotificationToken() async {
    try {
      String? token = await FirebaseMessagingService.getStoredToken();

      // Fallback: Try to get token directly from Firebase Messaging instance
      if (token == null) {
        print(
          '⚠️ Home: Stored token is null, fetching directly from instance...',
        );
        try {
          token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            print('✅ Home: Fetched token from instance');
          }
        } catch (e) {
          print('❌ Home: Failed to get token from instance: $e');
        }
      }

      if (token != null) {
        final platformData = {
          'is_android':
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
          'is_ios': !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
          'is_web': kIsWeb,
          'is_macos': !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS,
          'is_windows':
              !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
          'is_linux': !kIsWeb && defaultTargetPlatform == TargetPlatform.linux,
        };

        print('🚀 Home: Calling /create-notification-token/ with token');

        final response = await ApiService.post(
          '/create-notification-token/',
          body: {'fcm_token': token, ...platformData},
          useBearerToken: true,
        );

        if (response['statusCode'] == 200 &&
            response['data'] != null &&
            response['data']['status'] == 200) {
          if (mounted) {
            setState(() {
              _showTokenSuccess = true;
            });
            print('✅ Home: Token creation successful - Showing checkmark');

            // Hide after 2 seconds
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _showTokenSuccess = false;
                });
              }
            });
          }
        } else {
          print(
            '❌ Home: Token creation failed or invalid status: ${response['statusCode']}',
          );
        }
      } else {
        print('❌ Home: No token available to create notification token');
      }
    } catch (e) {
      print('❌ Error creating notification token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBody: true, // Allows content to go under the glass bottom nav
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAddressData,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 2. Store Categories Sticky Header
                SliverPersistentHeader(
                  pinned: true,
                  delegate: StoreCategoriesDelegate(
                    selectedCategoryId: _selectedCategoryId,
                    topPadding: MediaQuery.of(context).padding.top,
                    userName: userName,
                    userImage: userImage,
                    isLoadingUserData: _isLoadingUserData,
                    onUserDataUpdated: _loadUserData,
                    addressTitle: _addressTitle,
                    addressSubtitle: _addressSubtitle,
                    onAddressUpdated: () {
                      _loadAddressData();
                    },
                    onCategorySelected: (categoryId) {
                      setState(() {
                        _selectedCategoryId = categoryId;
                        _page = 1;
                      });
                      _fetchStores();
                    },
                    categoryRefreshTrigger: _categoryRefreshTrigger,
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
                      top: 24, // Increased padding for better separation
                      bottom: 0, // Removed bottom padding (handled by footer)
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
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
                      }, childCount: _stores.length + (_isMoreLoading ? 1 : 0)),
                    ),
                  ),

                // 3. Footer Branding - Integrated Flow Design
                SliverToBoxAdapter(
                  child: Container(
                    height: 280,
                    margin: const EdgeInsets.only(top: 20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 1. "EXANOR" Watermark (Integrated in background)
                        Positioned(
                          bottom: 40,
                          child: Text(
                            "EXANOR",
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.04,
                              ),
                              letterSpacing: 16,
                            ),
                          ),
                        ),

                        // 2. Waves (Overlaying the text) - Wrapped in RepaintBoundary for performance
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: ClipRect(
                              child: CustomPaint(
                                painter: _SilkWavePainter(
                                  color: theme.colorScheme.onSurface,
                                  isDark: theme.brightness == Brightness.dark,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 3. Gradient Fade (Top)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  theme.colorScheme.surface,
                                  theme.colorScheme.surface.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 4. Tagline "Go with the flow" - Repositioned to Top-Right
                        Positioned(
                          top: 40,
                          right: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Go with the flow",
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 20,
                                height: 1.5,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(2),
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
          ),

          // Animated Bottom Navigation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _isBottomNavVisible ? 0 : -100,
            child: ProfessionalBottomNav(
              currentIndex: _bottomNavIndex,
              onTap: (index) {
                setState(() {
                  _bottomNavIndex = index;
                });
              },
            ),
          ),
          if (_showTokenSuccess)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(Store store, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
              // 1. Image Section with Glassmorphic Elements
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.85,
                      child: Image.network(
                        store.storeBannerImgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.2,
                                ),
                                size: 32,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Gradient Overlay (Subtle)
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
                            Colors.black.withOpacity(
                              0.6,
                            ), // Increased darkness for better contrast
                          ],
                          stops: const [
                            0.5,
                            1.0,
                          ], // Start gradient earlier for a smoother, deeper look
                        ),
                      ),
                    ),
                  ),

                  // Top Tags (Sponsored / Featured)
                  if (store.isSponsored || store.isFeatured)
                    Positioned(
                      top: 12, // Tighter placement
                      left: 12,
                      child: Row(
                        children: [
                          if (store.isFeatured) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'FEATURED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8, // Smaller text
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (store.isSponsored)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: const Text(
                                'Ad',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Heart / Favorite Icon
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6), // Smaller padding
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.85),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 18, // Smaller icon
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),

                  // Bottom Glass Info Bar (Time & Rating) - Optimized for performance
                  // Note: Replaced BackdropFilter with static semi-transparent container
                  // for better scroll performance (BackdropFilter is expensive during scrolling)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        // Using a darker semi-transparent background instead of live blur
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 0.5,
                        ),
                        // Subtle shadow for depth
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
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
                            size: 14,
                            color: Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            store.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 1,
                            height: 10,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          Text(
                            store.fulfillmentSpeed, // e.g. "30-40 min"
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Dashed Line Separator
              CustomPaint(
                painter: _StoreCardDashedLinePainter(
                  color: theme.dividerColor.withOpacity(0.5),
                ),
                size: const Size(double.infinity, 1),
              ),

              // 2. Info Section - Reduced Padding
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Area
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                store.storeName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17, // Reduce from huge 20
                                  height: 1.2,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${store.category} • ${store.area}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 3. Coupons / Offers (Refined & subtle)
                    if (store.coupons.isNotEmpty &&
                        store.coupons.any((c) => c.amount > 0)) ...[
                      const SizedBox(height: 14),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: store.coupons
                              .where((c) => c.amount > 0)
                              .take(2)
                              .map((coupon) {
                                final isPercent = coupon.isPercentDiscountType;
                                final amount = coupon.amount.toInt();
                                final label = isPercent
                                    ? '$amount% OFF'
                                    : '₹$amount SAVED';

                                return Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE3F2FD,
                                    ).withOpacity(0.5), // Very light airy blue
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Coupon Icon
                                      if (coupon.imgUrl.isNotEmpty)
                                        Image.network(
                                          coupon.imgUrl,
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.local_offer_rounded,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.local_offer_rounded,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),

                                      const SizedBox(width: 8),

                                      // Coupon Text
                                      Text(
                                        label,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      if (isPercent &&
                                          coupon.maximumDiscountAmountLimit >
                                              0) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 1,
                                          height: 10,
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.3),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Up to ₹${coupon.maximumDiscountAmountLimit.toInt()}",
                                          style: TextStyle(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.8),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ] else if (store.bottomOfferTitle.isNotEmpty) ...[
                      // Bottom Offer Fallback
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              store.bottomOfferTitle,
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
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

class _StoreCardDashedLinePainter extends CustomPainter {
  final Color color;
  _StoreCardDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
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

class _SilkWavePainter extends CustomPainter {
  final Color color;
  final bool isDark;

  _SilkWavePainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Elegant, subtle wave lines
    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.03 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();

    // Draw 5 layers of "silk" for deeper effect
    _drawWave(
      canvas,
      size,
      paint,
      path,
      offset: 0,
      amplitude: 20,
      frequency: 0.012,
    );
    _drawWave(
      canvas,
      size,
      paint,
      path,
      offset: 30, // Tighter spacing
      amplitude: 25,
      frequency: 0.010,
    );
    _drawWave(
      canvas,
      size,
      paint,
      path,
      offset: 60,
      amplitude: 30,
      frequency: 0.008,
    );
    _drawWave(
      canvas,
      size,
      paint,
      path,
      offset: 90,
      amplitude: 20,
      frequency: 0.014,
    );
    _drawWave(
      canvas,
      size,
      paint,
      path,
      offset: 120, // Lower wave
      amplitude: 15,
      frequency: 0.018,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Paint paint,
    Path path, {
    required double offset,
    required double amplitude,
    required double frequency,
  }) {
    path.reset();
    final double startY = size.height * 0.4 + offset;

    path.moveTo(0, startY);

    for (double x = 0; x <= size.width; x += 5) {
      final y =
          startY +
          math.sin((x) * frequency) * amplitude +
          math.cos(x * 0.005) * (amplitude * 0.5);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
