import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:exanor/components/voice_search_sheet.dart';
import 'package:exanor/screens/saved_addresses_screen.dart';
import 'package:exanor/screens/my_profile_screen.dart';

import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/api_service.dart';

import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/language_selector.dart';

import 'dart:ui';
import 'dart:math' as math;
import 'package:exanor/screens/global_search_screen.dart';
import 'package:exanor/components/home_screen_skeleton.dart';

class CustomSliverAppBar extends StatelessWidget {
  final String? addressTitle;
  final String? addressSubtitle;
  final String? addressArea;
  final String? addressCity;
  final Function(Map<String, dynamic>?)? onAddressUpdated;
  final VoidCallback? onUserDataUpdated;
  final VoidCallback? onTabsRefresh;
  final VoidCallback? onRefreshNeeded;
  final Function(String, String?, String?)? onSubCategorySelected;
  final String? userImgUrl;
  final String? userImage; // Added for HomeScreen compatibility
  final String? userName;
  final bool isLoadingUserData;

  const CustomSliverAppBar({
    super.key,
    this.addressTitle,
    this.addressSubtitle,
    this.addressArea,
    this.addressCity,
    this.onAddressUpdated,
    this.onUserDataUpdated,
    this.onTabsRefresh,
    this.onRefreshNeeded,
    this.onSubCategorySelected,
    this.userImgUrl,
    this.userImage,
    this.userName,
    this.isLoadingUserData = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 70.0, // Increased to fix 9px overflow
      toolbarHeight: 56.0,
      floating: false,
      pinned: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      stretch: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        background: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate opacity to fade out content as it collapses
            // expandedHeight is 70, toolbarHeight is 56.
            // We fade from 1.0 to 0.0 as it shrinks from 70 to 56.
            final double currentHeight = constraints.maxHeight;
            final double opacity = ((currentHeight - 56.0) / (70.0 - 56.0))
                .clamp(0.0, 1.0);

            return Opacity(
              opacity: opacity,
              child: RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDarkMode
                          ? [
                              _hexToColor(
                                FirebaseRemoteConfigService.getThemeGradientDarkStart(),
                              ),
                              _hexToColor(
                                FirebaseRemoteConfigService.getThemeGradientDarkEnd(),
                              ),
                            ]
                          : [
                              _hexToColor(
                                FirebaseRemoteConfigService.getThemeGradientLightStart(),
                              ).withOpacity(0.12), // Unified strong tint
                              _hexToColor(
                                FirebaseRemoteConfigService.getThemeGradientLightStart(),
                              ).withOpacity(0.12), // Consistent opacity
                            ],
                      stops: isDarkMode ? null : const [0.0, 1.0],
                    ),
                  ),
                  child: const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: 12.0,
                        bottom: 0.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Content moved to Sticky Header
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class StoreCategoriesDelegate extends SliverPersistentHeaderDelegate {
  final Function(String) onCategorySelected;
  final String selectedCategoryId;
  final double topPadding;

  final String? userImgUrl;
  final String? userImage;
  final String? userName;
  final bool isLoadingUserData;
  final VoidCallback? onUserDataUpdated;

  final String? addressTitle;
  final String? addressSubtitle;
  final Function(Map<String, dynamic>?)? onAddressUpdated;
  final int categoryRefreshTrigger;

  const StoreCategoriesDelegate({
    required this.onCategorySelected,
    required this.selectedCategoryId,
    required this.topPadding,
    this.userImgUrl,
    this.userImage,
    this.userName,
    this.isLoadingUserData = false,
    this.onUserDataUpdated,
    this.addressTitle,
    this.addressSubtitle,
    this.onAddressUpdated,
    this.categoryRefreshTrigger = 0,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Calculate shrink percentage
    // We want the content to resize as we scroll.
    // When shrinkOffset increases, we are scrolling down.
    final double shrinkPercentage = (shrinkOffset / (maxExtent - minExtent))
        .clamp(0.0, 1.0);

    // Solid background with subtle tint
    // Solid background with subtle tint
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? _hexToColor(
                  FirebaseRemoteConfigService.getThemeGradientDarkStart(),
                )
              : Colors.white,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(15),
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.6)
                  : Colors.black.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 12),
              spreadRadius: -5,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [
                      _hexToColor(
                        FirebaseRemoteConfigService.getThemeGradientDarkStart(),
                      ),
                      _hexToColor(
                        FirebaseRemoteConfigService.getThemeGradientDarkEnd(),
                      ),
                    ]
                  : [
                      _hexToColor(
                        FirebaseRemoteConfigService.getThemeGradientLightStart(),
                      ).withOpacity(
                        0.35,
                      ), // Increased opacity for "immersive light"
                      _hexToColor(
                        FirebaseRemoteConfigService.getThemeGradientLightStart(),
                      ).withOpacity(0.0), // Fades beautifully to transparent
                    ],
              stops: const [0.0, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  child: AnimatedSnowfall(isDark: isDarkMode),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: StoreCategoriesWidget(
                  onCategorySelected: onCategorySelected,
                  selectedCategoryId: selectedCategoryId,
                  shrinkPercentage: shrinkPercentage,
                  userImgUrl: userImgUrl,
                  userImage: userImage,
                  userName: userName,
                  isLoadingUserData: isLoadingUserData,
                  onUserDataUpdated: onUserDataUpdated,
                  addressTitle: addressTitle,
                  addressSubtitle: addressSubtitle,
                  onAddressUpdated: onAddressUpdated,
                  categoryRefreshTrigger: categoryRefreshTrigger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 225.0 + topPadding; // Optimized to remove excess whitespace

  @override
  double get minExtent => 115.0 + topPadding; // Reduced to tighten space when collapsed

  @override
  bool shouldRebuild(covariant StoreCategoriesDelegate oldDelegate) {
    return oldDelegate.selectedCategoryId != selectedCategoryId ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.isLoadingUserData != isLoadingUserData ||
        oldDelegate.userName != userName ||
        oldDelegate.userImage != userImage ||
        oldDelegate.addressTitle != addressTitle ||
        oldDelegate.addressSubtitle != addressSubtitle ||
        oldDelegate.categoryRefreshTrigger != categoryRefreshTrigger;
  }
}

class StoreCategoriesWidget extends StatefulWidget {
  final Function(String) onCategorySelected;
  final String selectedCategoryId;
  final double shrinkPercentage;

  final String? userImgUrl;
  final String? userImage;
  final String? userName;
  final bool isLoadingUserData;
  final VoidCallback? onUserDataUpdated;

  final String? addressTitle;
  final String? addressSubtitle;
  final Function(Map<String, dynamic>?)? onAddressUpdated;
  final int categoryRefreshTrigger;

  const StoreCategoriesWidget({
    super.key,
    required this.onCategorySelected,
    required this.selectedCategoryId,
    this.shrinkPercentage = 0.0,
    this.userImgUrl,
    this.userImage,
    this.userName,
    this.isLoadingUserData = false,
    this.onUserDataUpdated,
    this.addressTitle,
    this.addressSubtitle,
    this.onAddressUpdated,
    this.categoryRefreshTrigger = 0,
  });

  @override
  State<StoreCategoriesWidget> createState() => _StoreCategoriesWidgetState();
}

class _StoreCategoriesWidgetState extends State<StoreCategoriesWidget> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void didUpdateWidget(StoreCategoriesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryRefreshTrigger != widget.categoryRefreshTrigger) {
      _fetchCategories();
    }
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.post(
        '/store-categories/',
        body: {'query': {}},
        useBearerToken: true,
      );

      if (!mounted) return;

      if (response['data'] != null && response['data']['status'] == 200) {
        final List<dynamic> data = response['data']['response'] ?? [];

        setState(() {
          _categories = data.map((e) => e as Map<String, dynamic>).toList();

          // Add "All" category at index 0
          _categories.insert(0, {
            'id': 'all',
            'category_name': 'All',
            'category_icon':
                'https://exanor-production-media.s3.ap-south-1.amazonaws.com/exanor-default-assest/store_default_icon.png',
          });

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching categories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Bar (Always visible)
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top:
                  12.0 -
                  (8.0 * widget.shrinkPercentage).clamp(
                    0.0,
                    8.0,
                  ), // Moves up when pinned
              bottom: 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Row: Address + Action Buttons
                // Collapsible section
                Container(
                  height:
                      54.0 * (1.0 - widget.shrinkPercentage).clamp(0.0, 1.0),
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: Opacity(
                    opacity: (1.0 - (widget.shrinkPercentage * 3.0)).clamp(
                      0.0,
                      1.0,
                    ),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6), // Spacing
                        child: Row(
                          children: [
                            // Address Widget (Expanded to take available space)
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final result =
                                      await Navigator.push<
                                        Map<String, dynamic>
                                      >(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SavedAddressesScreen(),
                                        ),
                                      );

                                  if (result != null &&
                                      result['addressSelected'] == true &&
                                      widget.onAddressUpdated != null) {
                                    widget.onAddressUpdated!(result);
                                  }
                                },
                                child: Container(
                                  color: Colors.transparent,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_rounded,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: TranslatedText(
                                              widget.addressTitle ?? 'Home',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18, // Larger title
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: theme.colorScheme.onSurface,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                      if (widget.addressSubtitle != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 26.0,
                                          ),
                                          child: Text(
                                            widget.addressSubtitle!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.6),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Action Buttons (Language + Profile)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Language Button
                                GestureDetector(
                                  onTap: () {
                                    showLanguageSelector(context);
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.white,
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.white.withOpacity(0.5),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.translate_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Profile Button
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const MyProfileScreen(),
                                      ),
                                    );
                                    if (widget.onUserDataUpdated != null) {
                                      widget.onUserDataUpdated!();
                                    }
                                  },
                                  child: widget.isLoadingUserData
                                      ? Shimmer.fromColors(
                                          baseColor: Colors.grey[800]!,
                                          highlightColor: Colors.grey[700]!,
                                          child: const CircleAvatar(radius: 20),
                                        )
                                      : Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Builder(
                                            builder: (context) {
                                              final imageUrl =
                                                  (widget.userImage != null &&
                                                      widget
                                                          .userImage!
                                                          .isNotEmpty)
                                                  ? widget.userImage
                                                  : (widget.userImgUrl !=
                                                            null &&
                                                        widget
                                                            .userImgUrl!
                                                            .isNotEmpty)
                                                  ? widget.userImgUrl
                                                  : null;

                                              return CircleAvatar(
                                                backgroundColor:
                                                    theme.colorScheme.primary,
                                                backgroundImage:
                                                    imageUrl != null
                                                    ? NetworkImage(imageUrl)
                                                    : null,
                                                onBackgroundImageError:
                                                    imageUrl != null
                                                    ? (exception, stackTrace) {
                                                        debugPrint(
                                                          'Profile image failed to load: $exception',
                                                        );
                                                      }
                                                    : null,
                                                child: imageUrl == null
                                                    ? const Icon(
                                                        Icons.person_rounded,
                                                        color: Colors.white,
                                                        size: 24,
                                                      )
                                                    : null,
                                              );
                                            },
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Collapse this spacing as we scroll up
                SizedBox(
                  height:
                      10.0 * (1.0 - widget.shrinkPercentage).clamp(0.0, 1.0),
                ),

                // 2. Search Bar (Full Width) - Wrapped with shadow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.6)
                            : const Color(0xFF1F4C6B).withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GlobalSearchScreen(),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 46, // Reduced height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black.withOpacity(0.6)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Icon(
                                CupertinoIcons.search,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : const Color(
                                        0xFF8E8E93,
                                      ), // iOS System Grey for a premium look
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              TranslatedText(
                                'Search \"Exanor\"',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode
                                      ? Colors.grey[300]!.withOpacity(0.6)
                                      : const Color(
                                          0xFF1F4C6B,
                                        ).withOpacity(0.5),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () async {
                                  final result =
                                      await showModalBottomSheet<String>(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) =>
                                            const VoiceSearchSheet(),
                                      );
                                  if (result != null && result.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            GlobalSearchScreen(
                                              initialQuery: result,
                                            ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  height: 36,
                                  width: 36,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.mic_rounded,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.9)
                                        : const Color(0xFF1F4C6B),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: 8.0 * (1.0 - widget.shrinkPercentage).clamp(0.0, 1.0),
                ),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                // 1. Expanded Layout (Compact Bubbles) - Fades OUT
                Opacity(
                  opacity: (1.0 - widget.shrinkPercentage * 2.0).clamp(
                    0.0,
                    1.0,
                  ),
                  child: IgnorePointer(
                    ignoring: widget.shrinkPercentage > 0.5,
                    child: _isLoading
                        ? const CategorySkeleton()
                        : MediaQuery.removePadding(
                            context: context,
                            removeTop: true,
                            removeBottom: true,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 16.0),
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final categoryId = category['id'];
                                final isSelected =
                                    categoryId == widget.selectedCategoryId ||
                                    (widget.selectedCategoryId.isEmpty &&
                                        categoryId == 'all');

                                return Center(
                                  child: GestureDetector(
                                    onTap: () => widget.onCategorySelected(
                                      categoryId == 'all' ? '' : categoryId,
                                    ),
                                    child: SizedBox(
                                      width: 56.0,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            height: 44.0,
                                            width: 44.0,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? theme.colorScheme.surface
                                                  : (isDarkMode
                                                        ? const Color(
                                                            0xFF2C2C2C,
                                                          )
                                                        : const Color(
                                                            0xFFF7F7F9,
                                                          )),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(
                                                        isDarkMode ? 0.2 : 0.08,
                                                      ),
                                                  blurRadius: 1.5,
                                                  offset: Offset.zero,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.network(
                                                category['category_icon'] ?? '',
                                                fit: BoxFit.contain,
                                                errorBuilder: (c, e, s) => Icon(
                                                  Icons.grid_view_rounded,
                                                  color: isSelected
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.5),
                                                  size: 20.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            style: TextStyle(
                                              fontFamily: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.fontFamily,
                                              color: isSelected
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontSize: 10.0,
                                              letterSpacing: 0.1,
                                              height: 1.1,
                                            ),
                                            child: Text(
                                              category['category_name'] ?? '',
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),

                // 2. Compact Layout (Chips) - Fades IN
                Opacity(
                  opacity: (widget.shrinkPercentage * 2.0 - 1.0).clamp(
                    0.0,
                    1.0,
                  ),
                  child: IgnorePointer(
                    ignoring: widget.shrinkPercentage <= 0.5,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 50, // Fixed height for chips container
                        padding: const EdgeInsets.only(
                          bottom: 10,
                        ), // Added bottom padding
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          removeBottom: true,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final categoryId = category['id'];
                              final isSelected =
                                  categoryId == widget.selectedCategoryId ||
                                  (widget.selectedCategoryId.isEmpty &&
                                      categoryId == 'all');

                              return Center(
                                child: GestureDetector(
                                  onTap: () => widget.onCategorySelected(
                                    categoryId == 'all' ? '' : categoryId,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDarkMode
                                                ? Colors.white
                                                : Colors.black)
                                          : (isDarkMode
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.white.withOpacity(
                                                    0.5,
                                                  )),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.transparent
                                            : Colors.black.withOpacity(0.05),
                                      ),
                                    ),
                                    child: TranslatedText(
                                      category['category_name'] ?? '',
                                      style: TextStyle(
                                        color: isSelected
                                            ? (isDarkMode
                                                  ? Colors.black
                                                  : Colors.white)
                                            : (isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
}

Color _hexToColor(String hex) {
  try {
    String cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    return Color(int.parse('0x$cleanHex'));
  } catch (e) {
    return Colors.transparent;
  }
}

class Snowflake {
  double x;
  double y;
  double radius;
  double speed;
  double rotation;
  double rotationSpeed;
  double opacity;

  Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.opacity,
  });
}

class AnimatedSnowfall extends StatefulWidget {
  final bool isDark;

  const AnimatedSnowfall({super.key, required this.isDark});

  @override
  State<AnimatedSnowfall> createState() => _AnimatedSnowfallState();
}

class _AnimatedSnowfallState extends State<AnimatedSnowfall>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Snowflake> _snowflakes = [];
  final math.Random _random = math.Random();
  // removed unused _lastSize

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // Driving the animation loop
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initSnowflakes(Size size) {
    _snowflakes.clear();
    // Create ~20 flakes for good density
    for (int i = 0; i < 20; i++) {
      _snowflakes.add(_createSnowflake(size, initial: true));
    }
  }

  Snowflake _createSnowflake(Size size, {bool initial = false}) {
    // Random radius: 4 to 10
    double radius = _random.nextDouble() * 6 + 4;

    // Speed: 0.2 to 1.0
    double speed = _random.nextDouble() * 0.8 + 0.2;

    double x;
    double y;
    int attempts = 0;

    // Attempt to find a position not too close to others
    do {
      x = _random.nextDouble() * size.width;
      if (initial) {
        y = _random.nextDouble() * size.height;
      } else {
        // Start above the screen
        y = -radius * 2 - _random.nextDouble() * 50;
      }

      bool tooClose = false;
      for (var s in _snowflakes) {
        final dist = (Offset(s.x, s.y) - Offset(x, y)).distance;
        if (dist < radius * 5) {
          // Ensure decent spacing
          tooClose = true;
          break;
        }
      }
      if (!tooClose) break;
      attempts++;
    } while (attempts < 10);

    return Snowflake(
      x: x,
      y: y,
      radius: radius,
      speed: speed,
      rotation: _random.nextDouble() * 2 * math.pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.05,
      opacity: _random.nextDouble() * 0.5 + 0.2, // 0.2 to 0.7
    );
  }

  void _updateSnowflakes(Size size) {
    if (_snowflakes.isEmpty) {
      _initSnowflakes(size);
      return;
    }

    for (var s in _snowflakes) {
      s.y += s.speed;
      s.rotation += s.rotationSpeed;
      s.x += math.sin(s.y * 0.02) * 0.3; // Gentle sway

      // Reset if below screen
      if (s.y > size.height + s.radius * 2) {
        var newFlake = _createSnowflake(size, initial: false);
        s.x = newFlake.x;
        s.y = newFlake.y;
        s.speed = newFlake.speed;
        s.radius = newFlake.radius;
        s.opacity = newFlake.opacity;
        s.rotation = newFlake.rotation;
        s.rotationSpeed = newFlake.rotationSpeed;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Fix: Only init if empty. Do NOT re-init on size change (scrolling).
        if (_snowflakes.isEmpty && size.width > 0 && size.height > 0) {
          _initSnowflakes(size);
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            _updateSnowflakes(size);
            return CustomPaint(
              painter: SnowflakePainter(
                snowflakes: _snowflakes,
                isDark: widget.isDark,
              ),
              size: size,
            );
          },
        );
      },
    );
  }
}

class SnowflakePainter extends CustomPainter {
  final List<Snowflake> snowflakes;
  final bool isDark;

  SnowflakePainter({required this.snowflakes, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var s in snowflakes) {
      paint.color = (isDark ? Colors.white : Colors.white).withOpacity(
        (isDark ? 0.3 : 0.6) *
            s.opacity, // Adjust base opacity by flake opacity
      );
      // Use flake's radius
      _drawDetailedSnowflake(
        canvas,
        Offset(s.x, s.y),
        s.radius,
        paint,
        s.rotation,
      );
    }
  }

  void _drawDetailedSnowflake(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
    double rotation,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    for (int i = 0; i < 6; i++) {
      _drawBranch(canvas, radius, paint);
      canvas.rotate(math.pi / 3);
    }
    canvas.restore();
  }

  void _drawBranch(Canvas canvas, double length, Paint paint) {
    canvas.drawLine(Offset.zero, Offset(0, -length), paint);

    // V-shapes
    double v1Pos = length * 0.45;
    double v1Len = length * 0.3;
    _drawV(canvas, 0, -v1Pos, v1Len, paint);

    double v2Pos = length * 0.75;
    double v2Len = length * 0.25;
    _drawV(canvas, 0, -v2Pos, v2Len, paint);
  }

  void _drawV(Canvas canvas, double x, double y, double len, Paint paint) {
    canvas.save();
    canvas.translate(x, y);

    canvas.save();
    canvas.rotate(-math.pi / 3.5);
    canvas.drawLine(Offset.zero, Offset(0, -len), paint);
    canvas.restore();

    canvas.save();
    canvas.rotate(math.pi / 3.5);
    canvas.drawLine(Offset.zero, Offset(0, -len), paint);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
