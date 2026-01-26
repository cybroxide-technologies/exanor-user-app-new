import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/screens/location_selection_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/enhanced_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _filteredAddresses = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Track extended cards
  final Set<String> _expandedCards = <String>{};

  // Enhanced translation service
  final EnhancedTranslationService _enhancedTranslation =
      EnhancedTranslationService.instance;

  // Animation Controllers
  late AnimationController _entryAnimationController;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _entryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchAddresses();
    _searchController.addListener(_onSearchChanged);
    _entryAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _entryAnimationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterAddresses(_searchController.text);
  }

  void _filterAddresses(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAddresses = List.from(_addresses);
      } else {
        _filteredAddresses = _addresses.where((address) {
          final searchText = query.toLowerCase();

          final addressName = (address['address_name'] ?? '')
              .toString()
              .toLowerCase();
          final attendeeName = (address['attendee_name'] ?? '')
              .toString()
              .toLowerCase();
          final addressLine1 = (address['address_line_1'] ?? '')
              .toString()
              .toLowerCase();
          final area = (address['area'] ?? '').toString().toLowerCase();
          final city = (address['city'] ?? '').toString().toLowerCase();
          final pincode = (address['pincode'] ?? 0).toString();

          return addressName.contains(searchText) ||
              attendeeName.contains(searchText) ||
              addressLine1.contains(searchText) ||
              area.contains(searchText) ||
              city.contains(searchText) ||
              pincode.contains(searchText);
        }).toList();
      }
    });
  }

  Future<void> _fetchAddresses() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await ApiService.post(
        '/user-address/',
        body: {"query": {}},
        useBearerToken: true,
      );

      if (mounted) {
        if (response['data'] != null && response['data']['status'] == 200) {
          final rawAddresses = List<Map<String, dynamic>>.from(
            response['data']['response'] ?? [],
          );

          final translatedAddresses = await _enhancedTranslation
              .translateApiResponseList(
                rawAddresses,
                translateUserNames: false,
                forceIncludeFields: [
                  'address_name',
                  'address_line_1',
                  'address_line_2',
                  'locality',
                  'city',
                  'area',
                  'district',
                  'state',
                  'attendee_name',
                ],
                excludeFields: ['id', 'phone_number', 'pincode', 'lat', 'lng'],
              );

          setState(() {
            _addresses = translatedAddresses;
            _filteredAddresses = List.from(_addresses);
            _isLoading = false;
          });

          // Re-trigger animation
          _entryAnimationController.reset();
          _entryAnimationController.forward();
        } else {
          setState(() {
            _errorMessage = 'Failed to load addresses';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: UniversalTranslationWrapper(
        excludePatterns: ['@', '.com', '+', 'ID:'],
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: theme.colorScheme.surface,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                centerTitle: false,
                title: TranslatedText(
                  'Saved Addresses',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 20, // Scaled for SliverAppBar
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: isDarkMode
                          ? [
                              Colors.blueGrey.shade900,
                              theme.colorScheme.surface,
                            ]
                          : [Colors.blue.shade50, theme.colorScheme.surface],
                    ),
                  ),
                ),
              ),
            ),
          ],
          body: RefreshIndicator(
            onRefresh: _fetchAddresses,
            child: CustomScrollView(
              slivers: [
                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: _buildSearchBar(theme),
                  ),
                ),

                // Add Address Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 0,
                    ),
                    child: _buildAddAddressButton(theme),
                  ),
                ),

                SliverPadding(padding: const EdgeInsets.only(top: 24)),

                // Title
                if (!_isLoading && _filteredAddresses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          TranslatedText(
                            "YOUR LOCATIONS",
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Content
                if (_isLoading)
                  SliverFillRemaining(child: _buildLoadingState(theme))
                else if (_errorMessage != null)
                  SliverFillRemaining(child: _buildErrorState(theme))
                else if (_filteredAddresses.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState(theme))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final address = _filteredAddresses[index];
                      // Staggered Animation
                      return AnimatedBuilder(
                        animation: _entryAnimationController,
                        builder: (context, child) {
                          final double slideStart = 50.0 * (index + 1);
                          final double slideEnd = 0.0;

                          final double start = (index * 0.1).clamp(0.0, 1.0);
                          final double end = (start + 0.6).clamp(0.0, 1.0);

                          final curve = CurvedAnimation(
                            parent: _entryAnimationController,
                            curve: Interval(
                              start,
                              end,
                              curve: Curves.easeOutQuint,
                            ),
                          );

                          return Opacity(
                            opacity: curve.value,
                            child: Transform.translate(
                              offset: Offset(0, slideStart * (1 - curve.value)),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: _buildModernAddressCard(address, theme),
                        ),
                      );
                    }, childCount: _filteredAddresses.length),
                  ),

                // Bottom padding
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search your saved places...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.primary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildAddAddressButton(ThemeData theme) {
    return ScaleButton(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => const LocationSelectionScreen(),
          ),
        );
        if (result != null) {
          _fetchAddresses();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4), // For border
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.2),
              theme.colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
              width: 1.5,
              style: BorderStyle
                  .solid, // Can change to use a DottedBorder package if available
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_location_alt_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              TranslatedText(
                "Add New Address",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAddressCard(
    Map<String, dynamic> address,
    ThemeData theme,
  ) {
    final String addressName = address['address_name'] ?? 'Address';
    final String addressLine1 = address['address_line_1'] ?? '';
    final String locality = address['locality'] ?? '';
    final String city = address['city'] ?? '';
    final int pincode = address['pincode'] ?? 0;
    final int phoneNumber = address['phone_number'] ?? 0;

    // Determine Type Icon
    IconData typeIcon;
    Color typeColor;

    final nameLower = addressName.toLowerCase();
    if (nameLower.contains('home')) {
      typeIcon = Icons.home_rounded;
      typeColor = Colors.teal;
    } else if (nameLower.contains('work') || nameLower.contains('office')) {
      typeIcon = Icons.work_rounded;
      typeColor = Colors.indigo;
    } else {
      typeIcon = Icons.location_on_rounded;
      typeColor = theme.colorScheme.primary;
    }

    final bool isExpanded = _expandedCards.contains(address['id']);

    return ScaleButton(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedCards.remove(address['id']);
          } else {
            _expandedCards.add(address['id'] ?? '');
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isExpanded ? typeColor.withOpacity(0.5) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Main Card Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Puc
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 24),
                    ),
                    const SizedBox(width: 16),

                    // Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TranslatedText(
                                addressName.toUpperCase(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              if (!isExpanded)
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TranslatedText(
                            addressLine1,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TranslatedText(
                            "$locality, $city",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded Actions Area
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? Container(
                        width: double.infinity,
                        color: theme
                            .colorScheme
                            .surfaceContainer, // Slightly darker
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Additional Details Grid
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                if (pincode > 0)
                                  _buildMiniDetail(
                                    Icons.grid_3x3,
                                    "$pincode",
                                    theme,
                                  ),
                                if (phoneNumber > 0)
                                  _buildMiniDetail(
                                    Icons.phone_rounded,
                                    "$phoneNumber",
                                    theme,
                                  ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Action Buttons
                            Row(
                              children: [
                                // Select Button
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () => _selectAddress(address),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: typeColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const TranslatedText(
                                      "Deliver Here",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Delete Icon Btn
                                Material(
                                  color: theme.colorScheme.error.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () =>
                                        _showDeleteConfirmation(address),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDetail(IconData icon, String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      highlightColor: theme.colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          TranslatedText(
            _errorMessage ?? "Something went wrong",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _fetchAddresses,
            child: const TranslatedText("Try Again"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Using Lottie for "good animation" as requested
          // Fallback to Icon if lottie fails or file missing
          SizedBox(
            height: 200,
            width: 200,
            child: Lottie.asset(
              'assets/lottie/location_marker.json',
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.map_rounded,
                  size: 100,
                  color: theme.colorScheme.outline.withOpacity(0.3),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          TranslatedText(
            "No Saved Addresses",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TranslatedText(
            "It feels a bit empty here.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // LOGIC & UTILS

  void _showDeleteConfirmation(Map<String, dynamic> address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText('Delete Address'),
        content: const TranslatedText(
          'Are you sure you want to delete this address?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteAddress(address);
            },
            child: const TranslatedText('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteAddress(Map<String, dynamic> address) async {
    // Implement API call here
    // For now assuming success or showing snackbar as per original code
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: TranslatedText('Delete functionality coming soon!')),
    );
  }

  void _selectAddress(Map<String, dynamic> address) async {
    try {
      final String addressName = address['address_name'] ?? 'Address';
      final String addressLine1 = address['address_line_1'] ?? '';
      final String addressLine2 = address['address_line_2'] ?? '';
      final double lat =
          double.tryParse(address['lat']?.toString() ?? '0.0') ?? 0.0;
      final double lng =
          double.tryParse(address['lng']?.toString() ?? '0.0') ?? 0.0;
      final String area = address['area'] ?? '';
      final String city = address['city'] ?? '';
      final String locality = address['locality'] ?? '';

      List<String> addressParts = [];
      if (addressLine1.isNotEmpty) addressParts.add(addressLine1);
      if (addressLine2.isNotEmpty) addressParts.add(addressLine2);
      if (area.isNotEmpty && area != city)
        addressParts.add(area);
      else if (locality.isNotEmpty && locality != city)
        addressParts.add(locality);
      if (city.isNotEmpty) addressParts.add(city);
      final String addressSubtitle = addressParts.join(', ');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('address_title', addressName.toUpperCase());
      await prefs.setString(
        'address_subtitle',
        addressSubtitle.isNotEmpty ? addressSubtitle : 'Selected address',
      );
      await prefs.setString('display_area', area);
      await prefs.setString('display_city', city);
      await prefs.setString('display_locality', locality);
      await prefs.setDouble('latitude', lat);
      await prefs.setDouble('longitude', lng);
      await prefs.setString('lat_string', address['lat']?.toString() ?? '0.0');
      await prefs.setString('lng_string', address['lng']?.toString() ?? '0.0');
      await prefs.setString('saved_address_id', address['id'] ?? '');
      await prefs.setString('saved_address_name', addressName);
      await prefs.setString('saved_address_line_1', addressLine1);
      await prefs.setString('saved_address_line_2', addressLine2);
      await prefs.setString('saved_locality', locality);
      await prefs.setString('saved_city', city);
      await prefs.setString('saved_state', address['state'] ?? '');
      await prefs.setString('saved_district', address['district'] ?? '');
      await prefs.setString('saved_area', area);
      await prefs.setInt('saved_pincode', address['pincode'] ?? 0);
      await prefs.setInt('saved_phone_number', address['phone_number'] ?? 0);
      await prefs.setString(
        'saved_attendee_name',
        address['attendee_name'] ?? '',
      );

      if (mounted) {
        _showSelectionAnimation(context, addressName);
      }

      await Future.delayed(const Duration(milliseconds: 1800));

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.pop(context, {
          'addressSelected': true,
          'addressData': address,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSelectionAnimation(BuildContext context, String addressName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TranslatedText(
                    'Location Updated!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    addressName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
}

// Helper Widget for bounce/scale effect
class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const ScaleButton({super.key, required this.child, required this.onTap});

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
