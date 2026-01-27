import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/screens/edit_profile_screen.dart';
import 'package:exanor/screens/saved_addresses_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exanor/services/user_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:exanor/components/my_profile_skeleton.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  String _userName = 'Guest User';
  String _userPhone = '';
  String? _userImage;
  bool _isLoadingUserData = true;

  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserData();
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

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    try {
      // Always fetch from API to get latest data including profile image
      await UserService.viewUserData();

      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('first_name') ?? '';
      final lastName = prefs.getString('last_name') ?? '';
      final phone = prefs.getString('user_phone') ?? '';
      final image = prefs.getString('user_image');

      if (mounted) {
        setState(() {
          _userName = '$firstName $lastName'.trim();
          if (_userName.isEmpty) {
            _userName = 'Guest User';
          }
          _userPhone = phone;
          _userImage = image;
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const TranslatedText(
            'Log out?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          ),
          content: const TranslatedText(
            'Are you sure you want to log out of your account?',
            style: TextStyle(fontSize: 13),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TranslatedText('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogout();
              },
              child: const TranslatedText(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/onboarding', (route) => false);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apple-style Grouped Background Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF000000)
        : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _isLoadingUserData ? const MyProfileSkeleton() : _buildBody(isDark),

          // 1. Sliding "Curtain" Header (Background + Title)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildSlidingHeader(isDark),
          ),

          // 2. Premium Fixed Back Button (Always Accessible)
          Positioned(
            top: 0, // Handled inside widget with SafeArea
            left: 0,
            child: _buildFloatingBackButton(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = 70.0;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.only(top: topPadding + headerHeight, bottom: 40),
      children: [
        // 1. Profile Section
        _buildProfileSection(isDark),

        const SizedBox(height: 24),

        // 2. Main Actions (Orders, Address, Wallet)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('MY ACCOUNT'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.6)
                          : Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'My Orders',
                      iconColor: Colors.blue,
                      onTap: () => Navigator.pushNamed(context, '/orders'),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSettingsTile(
                      icon: Icons.pin_drop_rounded,
                      title: 'Saved Addresses',
                      iconColor: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedAddressesScreen(),
                        ),
                      ),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSettingsTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Wallet',
                      iconColor: Colors.orange,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: TranslatedText('Wallet coming soon!'),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3. Promo Banner - REMOVED
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16),
        //   child: _buildReferBanner(isDark),
        // ),
        // const SizedBox(height: 12),
        const SizedBox(height: 24),

        // 4. Settings Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('SETTINGS & SUPPORT'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: _buildSettingsAndSupportItems(isDark)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 5. Danger Zone / Logout
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildSettingsTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              iconColor: Colors.red,
              isDestructive: true,
              onTap: _showLogoutConfirmationDialog,
              isDark: isDark,
              showChevron: false,
            ),
          ),
        ),

        const SizedBox(height: 12),
        // Delete Account - conditionally shown
        if (FirebaseRemoteConfigService.shouldShowDeleteAccount())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildSettingsTile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete Account',
                iconColor: Colors.red,
                isDestructive: true,
                onTap: () => _launchUrl(
                  FirebaseRemoteConfigService.getDeleteAccountUrl(),
                ),
                isDark: isDark,
              ),
            ),
          ),

        const SizedBox(height: 32),
        Center(
          child: TranslatedText(
            'Version ${FirebaseRemoteConfigService.getMinAppVersion()}',
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // --- Components ---

  Widget _buildProfileSection(bool isDark) {
    // "Super Creative" Magazine / Poster Style Header
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Artistic Background (Subtle Top-Right Flow)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    Theme.of(context).colorScheme.primary.withOpacity(0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // 2. Secondary Artistic Element (Bottom-Left Dot)
          Positioned(
            bottom: 0,
            left: 20,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 2. Main Content Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Hello" Tag
              // "Hello" Tag
              // Dynamic Greeting - High Fashion Vertical Bar
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TranslatedText(
                    _getGreeting().toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dynamic Layout: Name on Left, Image Floating on Right
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Super Bold Typography
                        Text(
                          _userName.split(' ').first.toUpperCase(),
                          style: TextStyle(
                            fontSize: 36,
                            height: 0.9,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: -1.5,
                          ),
                        ),
                        Text(
                          _userName.split(' ').length > 1
                              ? _userName
                                    .split(' ')
                                    .sublist(1)
                                    .join(' ')
                                    .toUpperCase()
                              : '',
                          style: TextStyle(
                            fontSize: 36,
                            height: 0.9,
                            fontWeight: FontWeight.w300, // Light contrast
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.4),
                            letterSpacing: -1.5,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Phone Pill
                        if (_userPhone.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_iphone_rounded,
                                  size: 12,
                                  color: isDark ? Colors.grey : Colors.black54,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _userPhone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey
                                        : Colors.black54,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Creative Floating Avatar
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Spinning / Pulsing Glow Ring
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFFF4757)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                      // The Image
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF1C1C1E)
                              : Colors.white, // Border gap
                          image: _userImage != null
                              ? DecorationImage(
                                  image: NetworkImage(_userImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _userImage == null
                            ? Icon(
                                Icons.person,
                                size: 40,
                                color: isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              )
                            : null,
                      ),
                      // Edit Pencil Badge
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfileScreen(),
                              ),
                            );
                            _loadUserData();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.black : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferBanner(bool isDark) {
    // Sleek gradient banner
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1), // Indigo
            const Color(0xFF8B5CF6), // Violet
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          final url = FirebaseRemoteConfigService.getAppDownloadUrl();
          Share.share(
            'Check out this amazing app! Download it here: $url',
            subject: 'Download Exanor App',
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    'Refer & Earn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  TranslatedText(
                    'Invite friends to get ₹100',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: TranslatedText(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: TranslatedText(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400, // Regular weight is more premium
                  color: isDestructive
                      ? Colors.red
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),

            // Chevron
            if (showChevron)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 54, // Align with text start
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
    );
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 4) {
      return 'Good Night'; // Until 4 AM
    } else if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else if (hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  // --- Header & Navigation ---

  Widget _buildSlidingHeader(bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = topPadding + 60;

    return AnimatedSlide(
      duration: Duration(
        milliseconds: _isScrolled ? 600 : 200,
      ), // Fast but visible retraction
      curve: _isScrolled
          ? Curves.easeOutQuart
          : Curves.fastOutSlowIn, // Instant start, no delay
      offset: _isScrolled ? Offset.zero : const Offset(0, -1),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: headerHeight,
            padding: EdgeInsets.only(top: topPadding),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.85),
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.05,
                  ),
                  width: 0.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: TranslatedText(
                "Profile",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build settings and support items based on remote config visibility
  List<Widget> _buildSettingsAndSupportItems(bool isDark) {
    final items = <Widget>[];

    // Help & Support - always shown
    items.add(
      _buildSettingsTile(
        icon: Icons.headset_mic_rounded,
        title: 'Help & Support',
        iconColor: Colors.purple,
        onTap: () => _launchUrl('https://chat.exanor.com'),
        isDark: isDark,
      ),
    );

    // About Us - conditionally shown
    if (FirebaseRemoteConfigService.shouldShowAboutUs()) {
      items.add(_buildDivider(isDark));
      items.add(
        _buildSettingsTile(
          icon: Icons.info_outline_rounded,
          title: 'About Us',
          iconColor: Colors.blue,
          onTap: () => _launchUrl(FirebaseRemoteConfigService.getAboutUsUrl()),
          isDark: isDark,
        ),
      );
    }

    // Privacy Policy - conditionally shown
    if (FirebaseRemoteConfigService.shouldShowPrivacyPolicy()) {
      items.add(_buildDivider(isDark));
      items.add(
        _buildSettingsTile(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy Policy',
          iconColor: Colors.grey,
          onTap: () =>
              _launchUrl(FirebaseRemoteConfigService.getPrivacyPolicyUrl()),
          isDark: isDark,
        ),
      );
    }

    // Terms & Conditions - conditionally shown
    if (FirebaseRemoteConfigService.shouldShowTermsAndConditions()) {
      items.add(_buildDivider(isDark));
      items.add(
        _buildSettingsTile(
          icon: Icons.description_rounded,
          title: 'Terms & Conditions',
          iconColor: Colors.grey,
          onTap: () => _launchUrl(
            FirebaseRemoteConfigService.getTermsAndConditionsUrl(),
          ),
          isDark: isDark,
        ),
      );
    }

    // Refund Policy - conditionally shown
    if (FirebaseRemoteConfigService.shouldShowRefundPolicy()) {
      items.add(_buildDivider(isDark));
      items.add(
        _buildSettingsTile(
          icon: Icons.policy_outlined,
          title: 'Refund Policy',
          iconColor: Colors.orange,
          onTap: () =>
              _launchUrl(FirebaseRemoteConfigService.getRefundPolicyUrl()),
          isDark: isDark,
        ),
      );
    }

    // Disclaimer - conditionally shown
    if (FirebaseRemoteConfigService.shouldShowDisclaimer()) {
      items.add(_buildDivider(isDark));
      items.add(
        _buildSettingsTile(
          icon: Icons.warning_amber_rounded,
          title: 'Disclaimer',
          iconColor: Colors.amber,
          onTap: () =>
              _launchUrl(FirebaseRemoteConfigService.getDisclaimerUrl()),
          isDark: isDark,
        ),
      );
    }

    return items;
  }

  Widget _buildFloatingBackButton(bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    // Premium Glassy Button
    return Container(
      margin: EdgeInsets.only(top: topPadding + 8, left: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14), // Modern Squircle
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(14),
                child: Icon(
                  Icons.arrow_back_rounded, // Cleaner rounded arrow
                  size: 22,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
