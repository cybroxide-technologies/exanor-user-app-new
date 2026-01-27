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
import 'dart:ui';
import 'package:exanor/services/api_service.dart';
// ticket_painter no longer needed if we use clipper, but keeping import just in case or we can remove it.

class ReferAndEarnScreen extends StatefulWidget {
  const ReferAndEarnScreen({super.key});

  @override
  State<ReferAndEarnScreen> createState() => _ReferAndEarnScreenState();
}

class _ReferAndEarnScreenState extends State<ReferAndEarnScreen>
    with TickerProviderStateMixin {
  late AnimationController _coinController;
  late Animation<double> _coinBounceAnimation;

  String _referralCode = '';
  bool _isLoadingCode = true;
  bool _hasContactPermission = false;
  bool _isLoadingContacts = false;
  List<Map<String, String>> _contacts = [];
  List<Map<String, String>> _filteredContacts = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _rewardAmount = 100; // Default value
  bool _isLoadingReward = true;
  bool _isUsingApiContacts =
      false; // Track if we're using API or native contacts

  @override
  void initState() {
    super.initState();

    // Track screen view
    AnalyticsService().logEvent(
      eventName: 'refer_and_earn_screen_opened',
      parameters: {
        'screen_name': 'refer_and_earn_screen',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );

    _coinController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _coinBounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _coinController,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeOut,
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      _coinController.repeat(reverse: true);
    });

    _loadReferralCode();
    _loadRewardAmount();
    _requestContactPermission();
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
          _referralCode = 'No phone number found';
          _isLoadingCode = false;
        });
      }
    } catch (e) {
      setState(() {
        _referralCode = 'Error loading phone number';
        _isLoadingCode = false;
      });
    }
  }

  Future<void> _loadRewardAmount() async {
    try {
      // Get reward amount from Firebase Remote Config
      final rewardAmount =
          FirebaseRemoteConfigService.getReferralRewardAmount();
      setState(() {
        _rewardAmount = rewardAmount;
        _isLoadingReward = false;
      });
      print('📊 Loaded reward amount: ₹$_rewardAmount');
    } catch (e) {
      print('❌ Error loading reward amount: $e');
      setState(() {
        _rewardAmount = 100; // Fallback to default
        _isLoadingReward = false;
      });
    }
  }

  Future<void> _requestContactPermission() async {
    try {
      print('📞 Requesting contact permission using permission_handler...');

      // Check current permission status
      PermissionStatus currentStatus = await Permission.contacts.status;
      print('📞 Current contact permission status: $currentStatus');

      if (currentStatus.isGranted) {
        print('📞 Permission already granted, loading contacts...');
        setState(() {
          _hasContactPermission = true;
        });
        await _loadContacts();
        return;
      }

      // Request permission
      final status = await Permission.contacts.request();
      print('📞 Permission request result: $status');

      setState(() {
        _hasContactPermission = status.isGranted;
      });

      if (status.isGranted) {
        print('📞 Permission granted, loading contacts...');
        await _loadContacts();
      } else if (status.isPermanentlyDenied) {
        print('📞 Permission permanently denied - Silent fallback');
        // Fallback to API contacts without nagging the user
        await _loadContacts();
      } else {
        print('📞 Permission denied: $status - Silent fallback');
        // Fallback to API contacts without nagging the user
        await _loadContacts();
      }
    } catch (e) {
      print('❌ Error requesting contact permission: $e');
      setState(() {
        _hasContactPermission = false;
      });
      // Try to load strictly from API/Local fallback even if permission errored
      await _loadContacts();
    }
  }

  /// Fetch contacts from API
  Future<List<Map<String, dynamic>>> _fetchContactsFromApi() async {
    try {
      print('📞 Fetching contacts from API...');

      final response = await ApiService.post(
        '/get-user-contacts/',
        body: {"limit": 10000},
        useBearerToken: true,
      );

      print('📞 API contacts response: $response');

      if (response['data'] != null && response['data']['status'] == 200) {
        final data = response['data']['data'];
        final List<dynamic> contacts = data['contacts'] ?? [];

        print('📞 API returned ${contacts.length} contacts');

        return contacts.cast<Map<String, dynamic>>();
      } else {
        print('📞 API returned no contacts or error status');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching contacts from API: $e');
      return [];
    }
  }

  Future<void> _loadContacts() async {
    print('📞 Starting contact loading...');
    setState(() {
      _isLoadingContacts = true;
    });

    List<Map<String, String>> localContacts = [];

    try {
      // Always try to fetch fresh contacts from device first
      // Check permission status before loading native contacts
      PermissionStatus status = await Permission.contacts.status;

      if (status.isGranted) {
        print('📞 Loading fresh contacts from device using fast_contacts...');
        final List<Contact> contacts = await FastContacts.getAllContacts();

        print('📞 Raw contacts loaded: ${contacts.length}');

        final List<Map<String, String>> formattedContacts = [];

        for (int i = 0; i < contacts.length; i++) {
          final Contact contact = contacts[i];
          // Check if contact has phones and display name
          if (contact.phones.isNotEmpty &&
              contact.displayName.isNotEmpty &&
              contact.displayName.trim().isNotEmpty) {
            final phoneNumber = contact.phones.first.number;
            final displayName = contact.displayName.trim();

            // Extract additional contact information (only what's available)
            final String email = contact.emails.isNotEmpty
                ? contact.emails.first.address
                : '';

            final String address = '';
            final String city = '';
            final String state = '';
            final String country = '';

            // Basic phone number validation - be more lenient
            final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
            if (phoneNumber.isNotEmpty && cleanPhone.length >= 10) {
              formattedContacts.add({
                'id': contact.id,
                'name': displayName,
                'phone': phoneNumber,
                'email': email,
                'address': address,
                'city': city,
                'state': state,
                'country': country,
                'is_user': 'false',
                'contact_user_id': '',
                'img_url': '',
              });
            }
          }
        }

        // Sort contacts alphabetically
        formattedContacts.sort(
          (a, b) =>
              a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
        );

        print('📞 Formatted device contacts: ${formattedContacts.length}');
        localContacts = formattedContacts;

        // Always upload fresh contacts to server
        await _bulkSyncContacts(formattedContacts);

        // After uploading, fetch updated contacts from server
        print('📞 Fetching updated contacts from server after upload...');
        final List<Map<String, dynamic>> apiContacts =
            await _fetchContactsFromApi();

        if (apiContacts.isNotEmpty) {
          // Use server contacts (with updated info like is_contact_an_user)
          print('📞 Using updated server contacts: ${apiContacts.length}');

          final List<Map<String, String>>
          serverFormattedContacts = apiContacts.map((contact) {
            return {
              'id': contact['id']?.toString() ?? '',
              'name': contact['contact_name']?.toString() ?? '',
              'phone': contact['contact_phone_number']?.toString() ?? '',
              'email': contact['contact_email']?.toString() ?? '',
              'is_user': contact['is_contact_an_user']?.toString() ?? 'false',
              'contact_user_id': contact['contact_user_id']?.toString() ?? '',
              'img_url': contact['contact_img_url']?.toString() ?? '',
              'address': '',
              'city': '',
              'state': '',
              'country': '',
            };
          }).toList();

          // Sort contacts alphabetically
          serverFormattedContacts.sort(
            (a, b) =>
                a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
          );

          setState(() {
            _contacts = serverFormattedContacts;
            _filteredContacts = serverFormattedContacts;
            _isLoadingContacts = false;
            _isUsingApiContacts = true;
          });

          return;
        }
      } else {
        print('❌ Contact permission not granted, trying API fallback...');

        // Fallback: try to get contacts from API if permission not granted
        final List<Map<String, dynamic>> apiContacts =
            await _fetchContactsFromApi();

        if (apiContacts.isNotEmpty) {
          print('📞 Using API contacts as fallback: ${apiContacts.length}');

          final List<Map<String, String>> formattedContacts = apiContacts.map((
            contact,
          ) {
            return {
              'id': contact['id']?.toString() ?? '',
              'name': contact['contact_name']?.toString() ?? '',
              'phone': contact['contact_phone_number']?.toString() ?? '',
              'email': contact['contact_email']?.toString() ?? '',
              'is_user': contact['is_contact_an_user']?.toString() ?? 'false',
              'contact_user_id': contact['contact_user_id']?.toString() ?? '',
              'img_url': contact['contact_img_url']?.toString() ?? '',
              'address': '',
              'city': '',
              'state': '',
              'country': '',
            };
          }).toList();

          // Sort contacts alphabetically
          formattedContacts.sort(
            (a, b) =>
                a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
          );

          setState(() {
            _contacts = formattedContacts;
            _filteredContacts = formattedContacts;
            _isLoadingContacts = false;
            _isUsingApiContacts = true;
          });

          // Still sync API contacts (in case they were updated)
          await _bulkSyncContacts(formattedContacts);
          return;
        }
      }

      // Final fallback: display local contacts if server fetch failed
      if (localContacts.isNotEmpty) {
        print('📞 Displaying local contacts as final fallback');
        setState(() {
          _contacts = localContacts;
          _filteredContacts = localContacts;
          _isLoadingContacts = false;
          _isUsingApiContacts = false;
        });
        return;
      }

      // If everything failed, show empty state
      print('📞 No contacts available from any source');
      setState(() {
        _contacts = [];
        _filteredContacts = [];
        _isLoadingContacts = false;
        _isUsingApiContacts = false;
      });

      // Still make empty sync call to ensure server is up to date
      await _bulkSyncContacts([]);
    } catch (e, stackTrace) {
      print('❌ Error loading contacts: $e');
      print('❌ Stack trace: $stackTrace');

      // Fallback to local contacts if available
      if (localContacts.isNotEmpty) {
        print('📞 Using local contacts due to error');
        setState(() {
          _contacts = localContacts;
          _filteredContacts = localContacts;
          _isLoadingContacts = false;
          _isUsingApiContacts = false;
        });
      } else {
        setState(() {
          _isLoadingContacts = false;
          _contacts = [];
          _filteredContacts = [];
          _isUsingApiContacts = false;
        });
      }

      // Still make empty sync call even on error
      await _bulkSyncContacts([]);
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = contact['name']?.toLowerCase() ?? '';
          final phone = contact['phone']?.toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) ||
              phone.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _inviteContact(String name, String phone) async {
    // Optimized SMS message with only essential info
    final message =
        '''Hi $name! Join KaamBazar with my code $_referralCode and get ₹$_rewardAmount ad credits! ${FirebaseRemoteConfigService.getAppDownloadUrl()}''';

    try {
      AnalyticsService().logEvent(
        eventName: 'individual_contact_invited',
        parameters: {
          'contact_name': name,
          'contact_phone': phone,
          'referral_code': _referralCode,
          'invitation_method': 'sms',
        },
      );

      // Clean phone number for SMS
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

      // Create SMS URI
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: {'body': message},
      );

      // Try to launch SMS app
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        // Fallback to clipboard if SMS can't be opened
        await Clipboard.setData(ClipboardData(text: message));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(
                'SMS app not available. Invitation message copied to clipboard!',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error opening SMS app: $e');

      // Fallback to clipboard
      await Clipboard.setData(ClipboardData(text: message));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(
              'Failed to open SMS. Invitation message copied to clipboard!',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Bulk sync contacts to backend - Silent and One-time
  Future<void> _bulkSyncContacts(List<Map<String, String>> contacts) async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool alreadySynced = prefs.getBool('contacts_synced_v1') ?? false;

      if (alreadySynced) {
        return;
      }

      await prefs.setBool('contacts_synced_v1', true);

      if (contacts.isEmpty) {
        return;
      }

      // Prepare contacts data for bulk upload
      final List<Map<String, dynamic>> contactsData = contacts
          .map((contact) {
            // Clean phone number - remove all non-digit characters
            String cleanPhone =
                contact['phone']?.replaceAll(RegExp(r'[^\d]'), '') ?? '';

            // Add 91 prefix if phone number is exactly 10 digits
            if (cleanPhone.length == 10) {
              cleanPhone = '91$cleanPhone';
            }

            final phoneNumber = int.tryParse(cleanPhone);

            if (phoneNumber == null) {
              return <String, dynamic>{};
            }

            // Build contact data with all available fields
            final Map<String, dynamic> contactData = {
              'contact_phone_number': phoneNumber,
              'contact_name': contact['name'],
            };

            // Add optional fields if they exist
            if (contact['email']?.isNotEmpty == true) {
              contactData['contact_email'] = contact['email'];
            }
            if (contact['address']?.isNotEmpty == true) {
              contactData['contact_address'] = contact['address'];
            }
            if (contact['city']?.isNotEmpty == true) {
              contactData['contact_city'] = contact['city'];
            }
            if (contact['state']?.isNotEmpty == true) {
              contactData['contact_state'] = contact['state'];
            }
            if (contact['country']?.isNotEmpty == true) {
              contactData['contact_country'] = contact['country'];
            }
            if (contact['img_url']?.isNotEmpty == true) {
              contactData['contact_img_url'] = contact['img_url'];
            }
            if (contact['contact_user_id']?.isNotEmpty == true) {
              contactData['contact_user_id'] = contact['contact_user_id'];
            }

            return contactData;
          })
          .where((data) => data.isNotEmpty)
          .toList();

      if (contactsData.isEmpty) return;

      await ApiService.post(
        '/create-user-contacts-bulk/',
        body: {'contacts': contactsData},
        useBearerToken: true,
      );

      print('📞 Bulk sync request completed silently');
    } catch (e) {
      print('❌ Error bulk syncing contacts: $e');
    }
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));

    AnalyticsService().logEvent(
      eventName: 'referral_code_copied',
      parameters: {'referral_code': _referralCode},
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const TranslatedText('Referral code copied!'),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _shareReferralCode() async {
    final appDownloadUrl = FirebaseRemoteConfigService.getAppDownloadUrl();

    final message =
        '''🎁 Join KaamBazar and get ₹$_rewardAmount ad credits!

Use my referral code: $_referralCode

Download KaamBazar: $appDownloadUrl

#KaamBazar #FreeCredits #ReferAndEarn''';

    try {
      AnalyticsService().logEvent(
        eventName: 'referral_code_shared',
        parameters: {
          'referral_code': _referralCode,
          'share_method': 'system_share',
        },
      );

      await Share.share(
        message,
        subject: 'Join KaamBazar - Get ₹$_rewardAmount ad credits!',
      );
    } catch (e) {
      Clipboard.setData(ClipboardData(text: message));

      AnalyticsService().logEvent(
        eventName: 'referral_share_fallback_copy',
        parameters: {'referral_code': _referralCode, 'error': e.toString()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const TranslatedText(
              'Referral message copied to clipboard!',
            ),
            backgroundColor: const Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _coinController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101010)
          : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Refer & Earn",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // 1. Header Text
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  height: 1.2,
                  fontFamily: 'Roboto',
                ),
                children: const [
                  TextSpan(text: "Refer & Earn \n"),
                  TextSpan(
                    text: "= ₹₹ Unlimited",
                    style: TextStyle(color: Color(0xFFFFD700)), // Gold/Yellow
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Invite friends and earn rewards",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            // 2. The Main "Ticket" Card
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // The Card Itself
                Container(
                  margin: const EdgeInsets.only(top: 20), // Space for ribbon
                  child: ClipPath(
                    clipper: SideTicketClipper(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Referral Code Section
                          Text(
                            "Your Referral Code",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Code Display
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black26
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(
                                  _referralCode.isEmpty
                                      ? "LOADING..."
                                      : _referralCode,
                                  style: TextStyle(
                                    fontFamily: 'RobotoMono',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: _copyReferralCode,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      size: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Separator with "REFER VIA"
                          Row(
                            children: [
                              Expanded(
                                child: CustomPaint(
                                  painter: DashedLinePainter(
                                    color: isDark
                                        ? Colors.white24
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "REFER VIA",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white38
                                            : const Color(0xFF94A3B8),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: CustomPaint(
                                  painter: DashedLinePainter(
                                    color: isDark
                                        ? Colors.white24
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Social Icons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialBtn(
                                icon: Icons.share_rounded,
                                color: const Color(0xFF3B82F6), // Blue
                                onTap: _shareReferralCode,
                              ),
                              const SizedBox(width: 20),
                              _buildSocialBtn(
                                icon: Icons.message_rounded,
                                color: const Color(0xFF10B981), // Green
                                onTap: () {
                                  // Default SMS intent
                                  _inviteContact("Friend", "");
                                },
                              ),
                              const SizedBox(width: 20),
                              _buildSocialBtn(
                                icon: Icons.qr_code_rounded,
                                color: const Color(0xFF8B5CF6), // Purple
                                onTap: _copyReferralCode,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Track Referrals Link
                          TextButton(
                            onPressed: () {
                              // Placeholder for tracking navigation
                            },
                            child: Text(
                              "Track My Referrals",
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // The Ribbon (Top)
                Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFD700),
                          Color(0xFFFFA000),
                        ], // Gold Gradient
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "  WIN ₹ 100 / REFER  ",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 3. Contact List Section
            _buildContactListSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildContactListSection(ThemeData theme) {
    if (_hasContactPermission == false && !_isUsingApiContacts) {
      return Column(
        children: [
          Icon(Icons.lock_outline, size: 48, color: theme.disabledColor),
          const SizedBox(height: 16),
          const Text("Contact access needed to invite friends"),
          TextButton(
            onPressed: _requestContactPermission,
            child: const Text("Allow Access"),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Contacts on KaamBazar",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _filterContacts,
            decoration: const InputDecoration(
              hintText: "Search contacts...",
              border: InputBorder.none,
              icon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_isLoadingContacts)
          const Center(child: CircularProgressIndicator())
        else if (_filteredContacts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                "No contacts found",
                style: TextStyle(color: theme.disabledColor),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredContacts.take(20).length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final contact = _filteredContacts[index];
              final isUser = contact['is_user'] == 'true';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isUser
                      ? Colors.green.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    contact['name']!.isNotEmpty
                        ? contact['name']!.substring(0, 1).toUpperCase()
                        : "?",
                    style: TextStyle(
                      color: isUser ? Colors.green : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  contact['name']!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(contact['phone']!),
                trailing: isUser
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Joined",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: () =>
                            _inviteContact(contact['name']!, contact['phone']!),
                        style: TextButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.1),
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        child: const Text("Invite"),
                      ),
              );
            },
          ),

        if (_filteredContacts.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Text(
                "+${_filteredContacts.length - 20} more contacts",
                style: TextStyle(color: theme.disabledColor),
              ),
            ),
          ),
      ],
    );
  }
}

// Custom Clipper for the Ticket Shape (Side Notches)
class SideTicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final notchRadius = 12.0;
    final notchY = 190.0;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);

    // Right Side
    path.lineTo(size.width, notchY - notchRadius);
    path.arcToPoint(
      Offset(size.width, notchY + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, size.height);

    // Bottom
    path.lineTo(0, size.height);

    // Left Side
    path.lineTo(0, notchY + notchRadius);
    path.arcToPoint(
      Offset(0, notchY - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Dashed Line Painter
class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double dashWidth = 6;
    final double dashSpace = 4;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
