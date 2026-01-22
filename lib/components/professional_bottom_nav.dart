import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/components/liquid_glass_bottom_nav.dart'; // For BottomNavTab and RegistrationBottomSheet
import 'package:exanor/components/language_selector.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/screens/qr_scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfessionalBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ProfessionalBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<ProfessionalBottomNav> createState() => _ProfessionalBottomNavState();
}

class _ProfessionalBottomNavState extends State<ProfessionalBottomNav> {
  List<BottomNavTab> _navigationTabs = [];

  @override
  void initState() {
    super.initState();
    _loadNavigationTabs();
  }

  void _loadNavigationTabs() {
    try {
      final tabsData = FirebaseRemoteConfigService.getBottomNavBarTabs();
      _navigationTabs = tabsData
          .map((json) => BottomNavTab.fromJson(json))
          .toList();

      _navigationTabs.sort((a, b) => a.index.compareTo(b.index));
    } catch (e) {
      _navigationTabs = _getDefaultTabs();
    }
  }

  List<BottomNavTab> _getDefaultTabs() {
    return [
      BottomNavTab(
        id: 'home',
        label: 'Home',
        icon: 'home_outlined',
        activeIcon: 'home',
        action: 'navigate',
        actionData: '/home',
        badgeType: BadgeType.none,
        index: 0,
      ),
      BottomNavTab(
        id: 'register',
        label: 'Register',
        icon: 'person_add_outlined',
        activeIcon: 'person_add',
        action: 'showRegistration',
        badgeType: BadgeType.freeBadge,
        index: 1,
      ),
      BottomNavTab(
        id: 'refer',
        label: 'Refer & Earn',
        icon: 'card_giftcard_outlined',
        activeIcon: 'card_giftcard',
        action: 'navigate',
        actionData: '/refer_and_earn',
        badgeType: BadgeType.goldenBadge,
        index: 2,
      ),
      BottomNavTab(
        id: 'translate',
        label: 'Translate',
        icon: 'translate_outlined',
        activeIcon: 'translate',
        action: 'showLanguageSelector',
        badgeType: BadgeType.none,
        index: 3,
      ),
    ];
  }

  void _handleTabAction(BottomNavTab tab) {
    HapticFeedback.lightImpact();

    switch (tab.action) {
      case 'showRegistration':
        _showRegistrationPopup();
        break;
      case 'showReferEarn':
        widget.onTap(tab.index);
        break;
      case 'showLanguageSelector':
        _showLanguageSelector(tab.index);
        break;
      case 'navigate':
        if (tab.actionData != null && tab.actionData!.isNotEmpty) {
          if (tab.actionData == '/refer_and_earn' ||
              tab.actionData == '/feed') {
            // Just callback, parent might handle routing
          } else {
            Navigator.pushNamed(context, tab.actionData!).then((_) {
              widget.onTap(0);
            });
          }
        }
        widget.onTap(tab.index);
        break;
      default:
        widget.onTap(tab.index);
        break;
    }
  }

  void _showRegistrationPopup() {
    widget.onTap(1);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegistrationBottomSheet(
        onClose: () {
          widget.onTap(0);
        },
      ),
    ).then((_) {
      widget.onTap(0);
    });
  }

  void _showLanguageSelector(int index) {
    widget.onTap(index);
    showLanguageSelector(
      context,
      onLanguageSelected: (language) {
        widget.onTap(0);
      },
    ).then((_) {
      widget.onTap(0);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Redesign logic:
    // 1. Sliding Pill Background: A subtle highlight that moves behind the active tab.
    // 2. Visible Labels: All tabs show their labels.
    // 3. Spacing: Add internal padding to the container to prevent edge squishing.
    // 4. Icons: Standard sizing with scaling effect.

    final backgroundColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Main Navigation Pill (4/5 width)
          Expanded(
            flex: 4,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: borderColor, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabCount = _navigationTabs.length;
                    // Add padding compensation to width calculation if we use padding on Row
                    // But simpler: just use Expanded and let LayoutBuilder determine width per tab.
                    final totalWidth = constraints.maxWidth;

                    // We want consistent padding on edges, say 8px
                    const double horizontalPadding = 8.0;
                    final double usableWidth =
                        totalWidth - (horizontalPadding * 2);
                    final double tabWidth = usableWidth / tabCount;

                    // Find active index relative to our list
                    int activeIndex = 0;
                    for (int i = 0; i < tabCount; i++) {
                      if (_navigationTabs[i].index == widget.currentIndex) {
                        activeIndex = i;
                        break;
                      }
                    }

                    return Stack(
                      children: [
                        // Sliding Indicator Pill
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack, // Bouncy/Fluid feel
                          left: horizontalPadding + (activeIndex * tabWidth),
                          top: 8,
                          bottom: 8,
                          width: tabWidth,
                          child: Center(
                            child: Container(
                              // The pill shouldn't fill the whole width, maybe 90%
                              width: tabWidth * 0.9,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),

                        // Tabs
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: Row(
                            children: _navigationTabs.map((tab) {
                              final isSelected =
                                  widget.currentIndex == tab.index;
                              final color = isSelected
                                  ? theme.colorScheme.primary
                                  : theme.iconTheme.color?.withOpacity(0.5);

                              return SizedBox(
                                width: tabWidth,
                                child: GestureDetector(
                                  onTap: () => _handleTabAction(tab),
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: isSelected ? 1.1 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? tab.activeIconData
                                              : tab.iconData,
                                          color: color,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tab.label,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          fontSize: 10,
                                          color: color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // QR Scanner FAB (1/5 width)
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: _handleQrScan,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      Color.lerp(theme.colorScheme.primary, Colors.white, 0.2)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
