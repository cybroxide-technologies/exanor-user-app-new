import 'package:flutter/material.dart';
import 'package:exanor/components/voice_search_sheet.dart';
import 'package:exanor/screens/saved_addresses_screen.dart';
import 'package:exanor/screens/my_profile_screen.dart';

import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/api_service.dart';

import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/language_selector.dart';

import 'dart:ui';
import 'package:exanor/screens/global_search_screen.dart';
import 'package:exanor/components/home_screen_skeleton.dart';

class CustomSliverAppBar extends StatelessWidget {
  final String? addressTitle;
  final String? addressSubtitle;
  final String? addressArea;
  final String? addressCity;
  final VoidCallback? onAddressUpdated;
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
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(
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
  final VoidCallback? onAddressUpdated;

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
                      ).withOpacity(0.12),
                      Colors.white,
                    ],
              stops: const [0.0, 1.0],
            ),
          ),
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
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 225.0 + topPadding; // Optimized to remove excess whitespace

  @override
  double get minExtent => 134.0 + topPadding; // Increased to add bottom padding when collapsed

  @override
  bool shouldRebuild(covariant StoreCategoriesDelegate oldDelegate) {
    return oldDelegate.selectedCategoryId != selectedCategoryId ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.isLoadingUserData != isLoadingUserData ||
        oldDelegate.userName != userName ||
        oldDelegate.userImage != userImage ||
        oldDelegate.addressTitle != addressTitle ||
        oldDelegate.addressSubtitle != addressSubtitle;
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
  final VoidCallback? onAddressUpdated;

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

  Future<void> _fetchCategories() async {
    if (!mounted) return;

    // Forced delay to visualize skeleton
    await Future.delayed(const Duration(seconds: 2));

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
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12, // Restored breathing room
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
                                    widget.onAddressUpdated!();
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
                                          child: CircleAvatar(
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            backgroundImage:
                                                (widget.userImage != null &&
                                                        widget
                                                            .userImage!
                                                            .isNotEmpty) ||
                                                    (widget.userImgUrl !=
                                                            null &&
                                                        widget
                                                            .userImgUrl!
                                                            .isNotEmpty)
                                                ? NetworkImage(
                                                    widget.userImage ??
                                                        widget.userImgUrl!,
                                                  )
                                                : null,
                                            child:
                                                (widget.userImage == null ||
                                                        widget
                                                            .userImage!
                                                            .isEmpty) &&
                                                    (widget.userImgUrl ==
                                                            null ||
                                                        widget
                                                            .userImgUrl!
                                                            .isEmpty)
                                                ? TranslatedText(
                                                    widget
                                                                .userName
                                                                ?.isNotEmpty ==
                                                            true
                                                        ? widget.userName!
                                                              .substring(0, 1)
                                                              .toUpperCase()
                                                        : 'U',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  )
                                                : null,
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

                // Removed SizedBox(height: 12) from here to reduce gap when expanded
                // The gap is now enforced by the Search Bar's top padding or the layout above
                const SizedBox(height: 10),

                // 2. Search Bar (Full Width)
                GestureDetector(
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
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.25)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode
                                  ? Colors.black.withOpacity(0.1)
                                  : const Color(
                                      0xFF1F4C6B,
                                    ).withOpacity(0.08), // Subtle bluish shadow
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
                              color: isDarkMode
                                  ? Colors.grey[300]!.withOpacity(0.8)
                                  : const Color(
                                      0xFF1F4C6B,
                                    ).withOpacity(0.6), // Use brand color
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            TranslatedText(
                              'Search "Exanor"',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDarkMode
                                    ? Colors.grey[300]!.withOpacity(0.6)
                                    : const Color(0xFF1F4C6B).withOpacity(0.5),
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
                                      builder: (context) => GlobalSearchScreen(
                                        initialQuery: result,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                height: 40,
                                width: 40,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.white.withOpacity(0.4),
                                ),
                                child: Icon(
                                  Icons.mic_rounded,
                                  color: isDarkMode
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

                const SizedBox(height: 8), // Reduced spacing before Categories
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
                                  SizedBox(width: 16.0),
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
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: theme
                                                            .colorScheme
                                                            .shadow
                                                            .withOpacity(0.05),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ]
                                                  : null,
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
                        padding: EdgeInsets.only(
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
          // Cinematic Fade Line
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
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
