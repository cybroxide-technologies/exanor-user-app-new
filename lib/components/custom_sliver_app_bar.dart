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
      backgroundColor: isDarkMode
          ? _hexToColor(FirebaseRemoteConfigService.getThemeGradientDarkStart())
          : _hexToColor(
              FirebaseRemoteConfigService.getThemeGradientLightStart(),
            ), // Match gradient start
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: RepaintBoundary(
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
                        ),
                        _hexToColor(
                          FirebaseRemoteConfigService.getThemeGradientLightStart(),
                        ), // Solid Blue to match top
                      ],
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
                    // Top row with location and actions
                    Row(
                      children: [
                        // Location icon and text
                        Icon(
                          Icons.location_on,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              // Navigate to SavedAddressesScreen
                              final result =
                                  await Navigator.push<Map<String, dynamic>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SavedAddressesScreen(),
                                    ),
                                  );

                              // If address was selected, call the callback to refresh
                              if (result != null &&
                                  result['addressSelected'] == true &&
                                  onAddressUpdated != null) {
                                onAddressUpdated!();
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    TranslatedText(
                                      addressTitle ?? 'Set Location',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: theme.colorScheme.onSurface,
                                      size: 20,
                                    ),
                                  ],
                                ),
                                TranslatedText(
                                  _buildAddressExcerpt(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Action icons
                        GestureDetector(
                          onTap: () async {
                            // Navigate to Profile screen
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MyProfileScreen(),
                              ),
                            );
                            // Refresh user data after returning from profile
                            if (onUserDataUpdated != null) {
                              onUserDataUpdated!();
                            }
                          },
                          child: isLoadingUserData
                              ? Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey[300],
                                  ),
                                )
                              : CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.orange,
                                  backgroundImage:
                                      userImgUrl != null &&
                                          userImgUrl!.isNotEmpty
                                      ? NetworkImage(userImgUrl!)
                                      : null,
                                  child:
                                      userImgUrl == null || userImgUrl!.isEmpty
                                      ? TranslatedText(
                                          userName?.isNotEmpty == true
                                              ? userName!
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                        ),
                        // Language Selector
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            // Show language selector
                            showLanguageSelector(context);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.surface,
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.3,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withOpacity(
                                    0.1,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.translate,
                              color: theme.colorScheme.primary,
                              size: 20,
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

    // Glassmorphism effect
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
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
                      ),
                      Colors.white,
                    ],
              stops: const [0.0, 1.0],
            ),
          ),
          // Add top padding dynamically to avoid status bar overlap
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
  double get maxExtent => 145.0 + topPadding; // Tighter spacing

  @override
  double get minExtent => 108.0 + topPadding; // Search (58) + Chips (34) + spacing

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
          // Search Bar (Always visible)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GlobalSearchScreen(),
                  ),
                );
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : theme.colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Icon(
                      Icons.search,
                      color: isDarkMode ? Colors.grey[400] : Colors.black87,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    TranslatedText(
                      'Search "Exanor"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode
                            ? Colors.grey[400]
                            : Colors.grey.shade600,
                        fontSize: 16,
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
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : const Color(0xFFFFF0EC),
                        ),
                        child: Icon(
                          Icons.mic_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
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
                              horizontal: 16,
                              vertical: 8,
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
                : // Expanded Layout (Bubbles)
                  _isLoading
                ? const CategorySkeleton()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => SizedBox(width: 12.0),
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
                            width: 70.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Standard Bubble
                                Container(
                                  height: 52.0,
                                  width: 52.0,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: theme.colorScheme.primary,
                                            width: 2,
                                          )
                                        : Border.all(
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.transparent,
                                            width: 1,
                                          ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      category['category_icon'] ?? '',
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) => Icon(
                                        Icons.category_outlined,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        size: 24.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TranslatedText(
                                  category['category_name'] ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 11.0,
                                    letterSpacing: 0.2,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
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
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (e) {
    return Colors.transparent;
  }
}
