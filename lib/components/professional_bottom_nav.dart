import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/components/liquid_glass_bottom_nav.dart'; // For RegistrationBottomSheet
import 'package:exanor/components/language_selector.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/screens/qr_scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfessionalBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ProfessionalBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return const _ProfessionalBottomNavContent();
  }
}

class _ProfessionalBottomNavContent extends StatefulWidget {
  const _ProfessionalBottomNavContent();

  @override
  State<_ProfessionalBottomNavContent> createState() =>
      _ProfessionalBottomNavContentState();
}

class _ProfessionalBottomNavContentState
    extends State<_ProfessionalBottomNavContent> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _tabs = [];

  // Expanded Icon Mapping to catch all server keys
  final Map<String, IconData> _iconMap = {
    // Basic / Home
    'home': Icons.home,
    'home_outlined': Icons.home_outlined,
    'home_filled': Icons.home,
    'house': Icons.home,

    // User / Auth / Profile
    'person_add': Icons.person_add,
    'person_add_outlined': Icons.person_add_outlined,
    'person': Icons.person,
    'person_outline': Icons.person_outline,
    'profile': Icons.person,
    'account': Icons.account_circle,
    'account_circle': Icons.account_circle,
    'user': Icons.person,

    // Rewards / Refer / Gift
    'card_giftcard': Icons.card_giftcard,
    'card_giftcard_outlined': Icons.card_giftcard_outlined,
    'wallet_giftcard': Icons.wallet_giftcard,
    'loyalty': Icons.loyalty,
    'redeem': Icons.redeem,
    'stars': Icons.stars,
    'gift': Icons.card_giftcard,
    'refer': Icons.card_giftcard,
    'refer_earn': Icons.card_giftcard,
    'refer_and_earn': Icons.card_giftcard,
    'share': Icons.share,
    'invite': Icons.person_add,

    // Translate
    'translate': Icons.translate,
    'translate_outlined': Icons.translate_outlined,
    'language': Icons.language,

    // Media / Feed / Social
    'play_circle_filled': Icons.play_circle_filled,
    'play_circle_outline': Icons.play_circle_outline,
    'video_library': Icons.video_library,
    'feed': Icons.feed,
    'feed_outlined': Icons.feed_outlined,
    'rss_feed': Icons.rss_feed,
    'newspaper': Icons.newspaper,
    'dynamic_feed': Icons.dynamic_feed,
    'explore': Icons.explore,
    'social': Icons.people,

    // Business / Work
    'work': Icons.work,
    'work_outline': Icons.work_outline,
    'business': Icons.business,
    'business_center': Icons.business_center,
    'business_outlined': Icons.business_outlined,

    // Orders / Transactions / List
    'list': Icons.list,
    'list_alt': Icons.list_alt,
    'receipt': Icons.receipt,
    'receipt_long': Icons.receipt_long,
    'receipt_long_outlined': Icons.receipt_long_outlined,
    'description': Icons.description,
    'history': Icons.history,
    'shopping_bag': Icons.shopping_bag,
    'shopping_bag_outlined': Icons.shopping_bag_outlined,
    'order': Icons.receipt_long,
    'orders': Icons.receipt_long,
    'my_orders': Icons.receipt_long,
    'assignment': Icons.assignment,
    'clipboard': Icons.assignment,

    // Misc / Shopping
    'qr_code_scanner': Icons.qr_code_scanner,
    'qr_code_scanner_rounded': Icons.qr_code_scanner_rounded,
    'settings': Icons.settings,
    'settings_outlined': Icons.settings_outlined,
    'shopping_cart': Icons.shopping_cart,
    'shopping_cart_outlined': Icons.shopping_cart_outlined,
    'cart': Icons.shopping_cart,
    'favorite': Icons.favorite,
    'favorite_outline': Icons.favorite_outline,
    'heart': Icons.favorite,
    'notifications': Icons.notifications,
    'notifications_none': Icons.notifications_none,
    'bell': Icons.notifications,
    'map': Icons.map,
    'place': Icons.place,
    'location': Icons.location_on,
  };

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  void _loadTabs() {
    final configTabs = FirebaseRemoteConfigService.getBottomNavBarTabs();
    // Debug log to help identify missing keys
    print(
      "📱 Loaded Bottom Nav Tabs: ${configTabs.map((t) => '${t['label']}: ${t['icon']}').toList()}",
    );

    if (mounted) {
      setState(() {
        _tabs = configTabs;
      });
    }
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    final parent = context
        .findAncestorWidgetOfExactType<ProfessionalBottomNav>();
    parent?.onTap(index);
  }

  void _showRegistrationPopup() {
    // Attempt to select the 'register' tab purely for visual feedback
    final regIndex = _tabs.indexWhere(
      (t) => t['id'] == 'register' || t['label'] == 'Register',
    );
    if (regIndex != -1) _onTabSelected(regIndex);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegistrationBottomSheet(onClose: () {}),
    ).then((_) {
      // Revert to Home
      final homeIndex = _tabs.indexWhere(
        (t) => t['id'] == 'home' || t['label'] == 'Home',
      );
      if (homeIndex != -1) _onTabSelected(homeIndex);
    });
  }

  void _showLanguageSelector(int index) {
    _onTabSelected(index);
    showLanguageSelector(
      context,
      onLanguageSelected: (language) {
        final homeIndex = _tabs.indexWhere((t) => t['id'] == 'home');
        if (homeIndex != -1) _onTabSelected(homeIndex);
      },
    ).then((_) {
      // Revert to Home on close
      final homeIndex = _tabs.indexWhere((t) => t['id'] == 'home');
      if (homeIndex != -1) _onTabSelected(homeIndex);
    });
  }

  Future<void> _handleQrScan() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const QRScannerScreen()),
        );
      }
    } else {
      if (mounted) {
        openAppSettings();
      }
    }
  }

  void _handleItemAction(String action, String? data, int index) {
    if (action == 'navigate' && data == '/home') {
      _onTabSelected(index);
      return;
    }

    switch (action) {
      case 'navigate':
        _onTabSelected(index);
        if (data != null && data.isNotEmpty && data != '/home') {
          Navigator.pushNamed(context, data).then((_) {
            final homeIndex = _tabs.indexWhere((t) => t['id'] == 'home');
            if (homeIndex != -1) _onTabSelected(homeIndex);
          });
        }
        break;
      case 'showRegistration':
        _showRegistrationPopup();
        break;
      case 'showLanguageSelector':
        _showLanguageSelector(index);
        break;
      case 'scan': // Handle scan action if comes from tab
        _handleQrScan();
        break;
      default:
        _onTabSelected(index);
        break;
    }
  }

  IconData _getIcon(String? iconName, String label) {
    // 1. Try to resolve via Icon Name if it exists
    if (iconName != null && iconName.isNotEmpty) {
      // Normalize key: trim whitespace and convert to lowercase
      final key = iconName.trim().toLowerCase();

      // Direct match
      if (_iconMap.containsKey(key)) return _iconMap[key]!;

      // Try matching without suffixes
      if (key.endsWith('_outlined')) {
        final base = key.replaceAll('_outlined', '');
        if (_iconMap.containsKey(base)) return _iconMap[base]!;
      }
      if (key.endsWith('_rounded')) {
        final base = key.replaceAll('_rounded', '');
        if (_iconMap.containsKey(base)) return _iconMap[base]!;
      }
      if (key.endsWith('_filled')) {
        final base = key.replaceAll('_filled', '');
        if (_iconMap.containsKey(base)) return _iconMap[base]!;
      }

      // Fuzzy match on Icon Key
      if (key.contains('home')) return Icons.home;
      if (key.contains('order')) return Icons.receipt_long;
      if (key.contains('receipt')) return Icons.receipt_long;
      if (key.contains('feed')) return Icons.feed;
      if (key.contains('gift') || key.contains('refer'))
        return Icons.card_giftcard;
      if (key.contains('user') || key.contains('profile')) return Icons.person;
    }

    // 2. Fallback: Resolve via Label (Robust Safety Net)
    final labelKey = label.trim().toLowerCase();

    if (labelKey.contains('home')) return Icons.home;

    // Orders / Transactions
    if (labelKey.contains('order')) return Icons.receipt_long;
    if (labelKey.contains('list')) return Icons.list_alt;
    if (labelKey.contains('history')) return Icons.history;
    if (labelKey.contains('transaction')) return Icons.receipt;
    if (labelKey.contains('booking')) return Icons.calendar_today;

    // Feed / Media
    if (labelKey.contains('feed')) return Icons.feed;
    if (labelKey.contains('news')) return Icons.newspaper;
    if (labelKey.contains('video')) return Icons.play_circle;

    // Refer / Rewards
    if (labelKey.contains('refer')) return Icons.card_giftcard;
    if (labelKey.contains('earn')) return Icons.monetization_on_outlined;
    if (labelKey.contains('reward')) return Icons.stars;
    if (labelKey.contains('bonus')) return Icons.card_giftcard;

    // Profile
    if (labelKey.contains('profile')) return Icons.person;
    if (labelKey.contains('account')) return Icons.manage_accounts;
    if (labelKey.contains('setting')) return Icons.settings;

    // Translate
    if (labelKey.contains('translat')) return Icons.translate;
    if (labelKey.contains('lang')) return Icons.language;

    // 3. Ultimate Fallback
    // If strict check passes, return proper icon
    if (labelKey == "orders" || labelKey == "my orders" || labelKey == "order")
      return Icons.receipt_long;

    // Return WARNING icon instead of circle to debug if it's truly falling through
    return Icons.warning_amber_rounded;
  }

  Color _hexToColor(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    try {
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;

    // Gradient Colors for Scanner
    final gradientStart = _hexToColor(
      isDark
          ? FirebaseRemoteConfigService.getThemeGradientDarkStart()
          : FirebaseRemoteConfigService.getThemeGradientLightStart(),
    );
    final gradientEnd = _hexToColor(
      isDark
          ? FirebaseRemoteConfigService.getThemeGradientDarkEnd()
          : FirebaseRemoteConfigService.getThemeGradientLightEnd(),
    );

    final displayTabs = _tabs.take(4).toList();
    final leftTabs = displayTabs.length >= 2
        ? displayTabs.sublist(0, 2)
        : displayTabs;
    final rightTabs = displayTabs.length > 2
        ? displayTabs.sublist(2)
        : <Map<String, dynamic>>[];

    // Allow stack to overflow for scanner button
    return SizedBox(
      height: 100, // Adjusted height to accommodate top of button
      child: Stack(
        clipBehavior: Clip.none, // VITAL: Allows button to pop out top
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Background Bar with Cutout
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 80,
              child: CustomPaint(
                size: Size(size.width, 80),
                painter: _PeelPainter(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shadowColor: Colors.black.withOpacity(0.08),
                ),
              ),
            ),
          ),

          // 2. Scanner Button (Floating)
          Positioned(
            bottom: 35, // Positioned to sit in the dip
            child: GestureDetector(
              onTap: _handleQrScan,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [gradientStart, gradientEnd],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientStart.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          // 3. Navigation Items
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0), // Adjust if needed
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ...leftTabs.asMap().entries.map(
                    (entry) => _buildNavItem(entry.value, entry.key, theme),
                  ),

                  // Central Gap (Reduced)
                  const SizedBox(width: 70),

                  ...rightTabs.asMap().entries.map(
                    (entry) => _buildNavItem(entry.value, entry.key + 2, theme),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(Map<String, dynamic> item, int index, ThemeData theme) {
    final bool isSelected = _currentIndex == index;
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.iconTheme.color?.withOpacity(0.5);

    final activeIcon = item['activeIcon'] as String?;
    final icon = item['icon'] as String?;
    final label = item['label'] as String? ?? '';
    final action = item['action'] as String? ?? '';
    final actionData = item['actionData'] as String?;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _handleItemAction(action, actionData, index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected
                    ? _getIcon(activeIcon, label)
                    : _getIcon(icon, label),
                key: ValueKey(isSelected),
                color: color,
                size: 24, // Slightly smaller to save space
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10, // Small text
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeelPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  _PeelPainter({required this.color, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path();

    final center = size.width / 2;
    // Tweak curve geometry for 64px button overlap
    const curveWidth = 70.0;

    path.moveTo(0, 0); // Top Left

    // Line to start of curve
    path.lineTo(center - curveWidth, 0);

    // Smooth Bezier Curve Cutout
    path.cubicTo(
      center - 32,
      0, // Control 1
      center - 32,
      40, // Control 2
      center,
      40, // Bottom Point
    );

    path.cubicTo(
      center + 32,
      40, // Control 1
      center + 32,
      0, // Control 2
      center + curveWidth,
      0, // End Point
    );

    // Line to right
    path.lineTo(size.width, 0);

    // Extend significantly down to cover safe area
    path.lineTo(size.width, size.height + 200);
    path.lineTo(0, size.height + 200);
    path.close();

    // Draw Shadow
    canvas.drawPath(path, shadowPaint);
    // Draw Shape
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
