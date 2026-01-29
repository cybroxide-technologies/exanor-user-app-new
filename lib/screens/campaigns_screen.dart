import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/campaign_models.dart';
import 'package:exanor/components/external_coupon_carousel.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  bool _isLoading = true;
  bool _isLeaderboardLoading = false;
  List<TopUser> _topUsers = [];
  List<NewUser> _newUsers = [];
  String? _errorMessage;
  int? _myRank;
  late PageController _premiumCarouselController;
  Timer? _carouselTimer;

  // Premium "Matte" Palette
  final Color _bgPurple = const Color(0xFF6B5AE0);
  final Color _matteDark = const Color(0xFF1A1A2E); // Deep Matte Blue/Black
  final Color _matteCard = const Color(0xFF16213E); // Slightly lighter matte

  final Color _cardPeach = const Color(0xFFFF9F76);
  final Color _cardPeachDark = const Color(0xFFFF8F60);

  final Color _p1Front = const Color(0xFFA89BF2);
  final Color _p1Side = const Color(0xFF8D82C4);
  final Color _p1Top = const Color(0xFFC4B9F7);

  final Color _p2Front = const Color(0xFFE5B085);
  final Color _p2Side = const Color(0xFFC4926C);
  final Color _p2Top = const Color(0xFFF0CBAB);

  final Color _p3Front = const Color(0xFFF2E291);
  final Color _p3Side = const Color(0xFFCFC07A);
  final Color _p3Top = const Color(0xFFF9EFB8);

  @override
  void initState() {
    super.initState();
    // Increased viewport fraction to prevent overlap
    _premiumCarouselController = PageController(
      viewportFraction: 0.75,
      initialPage: 1000,
    );
    _fetchData();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _premiumCarouselController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (_premiumCarouselController.hasClients) {
        _premiumCarouselController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  void _onTabTapped(int index) {
    if (index == 0) {
      // Trend/Leaderboard Tab
      setState(() {
        _isLeaderboardLoading = true;
      });
      // Simulate loading delay for better UX or fetch fresh data
      _fetchData(isRefresh: true);
    }
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (!isRefresh) _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.post(
          '/view-top-users/',
          body: {},
          useBearerToken: true,
        ).timeout(const Duration(seconds: 10)),
        ApiService.post(
          '/view-new-users/',
          body: {},
          useBearerToken: true,
        ).timeout(const Duration(seconds: 10)),
        // Force a minimum 2-second delay to show the loading animation
        Future.delayed(const Duration(seconds: 2)),
      ]);

      if (!mounted) return;

      final topUsersResponse = results[0];
      final newUsersResponse = results[1];

      // Extract current user's rank from current_user object
      int? myRank;
      try {
        if (topUsersResponse['data'] != null &&
            topUsersResponse['data']['current_user'] != null &&
            topUsersResponse['data']['current_user']['rank'] != null) {
          myRank = topUsersResponse['data']['current_user']['rank'] as int?;
        }
      } catch (_) {}

      List<TopUser> topUsers = [];
      try {
        if (topUsersResponse['data'] != null &&
            topUsersResponse['data']['response'] != null) {
          topUsers = (topUsersResponse['data']['response'] as List)
              .map((e) => TopUser.fromJson(e))
              .toList();
        }
      } catch (e) {
        print("Error parsing top users: $e");
      }

      // Limit to top 15 if more
      if (topUsers.length > 15) topUsers = topUsers.sublist(0, 15);

      List<NewUser> newUsers = [];
      try {
        if (newUsersResponse['data'] != null &&
            newUsersResponse['data']['response'] != null) {
          newUsers = (newUsersResponse['data']['response'] as List)
              .map((e) => NewUser.fromJson(e))
              .toList();
        }
      } catch (e) {
        print("Error parsing new users: $e");
      }

      setState(() {
        _topUsers = topUsers;
        _newUsers = newUsers;
        _myRank = myRank;
        _errorMessage = null;
      });
      if (_newUsers.isNotEmpty) {
        _startAutoScroll();
      }
    } catch (e) {
      print("Error in _fetchData: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load data";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLeaderboardLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPurple,
      body: DefaultTabController(
        length: 3,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isLoading
              ? _buildLoadingState() // Key is important for AnimatedSwitcher
              : _errorMessage != null
              ? _buildErrorState()
              : Stack(
                  key: const ValueKey('content'),
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_bgPurple, const Color(0xFF5648B8)],
                          ),
                        ),
                      ),
                    ),

                    // Content Layer
                    TabBarView(
                      physics:
                          const NeverScrollableScrollPhysics(), // DISABLED SWIPE
                      children: [
                        _buildWeeklyTab(context),
                        _buildNewUsersCreativeTab(context),
                        _buildOffersTab(context),
                      ],
                    ),

                    // Fixed Glass Header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildGlassHeader(context),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGlassHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    // Increased height to accommodate the restored tabs
    final headerHeight = topPadding + 140;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: headerHeight,
          decoration: BoxDecoration(
            color: _bgPurple.withOpacity(0.95),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Title Row
              Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 5,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(14),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Text(
                      "Trends",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Tabs
              Container(
                height: 44,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  onTap: _onTabTapped, // Ensures data refresh logic triggers
                  indicator: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.6),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(text: "Trends"),
                    Tab(text: "New Users"),
                    Tab(text: "Offers"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardShimmer() {
    final topPadding = MediaQuery.of(context).padding.top + 180;
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: topPadding + 10),
          sliver: SliverToBoxAdapter(
            child: Shimmer.fromColors(
              baseColor: Colors.white.withOpacity(0.4),
              highlightColor: Colors.white.withOpacity(0.8),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Podium Placeholder
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 80,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 90,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 80,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // List connector mask placeholder
                  Container(
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: List.generate(
                  5,
                  (index) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyTab(BuildContext context) {
    // Use real data only
    final List<TopUser> displayUsers = _topUsers;

    // Responsive calculations
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top + 160;

    // Calculate overlap based on screen height (~5.5% of screen, min 40px)
    final bannerOverlap = (screenHeight * 0.055).clamp(40.0, 70.0);

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(top: topPadding),
      children: [
        // A. Podium Section
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildPodiumRow(displayUsers.take(3).toList()),
        ),

        // B. Divider / List Header - overlaps the podium
        Transform.translate(
          offset: Offset(0, -bannerOverlap),
          child: Container(
            height: bannerOverlap,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),

        // C. The List Itself (Background White) - also shifted up
        Transform.translate(
          offset: Offset(0, -bannerOverlap),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                if (displayUsers.length > 3)
                  _buildListSection(displayUsers.sublist(3), startIndex: 4)
                else
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text("Start ordering to join the trends!"),
                  ),
                // Add bottom spacing here so it is white and scrollable
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewUsersCreativeTab(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 160;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: topPadding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // Unified "Billboard" Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  clipBehavior:
                      Clip.antiAlias, // KEY FIX: Clips the overflowing content
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header inside the container
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "FRESH FACES",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withOpacity(0.6),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "New Arrivals",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Carousel nicely contained inside
                      SizedBox(
                        height: 380, // Height for the carousel to live in
                        child: _newUsers.isEmpty
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : PageView.builder(
                                controller: _premiumCarouselController,
                                // Removed Clip.none, relying on container clipping
                                itemBuilder: (context, index) {
                                  final userIndex = index % _newUsers.length;
                                  final user = _newUsers[userIndex];

                                  return AnimatedBuilder(
                                    animation: _premiumCarouselController,
                                    builder: (context, child) {
                                      double value = 1.0;
                                      if (_premiumCarouselController
                                          .position
                                          .haveDimensions) {
                                        value =
                                            _premiumCarouselController.page! -
                                            index;
                                        value = (1 - (value.abs() * 0.25))
                                            .clamp(0.0, 1.0);
                                      }
                                      final scale = Curves.easeOut.transform(
                                        value,
                                      );
                                      // Less aggressive opacity fading
                                      final opacity = value < 0.8 ? 0.6 : 1.0;

                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: SizedBox(
                                            height: scale * 340,
                                            child: Opacity(
                                              opacity: opacity,
                                              child: child,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: _buildBigNewUserCard(user),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOffersTab(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 180;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      margin: EdgeInsets.only(top: topPadding + 20),
      child: const ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 50, bottom: 80),
          child: Column(
            children: [SizedBox(height: 20), ExternalCouponCarousel()],
          ),
        ),
      ),
    );
  }

  // Helper widget removed in favor of integrated header
  // Widget _buildHeader() {}
  // Widget _buildTabs() {}

  Widget _buildBigNewUserCard(NewUser user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        // Shadow removed as requested
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          if (user.imgUrl.isNotEmpty)
            Image.network(user.imgUrl, fit: BoxFit.cover)
          else
            Container(
              color: Colors.grey.shade200,
              child: Icon(Icons.person, size: 80, color: Colors.grey.shade400),
            ),

          // Subtle Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // Glass Info Box
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "NEW",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _bgPurple,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Joined Recently",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.8),
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
    );
  }

  Widget _buildLeaderboardHeaderContent() {
    final top3 = _topUsers.take(3).toList();

    return Column(
      children: [
        if (top3.isNotEmpty) _buildPodiumRow(top3),

        // MASK to strictly hide bottoms
        Transform.translate(
          offset: const Offset(0, -30),
          child: Container(
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            alignment: Alignment.topCenter,
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumRow(List<TopUser> top3) {
    TopUser? first = top3.isNotEmpty ? top3[0] : null;
    TopUser? second = top3.length > 1 ? top3[1] : null;
    TopUser? third = top3.length > 2 ? top3[2] : null;

    final width = MediaQuery.of(context).size.width;
    final availableWidth = width - 40;

    // Widths - Equal for all ranks
    final podiumWidth = availableWidth * 0.35;

    // Gap calculation:
    // podiumWidth - 25 provides good overlap for Rank 2.
    // We will manually slide Rank 3 to adjust its position independently.
    final double gapWidth = podiumWidth - 25;

    // We prepare the items
    Widget? rank2Item;
    if (second != null) {
      rank2Item = _buildPodiumItem(
        user: second,
        rank: 2,
        height: 180,
        width: podiumWidth,
        front: _p2Front,
        side: _p2Side,
        top: _p2Top,
        showSide: false, // Merges right
      );
    }

    Widget? rank3Item;
    if (third != null) {
      rank3Item = _buildPodiumItem(
        user: third,
        rank: 3,
        height: 150,
        width: podiumWidth,
        front: _p3Front,
        side: _p3Side,
        top: _p3Top,
        showSide: true,
      );
    }

    // Placeholders for alignment
    final rank2Placeholder = Opacity(
      opacity: 0,
      child: SizedBox(width: podiumWidth),
    );
    final rank3Placeholder = Opacity(
      opacity: 0,
      child: SizedBox(width: podiumWidth),
    );

    return Container(
      padding: EdgeInsets.zero,
      alignment: Alignment.bottomCenter,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Layer 1: Rank 2 (Back)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              rank2Item ?? SizedBox(width: podiumWidth),
              SizedBox(width: gapWidth),
              rank3Placeholder,
            ],
          ),

          // Layer 2: Rank 1 (Middle)
          if (first != null)
            _buildPodiumItem(
              user: first,
              rank: 1,
              height: 230,
              width: podiumWidth,
              front: _p1Front,
              side: _p1Side,
              top: _p1Top,
              isFirst: true,
              showSide: true,
            ),

          // Layer 3: Rank 3 (Front)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              rank2Placeholder,
              SizedBox(width: gapWidth),
              Transform.translate(
                offset: const Offset(
                  -2,
                  0,
                ), // Slide Rank 3 independently to the right
                child: rank3Item ?? SizedBox(width: podiumWidth),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required TopUser user,
    required int rank,
    required double height,
    required double width,
    required Color front,
    required Color side,
    required Color top,
    bool isFirst = false,
    bool showSide = true,
  }) {
    const double depth = 16.0;

    return GestureDetector(
      onTap: () => _showUserDialog(user, rank),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Icon(
                Icons.emoji_events,
                color: Color(0xFFFFCC00),
                size: 36,
              ),
            ),
          if (!isFirst) SizedBox(height: isFirst ? 0 : 36),

          Container(
            width: isFirst ? 72 : 60,
            height: isFirst ? 72 : 60,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundImage: user.imgUrl.isNotEmpty
                  ? NetworkImage(user.imgUrl)
                  : null,
              backgroundColor: Colors.grey.shade300,
              child: user.imgUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
          ),

          SizedBox(
            width: width + 20,
            child: Text(
              user.firstName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${user.orderCount} Orders",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: BlockPainter(
                      front: front,
                      top: top,
                      side: side,
                      showSide: showSide,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 50, // Align to bottom to keep numbers in one line
                  left: 0,
                  width: showSide ? width - depth : width,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(-4, 0), // Shift left as requested
                      child: Text(
                        "$rank",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(List<TopUser> users, {required int startIndex}) {
    if (users.isEmpty) return const SizedBox.shrink();
    // Reduced top padding from 50 to 10 to bring ranks up
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
      child: Column(
        children: List.generate(users.length, (index) {
          final user = users[index];
          final rank = startIndex + index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildListItem(
              rank: rank,
              name: user.firstName,
              points: "${user.orderCount} Orders",
              imgUrl: user.imgUrl,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTrendsList(List<NewUser> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No trends yet!", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
      child: Column(
        children: List.generate(users.length, (index) {
          final user = users[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildListItem(
              rank: -1,
              name: user.firstName,
              points: "New",
              imgUrl: user.imgUrl,
              isTrend: true,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildListItem({
    required int rank,
    required String name,
    required String points,
    required String imgUrl,
    bool isTrend = false,
  }) {
    // Extract actual order count for dialog if needed
    // Assuming 'points' string is like "123 Pt" or "123 points"
    final rawPoints = points.replaceAll(RegExp(r'[^0-9]'), '');
    final orderCount = int.tryParse(rawPoints) ?? 0;

    return GestureDetector(
      onTap: () {
        if (!isTrend) {
          _showUserDialog(
            TopUser(
              id: 'temp',
              firstName: name,
              imgUrl: imgUrl,
              orderCount: orderCount,
            ),
            rank,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!isTrend)
              Container(
                width: 30,
                alignment: Alignment.centerLeft,
                child: Text(
                  "#$rank",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Container(
                width: 30,
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),

            // Enhanced Avatar Circle
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _bgPurple.withOpacity(0.2),
                    _cardPeach.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundImage: imgUrl.isNotEmpty
                    ? NetworkImage(imgUrl)
                    : null,
                backgroundColor: Colors.white,
                child: imgUrl.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        color: Colors.grey.shade300,
                        size: 28,
                      )
                    : null,
              ),
            ),

            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF2D3142),
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (isTrend)
                    const Text(
                      "New Joiner",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _bgPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                points,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _bgPurple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDialog(TopUser user, int rank) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large Image Section (Square aspect ratio, taking up significant space)
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    image: user.imgUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(user.imgUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey.shade200,
                  ),
                  child: user.imgUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.grey.shade400,
                        )
                      : null,
                ),
              ),

              // Compact Info Section
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16,
                ), // Reduced padding
                child: Column(
                  children: [
                    // Name (Centered)
                    Text(
                      user.firstName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D3142),
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Rank Badge (Centered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "RANK #${rank}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats (Centered)
                    Column(
                      children: [
                        Text(
                          "${user.orderCount}",
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3142),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "WEEKLY ORDERS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade400,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Centered Text Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _bgPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          "Awesome!",
                          style: TextStyle(
                            color: _bgPurple,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      key: const ValueKey('loading'),
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: _matteDark, // Matte background as requested
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_matteDark, _matteCard], // Subtle matte gradient
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _PremiumTrendLoader(), // New Premium Loader
          const SizedBox(height: 48),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: const Column(
              children: [
                Text(
                  "GATHERING TRENDS",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Curating the best for you...",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
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

  Widget _buildErrorState() {
    return Center(
      child: Text(
        _errorMessage ?? "Something went wrong",
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _PremiumTrendLoader extends StatefulWidget {
  const _PremiumTrendLoader();

  @override
  State<_PremiumTrendLoader> createState() => _PremiumTrendLoaderState();
}

class _PremiumTrendLoaderState extends State<_PremiumTrendLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(120, 120),
          painter: _SleekGraphPainter(
            animationValue: _controller.value,
            color: Colors.white,
          ),
        );
      },
    );
  }
}

class _SleekGraphPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _SleekGraphPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Create a dynamic flowing line graph
    // We'll use multiple sine waves to create an organic looking trend line
    path.moveTo(0, h * 0.8);

    for (double x = 0; x <= w; x++) {
      // Normalize x
      final nx = x / w;

      // Dynamic offset based on animation
      final offset = animationValue * 2 * math.pi;

      // Complex wave function
      final y =
          h * 0.5 +
          math.sin(nx * 2 * math.pi + offset) * (h * 0.2) +
          math.sin(nx * 4 * math.pi - offset) * (h * 0.1);

      path.lineTo(x, y);
    }

    // Draw Glow
    canvas.drawPath(path, glowPaint);
    // Draw Line
    canvas.drawPath(path, paint);

    // Draw a moving dot at the "leading edge" of the trend?
    // Let's just draw a pulsing dot at the center-ish based on the wave
    final dotX = w * 0.5;
    final dotY =
        h * 0.5 +
        math.sin(0.5 * 2 * math.pi + animationValue * 2 * math.pi) * (h * 0.2) +
        math.sin(0.5 * 4 * math.pi - animationValue * 2 * math.pi) * (h * 0.1);

    canvas.drawCircle(Offset(dotX, dotY), 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(dotX, dotY),
      12 + (math.sin(animationValue * 4 * math.pi) * 4),
      Paint()..color = Colors.white.withOpacity(0.2),
    );
  }

  @override
  bool shouldRepaint(covariant _SleekGraphPainter oldDelegate) => true;
}

class BlockPainter extends CustomPainter {
  final Color front;
  final Color top;
  final Color side;
  final bool showSide;

  BlockPainter({
    required this.front,
    required this.top,
    required this.side,
    this.showSide = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const double d = 16.0;

    final Paint paintFront = Paint()..color = front;
    final Paint paintTop = Paint()..color = top;
    final Paint paintSide = Paint()..color = side;

    final double fWidth = showSide ? w - d : w;

    final pathFront = Path()
      ..moveTo(0, d)
      ..lineTo(fWidth, d)
      ..lineTo(fWidth, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(pathFront, paintFront);

    final pathTop = Path()
      ..moveTo(0, d)
      ..lineTo(d, 0)
      ..lineTo(fWidth + d, 0)
      ..lineTo(fWidth, d)
      ..close();
    canvas.drawPath(pathTop, paintTop);

    if (showSide) {
      final pathSide = Path()
        ..moveTo(fWidth, d)
        ..lineTo(fWidth + d, 0)
        ..lineTo(w, h - d)
        ..lineTo(fWidth, h)
        ..close();
      canvas.drawPath(pathSide, paintSide);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
