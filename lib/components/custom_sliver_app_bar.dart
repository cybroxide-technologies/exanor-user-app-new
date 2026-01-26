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

  String _buildAddressExcerpt() {
    if (addressSubtitle == null) {
      return 'Set your location by clicking here.';
    }

    // Build excerpt with address subtitle + area/city context
    List<String> excerptParts = [addressSubtitle!];

    // Add area and city for additional context, avoiding duplicates
    if (addressArea != null &&
        addressArea!.isNotEmpty &&
        !addressSubtitle!.toLowerCase().contains(addressArea!.toLowerCase())) {
      excerptParts.add(addressArea!);
    }

    if (addressCity != null &&
        addressCity!.isNotEmpty &&
        !addressSubtitle!.toLowerCase().contains(addressCity!.toLowerCase()) &&
        (addressArea == null ||
            !addressArea!.toLowerCase().contains(addressCity!.toLowerCase()))) {
      excerptParts.add(addressCity!);
    }

    String fullExcerpt = excerptParts.join(', ');

    // Truncate if too long (keep under ~50 characters for mobile display)
    if (fullExcerpt.length > 50) {
      return '${fullExcerpt.substring(0, 47)}...';
    }

    return fullExcerpt;
  }

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
                        top: 12.0, // Increased top padding
                        bottom: 0.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row with refined layout - Standalone Icon & Consistent Buttons
                          Row(
                            children: [
                              // 1. Address Section (Expanded)
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
                                        onAddressUpdated != null) {
                                      onAddressUpdated!();
                                    }
                                  },
                                  child: Container(
                                    color:
                                        Colors.transparent, // Hit test target
                                    child: Row(
                                      children: [
                                        // Standalone Location Icon (No Box)
                                        Icon(
                                          Icons.location_on_rounded,
                                          color: theme.colorScheme.primary,
                                          size:
                                              32, // Slightly larger to stand out without box
                                        ),
                                        const SizedBox(width: 8),

                                        // Text Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              // Title Row
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: TranslatedText(
                                                      addressTitle ??
                                                          'Set Location',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface,
                                                        height: 1.1,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              // Subtitle
                                              TranslatedText(
                                                _buildAddressExcerpt(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.7),
                                                  letterSpacing: 0,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 2. Actions Row (Language + Profile)
                              // Wrapped in a Row to keep them tight
                              Row(
                                children: [
                                  // Language Button
                                  GestureDetector(
                                    onTap: () {
                                      showLanguageSelector(context);
                                    },
                                    child: Container(
                                      width: 44, // Fixed consistent size
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.white,
                                        border: Border.all(
                                          color: isDarkMode
                                              ? Colors.white.withOpacity(0.1)
                                              : Colors.grey.withOpacity(0.2),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.translate_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 20,
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
                                      if (onUserDataUpdated != null) {
                                        onUserDataUpdated!();
                                      }
                                    },
                                    child: isLoadingUserData
                                        ? Shimmer.fromColors(
                                            baseColor: Colors.grey[800]!,
                                            highlightColor: Colors.grey[700]!,
                                            child: const CircleAvatar(
                                              radius: 22,
                                            ),
                                          )
                                        : Container(
                                            width: 44, // Matched size
                                            height: 44,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors
                                                    .white, // Clean white border acting as a ring
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              backgroundColor:
                                                  theme.colorScheme.primary,
                                              backgroundImage:
                                                  (userImage != null &&
                                                          userImage!
                                                              .isNotEmpty) ||
                                                      (userImgUrl != null &&
                                                          userImgUrl!
                                                              .isNotEmpty)
                                                  ? NetworkImage(
                                                      userImage ?? userImgUrl!,
                                                    )
                                                  : null,
                                              child:
                                                  (userImage == null ||
                                                          userImage!.isEmpty) &&
                                                      (userImgUrl == null ||
                                                          userImgUrl!.isEmpty)
                                                  ? TranslatedText(
                                                      userName?.isNotEmpty ==
                                                              true
                                                          ? userName!
                                                                .substring(0, 1)
                                                                .toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
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

  const StoreCategoriesDelegate({
    required this.onCategorySelected,
    required this.selectedCategoryId,
    required this.topPadding,
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
          padding: EdgeInsets.only(top: topPadding * shrinkPercentage),
          child: StoreCategoriesWidget(
            onCategorySelected: onCategorySelected,
            selectedCategoryId: selectedCategoryId,
            shrinkPercentage: shrinkPercentage,
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 128.0 + topPadding; // Enough room for natural scrolling transition

  @override
  double get minExtent => 122.0 + topPadding; // Compact frozen state at top

  @override
  bool shouldRebuild(covariant StoreCategoriesDelegate oldDelegate) {
    return oldDelegate.selectedCategoryId != selectedCategoryId ||
        oldDelegate.topPadding != topPadding;
  }
}

class StoreCategoriesWidget extends StatefulWidget {
  final Function(String) onCategorySelected;
  final String selectedCategoryId;
  final double shrinkPercentage;

  const StoreCategoriesWidget({
    super.key,
    required this.onCategorySelected,
    required this.selectedCategoryId,
    this.shrinkPercentage = 0.0,
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
          // Separator Line between Header and Search (only visible at top)
          // Dotted Separator Line with fade effect
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity:
                1.0 - widget.shrinkPercentage, // Fades out as you scroll down
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CustomPaint(
                size: const Size(double.infinity, 1),
                painter: _DashedLinePainter(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),
          // Search Bar (Always visible)
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16, // Increased top padding
              bottom: 4,
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
                        const SizedBox(width: 20),
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
                            final result = await showModalBottomSheet<String>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const VoiceSearchSheet(),
                            );
                            if (result != null && result.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GlobalSearchScreen(initialQuery: result),
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
          ),

          Expanded(
            child: widget.shrinkPercentage > 0.5
                ? // Compact Layout (Chips)
                  ListView.separated(
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
                                  ? (isDarkMode ? Colors.white : Colors.black)
                                  : (isDarkMode
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.5)),
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
                                    ? (isDarkMode ? Colors.black : Colors.white)
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
                  )
                : // Expanded Layout (Compact Bubbles)
                  _isLoading
                ? const CategorySkeleton()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ), // Minimal vertical padding
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => SizedBox(
                      width: 16.0,
                    ), // More breathing room but tighter items
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
                            width: 56.0, // Tighter width for elegance
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Elegant Minimal Bubble
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves
                                      .easeOutCubic, // Smooth, refined animation
                                  height: 44.0, // Reduced from 52
                                  width: 44.0,
                                  padding: const EdgeInsets.all(
                                    8,
                                  ), // Tighter padding
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.surface
                                        : (isDarkMode
                                              ? const Color(0xFF2C2C2C)
                                              : const Color(0xFFF7F7F9)),
                                    borderRadius: BorderRadius.circular(
                                      14,
                                    ), // Elegant soft square
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      width: 1.5, // Thin, precise border
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            // Very subtle lift for selected only
                                            BoxShadow(
                                              color: theme.colorScheme.shadow
                                                  .withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      category['category_icon'] ?? '',
                                      fit: BoxFit.contain,
                                      // Minimalist: Don't tint icons, trust the asset quality.
                                      // If user insists on tint, we can re-add, but minimal means clean assets.
                                      errorBuilder: (c, e, s) => Icon(
                                        Icons.grid_view_rounded,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurfaceVariant
                                                  .withOpacity(0.5),
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6), // Tighter spacing
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontFamily:
                                        theme.textTheme.bodyMedium?.fontFamily,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme
                                              .colorScheme
                                              .onSurface, // Standard text color
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 10.0, // Small, clean font
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

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dashWidth = 1.0;
    const dashSpace = 5.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
