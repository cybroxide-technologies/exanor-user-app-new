import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/screens/location_selection_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/saved_addresses_skeleton.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  List<Map<String, dynamic>> _savedAddresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAddresses();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrolled =
        _scrollController.hasClients && _scrollController.offset > 10;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('📍 SavedAddresses: Fetching addresses from API...');

      // Fetch addresses from the server
      final response = await ApiService.post(
        '/user-address/',
        body: {'query': {}}, // Empty query as per API format
        useBearerToken: true,
      );

      if (response['data'] != null) {
        final responseData = response['data'];
        final status = responseData['status'];

        if (status == 200 && responseData['response'] != null) {
          final List<dynamic> addressesList = responseData['response'] as List;

          print(
            '✅ SavedAddresses: Loaded ${addressesList.length} addresses from server',
          );

          final List<Map<String, dynamic>> loaded = addressesList
              .map((item) => item as Map<String, dynamic>)
              .toList();

          // Also save to local storage for offline access
          final prefs = await SharedPreferences.getInstance();
          final List<String> listToSave = loaded
              .map((e) => json.encode(e))
              .toList();
          await prefs.setStringList('saved_addresses_list', listToSave);

          setState(() {
            _savedAddresses = loaded;
            _isLoading = false;
          });
          return;
        }
      }

      // Fallback: If API fails, load from local storage
      print(
        '⚠️ SavedAddresses: API response invalid, falling back to local storage',
      );
      await _loadFromLocalStorage();
    } catch (e) {
      print('❌ SavedAddresses: Error fetching from API: $e');
      // Fallback to local storage if API fails
      await _loadFromLocalStorage();
    }
  }

  /// Load addresses from local SharedPreferences (fallback)
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list =
          prefs.getStringList('saved_addresses_list') ?? [];

      final List<Map<String, dynamic>> loaded = [];
      for (var item in list) {
        try {
          loaded.add(json.decode(item) as Map<String, dynamic>);
        } catch (e) {
          print('Error decoding address: $e');
        }
      }

      // Migration: If list is empty but we have a single saved address, use that
      if (loaded.isEmpty) {
        final String? singleAddress = prefs.getString('address_details');
        if (singleAddress != null) {
          try {
            final Map<String, dynamic> addr = json.decode(singleAddress);
            loaded.add(addr);
            // Save back as list so we don't need to migrate next time
            await prefs.setStringList('saved_addresses_list', [singleAddress]);
          } catch (e) {
            print("Error migrating single address: $e");
          }
        }
      }

      setState(() {
        _savedAddresses = loaded;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading addresses from local storage: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _hexToColor(String? hex, {Color defaultColor = Colors.transparent}) {
    if (hex == null || hex.isEmpty) {
      return defaultColor;
    }
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

  Color _lightenColor(Color color, [double amount = 0.3]) {
    assert(amount >= 0 && amount <= 1);
    return Color.lerp(color, Colors.white, amount)!;
  }

  void _addNewAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationSelectionScreen()),
    );
    // Reload addresses when returning
    _loadAddresses();
  }

  void _editAddress(int index) {
    // For now, since we don't have an edit flow, we'll just redirect to Add New Address
    // ideally we would pass the address data to the screen
    _addNewAddress();
  }

  IconData _getIconForLabel(String? label) {
    if (label == null) return Icons.location_on_rounded;
    final l = label.toLowerCase();
    if (l.contains('home')) return Icons.home_rounded;
    if (l.contains('work') || l.contains('office')) return Icons.work_rounded;
    if (l.contains('friend') || l.contains('partner') || l.contains('family')) {
      return Icons.people_rounded;
    }
    return Icons.location_on_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: UniversalTranslationWrapper(
        child: Stack(
          children: [
            // 1. Scrollable Content
            RefreshIndicator(
              onRefresh: _loadAddresses,
              color: theme.colorScheme.primary,
              backgroundColor: theme.cardColor,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 100,
                      bottom: 120, // Space for bottom button
                      left: 20,
                      right: 20,
                    ),
                    sliver: _isLoading
                        ? const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: SavedAddressesSkeleton(),
                            ),
                          )
                        : _savedAddresses.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(theme),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: _buildAddressCard(
                                  theme,
                                  _savedAddresses[index],
                                  index,
                                  isDark,
                                ),
                              );
                            }, childCount: _savedAddresses.length),
                          ),
                  ),
                ],
              ),
            ),

            // 2. Fixed Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(theme, isDark),
            ),

            // 3. Floating Bottom Button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomButton(theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;

    // Calculate Light Mode Colors to match HomeScreen logic (Immersive Light)
    final lightStartBase = _hexToColor(
      FirebaseRemoteConfigService.getThemeGradientLightStart(),
    );
    final lightModeStart = Color.alphaBlend(
      lightStartBase.withOpacity(0.35),
      Colors.white,
    );
    const lightModeEnd = Colors.white;

    final startColor = isDark
        ? _hexToColor(
            FirebaseRemoteConfigService.getThemeGradientDarkStart(),
            defaultColor: const Color(0xFF1A1A1A),
          )
        : lightModeStart;
    final endColor = isDark
        ? _hexToColor(
            FirebaseRemoteConfigService.getThemeGradientDarkEnd(),
            defaultColor: Colors.black,
          )
        : lightModeEnd;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: topPadding + 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  startColor.withOpacity(
                    0.95,
                  ), // Added opacity for glass effect
                  endColor.withOpacity(0.95),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Stack(
              children: [
                // Watermark Icon
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 120,
                      color: theme.colorScheme.onSurface.withOpacity(0.03),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.only(
                    top: topPadding + 10,
                    left: 20,
                    right: 20,
                    bottom: 15,
                  ),
                  child: Row(
                    children: [
                      _buildBackButton(theme, isDark),
                      Expanded(
                        child: Center(
                          child: TranslatedText(
                            "Saved Addresses",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance spacing
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(ThemeData theme, bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 22,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(
    ThemeData theme,
    Map<String, dynamic> address,
    int index,
    bool isDark,
  ) {
    final label = address['address_name'] ?? address['label'] ?? 'Unknown';
    // Construct display address from components if available
    String displayAddress = address['address'] ?? '';
    if (displayAddress.isEmpty) {
      List<String> parts = [];
      if (address['address_line_1'] != null)
        parts.add(address['address_line_1']);
      if (address['address_line_2'] != null)
        parts.add(address['address_line_2']);
      if (address['city'] != null) parts.add(address['city']);
      if (address['state'] != null) parts.add(address['state']);
      if (address['pincode'] != null) parts.add(address['pincode'].toString());
      displayAddress = parts.join(', ');
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              // Save the selected address to SharedPreferences
              try {
                final prefs = await SharedPreferences.getInstance();

                // Save address ID and coordinates (handle both string and numeric types)
                await prefs.setString('saved_address_id', address['id'] ?? '');

                // Parse lat/lng properly - they come as strings from the API
                double lat = 0.0;
                double lng = 0.0;

                if (address['lat'] != null) {
                  lat = address['lat'] is String
                      ? double.parse(address['lat'])
                      : (address['lat'] as num).toDouble();
                }

                if (address['lng'] != null) {
                  lng = address['lng'] is String
                      ? double.parse(address['lng'])
                      : (address['lng'] as num).toDouble();
                }

                await prefs.setDouble('latitude', lat);
                await prefs.setDouble('longitude', lng);

                // Save address display strings
                final label =
                    address['address_name'] ?? address['label'] ?? 'Unknown';
                String displayAddress = address['address'] ?? '';
                if (displayAddress.isEmpty) {
                  List<String> parts = [];
                  if (address['address_line_1'] != null)
                    parts.add(address['address_line_1']);
                  if (address['address_line_2'] != null)
                    parts.add(address['address_line_2']);
                  if (address['city'] != null) parts.add(address['city']);
                  if (address['state'] != null) parts.add(address['state']);
                  if (address['pincode'] != null)
                    parts.add(address['pincode'].toString());
                  displayAddress = parts.join(', ');
                }

                await prefs.setString(
                  'address_title',
                  label.toString().toUpperCase(),
                );
                await prefs.setString('address_subtitle', displayAddress);

                print(
                  '✅ SavedAddresses: Selected address saved to SharedPreferences',
                );
                print('   ID: ${address['id']}');
                print('   Lat/Lng: ${address['lat']}, ${address['lng']}');
                print('   Title: $label');
                print('   Subtitle: $displayAddress');
              } catch (e) {
                print('❌ Error saving address to SharedPreferences: $e');
              }

              // Return the selected address with proper format
              if (mounted) {
                Navigator.pop(context, {'addressSelected': true, ...address});
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Icon Container
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _getIconForLabel(label),
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatedText(
                          label.toString().toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.0,
                            color: theme.colorScheme.onSurface.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TranslatedText(
                          displayAddress,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            height: 1.5,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
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
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.disabledColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_off_rounded,
              size: 64,
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 24),
          TranslatedText(
            'No saved addresses',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          TranslatedText(
            'Add a location to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(ThemeData theme, bool isDark) {
    // Gradient button style from OrdersListScreen
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.scaffoldBackgroundColor.withOpacity(0),
            theme.scaffoldBackgroundColor.withOpacity(0.9),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 1. Base Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      _lightenColor(theme.colorScheme.primary, 0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // 2. Glass Overlay
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // 3. Content
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _addNewAddress,
                  splashColor: Colors.white.withOpacity(0.2),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_location_alt_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        TranslatedText(
                          "ADD NEW ADDRESS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
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
