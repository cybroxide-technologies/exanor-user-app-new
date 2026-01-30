import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/analytics_service.dart';
import 'package:exanor/services/contact_service.dart';
import 'package:exanor/services/user_service.dart';

import 'dart:ui' as ui;
import 'package:exanor/models/refer_and_earn_data.dart';
import 'package:exanor/components/refer_and_earn_skeleton.dart';

class ReferAndEarnScreen extends StatefulWidget {
  const ReferAndEarnScreen({super.key});

  @override
  State<ReferAndEarnScreen> createState() => _ReferAndEarnScreenState();
}

class _ReferAndEarnScreenState extends State<ReferAndEarnScreen>
    with SingleTickerProviderStateMixin {
  late ReferAndEarnData _data;
  String _referralCode = '';
  bool _isLoadingCode = true;
  bool _isSyncing = false;
  bool _isScrolled = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadData();
    _loadReferralCode();

    // Track screen view
    AnalyticsService().logEvent(
      eventName: 'refer_and_earn_screen_opened',
      parameters: {
        'screen_name': 'refer_and_earn_screen',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Automatically sync contacts after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncContacts(silent: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isScrolled = _scrollController.offset > 10;
      if (isScrolled != _isScrolled) {
        setState(() {
          _isScrolled = isScrolled;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoadingCode = true;
    });

    // Fetch latest config & user data
    await Future.wait([
      FirebaseRemoteConfigService.fetchAndActivate(),
      UserService.viewUserData(), // Refresh user profile including phone
    ]);

    _loadData();
    await _loadReferralCode();
  }

  void _loadData() {
    setState(() {
      _data = FirebaseRemoteConfigService.getReferAndEarnData();
    });
  }

  Future<void> _loadReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phone_number') ?? '';

      if (phoneNumber.isNotEmpty) {
        setState(() {
          _referralCode = phoneNumber;
          _isLoadingCode = false;
        });
      } else {
        setState(() {
          _referralCode = 'No phone number';
          _isLoadingCode = false;
        });
      }
    } catch (e) {
      setState(() {
        _referralCode = 'Error';
        _isLoadingCode = false;
      });
    }
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const TranslatedText('Referral code copied!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareReferralCode() {
    final appDownloadUrl = FirebaseRemoteConfigService.getAppDownloadUrl();
    final message =
        '''${_data.title}\n\n${_data.description}\n\nUse my referral code: $_referralCode\n\nDownload: $appDownloadUrl''';

    Share.share(message);
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'groups':
        return Icons.groups_rounded;
      case 'schedule':
        return Icons.schedule_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium Design Setup
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Gradients
    return Scaffold(
      backgroundColor: isDark
          ? Colors.black
          : const Color(0xFFF8F9FA), // Light grey background
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Content
          RefreshIndicator(
            onRefresh: _refreshData,
            color: theme.colorScheme.primary,
            backgroundColor: theme.cardColor,
            displacement: 140, // Push spinner below the header
            edgeOffset: 130, // Offset from top to account for header
            child: _isLoadingCode
                ? const SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.only(top: 130),
                      child: ReferAndEarnSkeleton(),
                    ),
                  )
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 130, bottom: 40),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContentHeader(theme, isDark),
                        const SizedBox(height: 10),
                        _buildReferralCodeSection(theme, isDark),
                        const SizedBox(height: 48),
                        _buildBenefitsGrid(theme, isDark),
                        const SizedBox(height: 48),
                        _buildContactsSection(theme, isDark),
                        const SizedBox(height: 48),
                        _buildTermsAndConditions(theme, isDark),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
          ),

          // Pinned Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(theme, isDark),
          ),
        ],
      ),
    );
  }

  // Pinned Header - Gradient Blur Style (Matches Order List)
  Widget _buildHeader(ThemeData theme, bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;

    // Animate opacity/blur based on scroll
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: 0.0, end: _isScrolled ? 1.0 : 0.0),
      builder: (context, value, child) {
        final double blurSigma = value * 15.0;
        // Gradient is always visible (0.95) and becomes slightly more opaque when scrolled (1.0)
        final double opacity = 0.95 + (value * 0.05);

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
              )
            : lightModeStart;
        final endColor = isDark
            ? _hexToColor(FirebaseRemoteConfigService.getThemeGradientDarkEnd())
            : lightModeEnd;

        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 25,
                offset: const Offset(0, 12),
                spreadRadius: -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: Container(
                  height:
                      topPadding +
                      80, // Increased height for bigger banner feel
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        startColor.withOpacity(opacity),
                        endColor.withOpacity(opacity),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withOpacity(value * 0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      // Center content vertically in the taller header
                      child: SizedBox(
                        height: 60, // Keep content height standard
                        child: Stack(
                          children: [
                            // Left Back Button
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(
                                      16,
                                    ), // Squircle
                                    border: Border.all(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ui.ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
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
                                ),
                              ),
                            ),

                            // Center Title
                            Center(
                              child: Text(
                                _data.title,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.5,
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
            ),
          ),
        );
      },
    );
  }

  Color _hexToColor(String code) {
    if (code.isEmpty) return Colors.transparent;
    try {
      return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.transparent;
    }
  }

  Widget _buildContentHeader(ThemeData theme, bool isDark) {
    // "Doodle Art" aesthetic purely via Code
    // White/Cream background + Black Outlines + Orange Accents
    final cardBgColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFFFF8F0);
    const accentColor = Color(0xFFFF7043); // Vivid Orange
    final contentColor = isDark ? Colors.white : const Color(0xFF2D2424);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 0,
              offset: const Offset(4, 4), // Hard shadow for "sticker" look
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // 1. Code-based Doodle Decorations

              // Top Right: Organic Blob shape
              Positioned(
                top: -30,
                right: -30,
                child: Transform.rotate(
                  angle: -0.1,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(60),
                        topLeft: Radius.circular(60),
                        bottomRight: Radius.circular(60),
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Left: Dotted Pattern or Squiggle
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: contentColor.withOpacity(0.05),
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Floating Doodle Icons (Simulating the line art)
              _buildDoodleIcon(
                icon: Icons.favorite_rounded,
                color: accentColor,
                size: 24,
                top: 20,
                left: 30,
                angle: -0.2,
              ),

              _buildDoodleIcon(
                icon: Icons.star_outline_rounded,
                color: contentColor.withOpacity(0.4),
                size: 28,
                bottom: 40,
                right: 30,
                angle: 0.2,
              ),

              _buildDoodleIcon(
                icon: Icons.card_giftcard_rounded,
                color: contentColor.withOpacity(0.2),
                size: 40,
                top: 30,
                right: 40,
                angle: 0.15,
              ),

              // 2. Central Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 50, // Reverted to 50
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main "Sticker" Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.2),
                            blurRadius: 0,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        size: 48,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    Text(
                      _data.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: contentColor,
                        letterSpacing: -0.5,
                        fontSize: 28,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      _data.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: contentColor.withOpacity(0.6),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for placing playful icons
  Widget _buildDoodleIcon({
    required IconData icon,
    required Color color,
    required double size,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double angle,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Icon(icon, color: color, size: size),
      ),
    );
  }

  Widget _buildReferralCodeSection(ThemeData theme, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF5F5F5);

    // Ticket Style Card using standard widgets + Clipper for notches
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        // Background color that will show through the notches
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: PhysicalShape(
            clipper: TicketClipper(),
            color: cardColor,
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.2),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: cardColor),
              child: Column(
                children: [
                  // Top Section: Code
                  Text(
                    'Your Referral Code',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Code Display - Centered, Large but Fitted
                  _isLoadingCode
                      ? const Center(
                          child: SizedBox(
                            height: 40,
                            width: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Referral Code - Centered
                            Center(
                              child: SelectableText(
                                _referralCode,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: theme.colorScheme.onSurface,
                                  fontFamily: 'Inter',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Copy Button - Centered
                            Center(
                              child: Material(
                                color: theme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: _copyReferralCode,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.copy_rounded,
                                          color: theme.primaryColor,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Copy Code',
                                          style: TextStyle(
                                            color: theme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
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

                  const SizedBox(height: 32),

                  // Divider Section with "REFER VIA"
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _DashedLinePainter(
                            color: theme.dividerColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "REFER VIA",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CustomPaint(
                          painter: _DashedLinePainter(
                            color: theme.dividerColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Bottom Section: Social Share Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        theme,
                        Icons.share_rounded,
                        Colors.blue,
                        _shareReferralCode,
                      ),
                      _buildSocialButton(
                        theme,
                        Icons.message_rounded,
                        Colors.green,
                        _shareReferralCode,
                      ),
                      _buildSocialButton(
                        theme,
                        Icons.email_rounded,
                        Colors.redAccent,
                        _shareReferralCode,
                      ),
                      _buildSocialButton(
                        theme,
                        Icons.more_horiz_rounded,
                        Colors.grey,
                        _shareReferralCode,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Footer Link
                  InkWell(
                    onTap: () {
                      // Track referrals
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Track My Referrals",
                        style: TextStyle(
                          color: Colors.blue, // Blue as requested
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
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

  // Helper for social buttons
  Widget _buildSocialButton(
    ThemeData theme,
    IconData icon,
    Color bg,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: bg.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: bg, size: 24),
      ),
    );
  }

  Widget _buildBenefitsGrid(ThemeData theme, bool isDark) {
    if (_data.benefits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "How it Works",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Simple steps to start earning",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Horizontal Scrollable Cards
        SizedBox(
          height: 240, // Fixed height for the horizontal list
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: _data.benefits.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final benefit = _data.benefits[index];

              return Container(
                width: 260,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Watermark Number (Aesthetic touch)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Text(
                        "0${index + 1}",
                        style: TextStyle(
                          fontSize: 100,
                          fontWeight: FontWeight.w900,
                          color: theme.primaryColor.withOpacity(0.05),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon Badge
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getIconData(benefit.iconName),
                              color: theme.primaryColor,
                              size: 28,
                            ),
                          ),
                          const Spacer(),

                          // Step Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.05,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "STEP ${index + 1}",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            benefit.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Description
                          Text(
                            benefit.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactsSection(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sync_rounded,
                color: theme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Text
            Text(
              "Sync Contacts",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Sync your contacts to find friends who are already on Exanor.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSyncing
                    ? null
                    : () => _syncContacts(silent: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // Premium Black
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSyncing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync_rounded, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "Sync Contacts",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _shareReferralCode,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                    width: 1,
                  ),
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_rounded, size: 20),
                    SizedBox(width: 12),
                    Text(
                      "Invite a Friend",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncContacts({bool silent = false}) async {
    if (!silent) {
      setState(() => _isSyncing = true);
    }

    try {
      // 1. Get Contacts
      final contacts = await ContactService.getAllContacts();

      // 2. Sync to Backend
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Syncing ${contacts.length} contacts...')),
        );
      }

      await ContactService.syncContacts(contacts);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Widget _buildTermsAndConditions(ThemeData theme, bool isDark) {
    if (_data.termsAndConditions.points.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: 24,
            ),
            title: Text(
              _data.termsAndConditions.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            iconColor: theme.colorScheme.onSurface.withOpacity(0.6),
            collapsedIconColor: theme.colorScheme.onSurface.withOpacity(0.4),
            children: _data.termsAndConditions.points.map((point) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "• ",
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  final double holeRadius;
  final double holeHeightRatio;
  final double cornerRadius;

  TicketClipper({
    this.holeRadius = 16.0,
    this.holeHeightRatio = 0.55,
    this.cornerRadius = 24.0,
  });

  @override
  Path getClip(Size size) {
    Path path = Path();

    // Start with a rounded rectangle
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(cornerRadius),
      ),
    );

    // Right Notch
    path.addOval(
      Rect.fromCircle(
        center: Offset(size.width, size.height * holeHeightRatio),
        radius: holeRadius,
      ),
    );

    // Left Notch
    path.addOval(
      Rect.fromCircle(
        center: Offset(0.0, size.height * holeHeightRatio),
        radius: holeRadius,
      ),
    );

    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _DashedLinePainter({
    this.color = Colors.black,
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
