import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/analytics_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'package:exanor/services/api_service.dart';
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
  bool _isLoadingContacts = false;
  List<Map<String, String>> _contacts = [];

  bool _hasContactPermission = false;
  bool _isUsingApiContacts = false;
  late ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadData();
    _loadReferralCode();
    _requestContactPermission();

    // Track screen view
    AnalyticsService().logEvent(
      eventName: 'refer_and_earn_screen_opened',
      parameters: {
        'screen_name': 'refer_and_earn_screen',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
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

  Future<void> _requestContactPermission() async {
    try {
      PermissionStatus currentStatus = await Permission.contacts.status;
      if (currentStatus.isGranted) {
        setState(() {
          _hasContactPermission = true;
        });
        await _loadContacts();
        return;
      }

      final status = await Permission.contacts.request();
      setState(() {
        _hasContactPermission = status.isGranted;
      });

      if (status.isGranted) {
        await _loadContacts();
      } else {
        await _loadContacts(); // Fallback to API
      }
    } catch (e) {
      setState(() {
        _hasContactPermission = false;
      });
      await _loadContacts();
    }
  }

  /// Fetch contacts from API
  Future<List<Map<String, dynamic>>> _fetchContactsFromApi() async {
    try {
      final response = await ApiService.post(
        '/get-user-contacts/',
        body: {"limit": 10000},
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final data = response['data']['data'];
        final List<dynamic> contacts = data['contacts'] ?? [];
        return contacts.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoadingContacts = true;
    });

    List<Map<String, String>> localContacts = [];

    try {
      PermissionStatus status = await Permission.contacts.status;

      if (status.isGranted) {
        final List<Contact> contacts = await FastContacts.getAllContacts();
        final List<Map<String, String>> formattedContacts = [];

        for (int i = 0; i < contacts.length; i++) {
          final Contact contact = contacts[i];
          if (contact.phones.isNotEmpty &&
              contact.displayName.isNotEmpty &&
              contact.displayName.trim().isNotEmpty) {
            final phoneNumber = contact.phones.first.number;
            final displayName = contact.displayName.trim();
            final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

            if (phoneNumber.isNotEmpty && cleanPhone.length >= 10) {
              formattedContacts.add({
                'id': contact.id,
                'name': displayName,
                'phone': phoneNumber,
                'is_user': 'false',
                'img_url': '',
              });
            }
          }
        }

        formattedContacts.sort(
          (a, b) =>
              a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
        );

        localContacts = formattedContacts;
        await _bulkSyncContacts(formattedContacts);

        // Fetch updated contacts from server to check who is a user
        final List<Map<String, dynamic>> apiContacts =
            await _fetchContactsFromApi();

        if (apiContacts.isNotEmpty) {
          final List<Map<String, String>>
          serverFormattedContacts = apiContacts.map((contact) {
            return {
              'id': contact['id']?.toString() ?? '',
              'name': contact['contact_name']?.toString() ?? '',
              'phone': contact['contact_phone_number']?.toString() ?? '',
              'is_user': contact['is_contact_an_user']?.toString() ?? 'false',
              'contact_user_id': contact['contact_user_id']?.toString() ?? '',
              'img_url': contact['contact_img_url']?.toString() ?? '',
            };
          }).toList();

          serverFormattedContacts.sort(
            (a, b) =>
                a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
          );

          setState(() {
            _contacts = serverFormattedContacts;
            _isLoadingContacts = false;
            _isUsingApiContacts = true;
          });
          return;
        }
      } else {
        // Fallback to API
        final List<Map<String, dynamic>> apiContacts =
            await _fetchContactsFromApi();
        if (apiContacts.isNotEmpty) {
          final List<Map<String, String>> formattedContacts = apiContacts.map((
            contact,
          ) {
            return {
              'id': contact['id']?.toString() ?? '',
              'name': contact['contact_name']?.toString() ?? '',
              'phone': contact['contact_phone_number']?.toString() ?? '',
              'is_user': contact['is_contact_an_user']?.toString() ?? 'false',
              'contact_user_id': contact['contact_user_id']?.toString() ?? '',
              'img_url': contact['contact_img_url']?.toString() ?? '',
            };
          }).toList();

          formattedContacts.sort(
            (a, b) =>
                a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
          );

          setState(() {
            _contacts = formattedContacts;
            _isLoadingContacts = false;
            _isUsingApiContacts = true;
          });
          await _bulkSyncContacts(formattedContacts);
          return;
        }
      }

      // Display local if server failed but local exists
      if (localContacts.isNotEmpty) {
        setState(() {
          _contacts = localContacts;
          _isLoadingContacts = false;
          _isUsingApiContacts = false;
        });
        return;
      }

      // Empty
      setState(() {
        _contacts = [];
        _isLoadingContacts = false;
        _isUsingApiContacts = false;
      });
      await _bulkSyncContacts([]);
    } catch (e) {
      if (localContacts.isNotEmpty) {
        setState(() {
          _contacts = localContacts;
          _isLoadingContacts = false;
          _isUsingApiContacts = false;
        });
      } else {
        setState(() {
          _isLoadingContacts = false;
          _contacts = [];
          _isUsingApiContacts = false;
        });
      }
      await _bulkSyncContacts([]);
    }
  }

  Future<void> _bulkSyncContacts(List<Map<String, String>> contacts) async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool alreadySynced = prefs.getBool('contacts_synced_v1') ?? false;

      if (alreadySynced) return;
      await prefs.setBool('contacts_synced_v1', true);

      if (contacts.isEmpty) return;

      final List<Map<String, dynamic>> contactsData = contacts
          .map((contact) {
            String cleanPhone =
                contact['phone']?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
            if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone';
            final phoneNumber = int.tryParse(cleanPhone);
            if (phoneNumber == null) return <String, dynamic>{};

            final Map<String, dynamic> contactData = {
              'contact_phone_number': phoneNumber,
              'contact_name': contact['name'],
            };
            if (contact['img_url']?.isNotEmpty == true) {
              contactData['contact_img_url'] = contact['img_url'];
            }
            return contactData;
          })
          .where((data) => data.isNotEmpty)
          .toList();

      await ApiService.post(
        '/create-user-contacts-bulk/',
        body: {'contacts': contactsData},
        useBearerToken: true,
      );
    } catch (e) {
      print('Error bulk syncing contacts: $e');
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

  void _inviteContact(String name, String phone) async {
    final appDownloadUrl = FirebaseRemoteConfigService.getAppDownloadUrl();
    final message =
        '''Hi $name! Join Exanor with my code $_referralCode. $appDownloadUrl''';

    AnalyticsService().logEvent(
      eventName: 'individual_contact_invited',
      parameters: {
        'contact_name': name,
        'contact_phone': phone,
        'referral_code': _referralCode,
        'invitation_method': 'sms',
      },
    );

    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Copied to clipboard')));
        }
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Copied to clipboard')));
      }
    }
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
          : Color(0xFFF8F9FA), // Light grey background
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Content
          SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.only(top: 100, bottom: 40),
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
        final lightModeEnd = Colors.white;

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
                  height: topPadding + 60, // Standard header height
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
                    child: SizedBox(
                      height: 60,
                      child: Stack(
                        children: [
                          // Left Back Button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: theme.colorScheme.onSurface,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),

                          // Center Title
                          Center(
                            child: Text(
                              "Refer & Earn", // Explicitly matching menu bar
                              style: TextStyle(
                                fontSize: 20,
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
    final accentColor = const Color(0xFFFF7043); // Vivid Orange
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
                      borderRadius: BorderRadius.only(
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main "Sticker" Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.2),
                            blurRadius: 0,
                            offset: const Offset(3, 3), // Pop-art shadow
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        size: 38,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title (Restored)
                    Text(
                      _data.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: contentColor,
                        letterSpacing: -0.5,
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
    // Ticket Style Card using standard widgets + Clipper for notches
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Stack(
        children: [
          // Main Card Background with Notches
          ClipPath(
            clipper: TicketClipper(),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
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
                  SizedBox(height: 16),

                  // Code Display - Centered, Large but Fitted
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: _isLoadingCode
                        ? SizedBox(
                            height: 40,
                            width: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SelectableText(
                                    _referralCode,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: theme.colorScheme.onSurface,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                onPressed: _copyReferralCode,
                                icon: Icon(
                                  Icons.copy_rounded,
                                  color: theme.primaryColor.withOpacity(0.8),
                                  size: 22,
                                ),
                                tooltip: "Copy",
                              ),
                            ],
                          ),
                  ),

                  SizedBox(height: 32),

                  // Divider Section with "REFER VIA"
                  Row(
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
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "REFER VIA",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.4,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                            ),
                          ],
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

                  SizedBox(height: 32),

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
                      // We can add more specific share buttons here if we implemented specific sharing
                      // For now, replicating the visual of multiple options using the generic share
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

                  SizedBox(height: 24),

                  // Footer Link
                  InkWell(
                    onTap: () {
                      // Track referrals
                    },
                    child: Text(
                      "Track My Referrals",
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.primaryColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(
    ThemeData theme,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  Widget _buildBenefitsGrid(ThemeData theme, bool isDark) {
    if (_data.benefits.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
            child: Text(
              "How it Works",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _data.benefits.length,
              separatorBuilder: (c, i) => Container(
                height: 24,
                margin: EdgeInsets.only(left: 23), // Align with center of icon
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.dividerColor.withOpacity(0.5),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              ),
              itemBuilder: (context, index) {
                final benefit = _data.benefits[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                      child: Icon(
                        _getIconData(benefit.iconName),
                        color: theme.primaryColor,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 16),

                    // Text
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Step ${index + 1}",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              benefit.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              benefit.subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  "Invite from Contacts",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (_contacts.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${_contacts.length}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_isLoadingContacts)
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_contacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.contacts_outlined,
                        size: 48,
                        color: theme.disabledColor.withOpacity(0.3),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "No contacts found",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: _requestContactPermission,
                        child: Text("Sync Contacts"),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  height: 400, // Reduced height for cleaner look
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      physics: AlwaysScrollableScrollPhysics(),
                      itemCount: _contacts.length,
                      separatorBuilder: (c, i) => Divider(
                        height: 1,
                        indent: 70,
                        endIndent: 0,
                        color: theme.dividerColor.withOpacity(0.1),
                      ),
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        final isUser = contact['is_user'] == 'true';

                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: isUser
                                  ? Colors.green.withOpacity(0.1)
                                  : theme.primaryColor.withOpacity(0.1),
                              child: Text(
                                contact['name']!.isNotEmpty
                                    ? contact['name']![0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.green
                                      : theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              contact['name']!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              contact['phone']!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () => _inviteContact(
                                contact['name']!,
                                contact['phone']!,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: isUser
                                    ? Colors.green
                                    : theme.primaryColor,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                backgroundColor: isUser
                                    ? Colors.green.withOpacity(0.1)
                                    : theme.primaryColor.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                isUser ? "Remind" : "Invite",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAndConditions(ThemeData theme, bool isDark) {
    if (_data.termsAndConditions.points.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            childrenPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
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

  TicketClipper({this.holeRadius = 16.0, this.holeHeightRatio = 0.55});

  @override
  Path getClip(Size size) {
    Path path = Path();

    path.lineTo(0.0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0.0);

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
    this.dashWidth = 5.0,
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
