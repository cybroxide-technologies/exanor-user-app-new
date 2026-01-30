import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/analytics_service.dart';
import 'package:exanor/services/contact_service.dart';
import 'package:exanor/services/user_service.dart';

import 'package:exanor/models/refer_and_earn_data.dart';

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient Spots
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          RefreshIndicator(
            onRefresh: _refreshData,
            color: theme.colorScheme.primary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header Space
                const SliverToBoxAdapter(child: SizedBox(height: 120)),

                // Title & Description
                SliverToBoxAdapter(child: _buildHeaderSection(theme, isDark)),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Referral Code "Ticket"
                SliverToBoxAdapter(
                  child: _buildReferralCodeSection(theme, isDark),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                // "How it Works" / Benefits Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "Your Rewards",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Benefits Grid (The "Boxes")
                _buildBenefitsGrid(theme, isDark),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                // Contacts Section
                SliverToBoxAdapter(child: _buildContactsSection(theme, isDark)),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                // Terms
                SliverToBoxAdapter(
                  child: _buildTermsAndConditions(theme, isDark),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // Custom App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildCustomAppBar(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar(ThemeData theme, bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      height: topPadding + 60,
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
          ),
          Expanded(
            child: AnimatedOpacity(
              opacity: _isScrolled ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                "Refer & Earn",
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance back button
        ],
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Animated Icon or Illustration
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              size: 48,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _data.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
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
    if (_data.benefits.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final benefit = _data.benefits[index];
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getIconData(benefit.iconName),
                    color: theme.primaryColor,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Text(
                  benefit.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  benefit.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }, childCount: _data.benefits.length),
      ),
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
