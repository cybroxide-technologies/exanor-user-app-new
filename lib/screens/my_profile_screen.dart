import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/screens/edit_profile_screen.dart';
import 'package:exanor/screens/saved_addresses_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exanor/services/user_service.dart';

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

  late ScrollController _scrollController;
  bool _showStickyHeader = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadUserData();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      // 280 is expandedHeight. We transition when content is mostly scrolled.
      // 200 is a good threshold leaving some context.
      bool showSticky = _scrollController.offset > 200;
      if (showSticky != _showStickyHeader) {
        setState(() {
          _showStickyHeader = showSticky;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        // Use new endpoint to fetch user data
        await UserService.viewUserData();
      }

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
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });

        if (forceRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(
                'Failed to refresh data: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: TranslatedText(
                  'Logout?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: const TranslatedText(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const TranslatedText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
              ),
              child: const TranslatedText('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    TranslatedText('Logging out...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Clear all SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      print('✅ All SharedPreferences data cleared');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Logged out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Navigate to login/onboarding screen
      // Replace this with your actual navigation logic
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/onboarding', // or '/login' - adjust based on your app
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error during logout: $e');

      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Could not open link: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _isLoadingUserData
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadUserData(forceRefresh: true),
              child: CustomScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(), // Ensure scroll is possible always
                controller: _scrollController,
                slivers: [
                  // Modern App Bar with Glassmorphism
                  SliverAppBar(
                    expandedHeight: 280,
                    collapsedHeight:
                        70, // Increased height to bring content down a bit
                    toolbarHeight: 70,
                    floating: false,
                    pinned: true,
                    backgroundColor:
                        theme.scaffoldBackgroundColor, // Match body background
                    elevation: 0,
                    title: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showStickyHeader ? 1.0 : 0.0,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 8.0,
                        ), // Slight top padding
                        child: TranslatedText(
                          'MY ACCOUNT',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    centerTitle: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(child: _buildFloatingHeader(theme)),
                          // Smooth fade to background color
                          RepaintBoundary(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _showStickyHeader ? 1.0 : 0.0,
                              child: Container(
                                color: theme.scaffoldBackgroundColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    leading: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _showStickyHeader
                          ? Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                              ), // Align with title
                              child: IconButton(
                                key: const ValueKey('sticky_back'),
                                icon: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: theme.colorScheme.onSurface,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('glass_back'),
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                    ),
                  ),

                  // Content
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          top: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              height: 24,
                            ), // Added padding below header
                            // Quick Access Row
                            _buildQuickAccessRow(theme),
                            const SizedBox(height: 32),

                            // Menu Items
                            _buildSectionTitle('Settings', theme),
                            const SizedBox(height: 16),
                            _buildModernMenuItem(
                              icon: Icons.receipt_long_outlined,
                              title: 'Order History',
                              subtitle: 'View your past orders',
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                              onTap: () {
                                Navigator.pushNamed(context, '/orders');
                              },
                              theme: theme,
                            ),
                            const SizedBox(height: 12),

                            _buildSectionTitle('Legal', theme),
                            const SizedBox(height: 16),
                            _buildModernMenuItem(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              subtitle: 'Read our privacy policy',
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.purple.shade600,
                                ],
                              ),
                              onTap: () {
                                final url =
                                    FirebaseRemoteConfigService.getPrivacyPolicyUrl();
                                _launchUrl(url);
                              },
                              theme: theme,
                            ),
                            const SizedBox(height: 12),
                            _buildModernMenuItem(
                              icon: Icons.description_outlined,
                              title: 'Terms & Conditions',
                              subtitle: 'Review terms of service',
                              gradient: LinearGradient(
                                colors: [
                                  Colors.indigo.shade400,
                                  Colors.indigo.shade600,
                                ],
                              ),
                              onTap: () {
                                final url =
                                    FirebaseRemoteConfigService.getTermsAndConditionsUrl();
                                _launchUrl(url);
                              },
                              theme: theme,
                            ),

                            const SizedBox(height: 32),

                            // Account Management
                            _buildSectionTitle('Account Management', theme),
                            const SizedBox(height: 16),
                            _buildModernMenuItem(
                              icon: Icons.delete_outline_rounded,
                              title: 'Delete Account',
                              subtitle: 'Remove your account permanently',
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade400,
                                  Colors.red.shade600,
                                ],
                              ),
                              onTap: () {
                                final url =
                                    FirebaseRemoteConfigService.getDeleteAccountUrl();
                                _launchUrl(url);
                              },
                              theme: theme,
                            ),

                            const SizedBox(height: 32),

                            // Logout Button
                            _buildModernLogoutButton(theme),

                            const SizedBox(height: 24),

                            // App Version
                            Center(
                              child: TranslatedText(
                                'Version ${FirebaseRemoteConfigService.getMinAppVersion()}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFloatingHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        image: DecorationImage(
          image: const NetworkImage(
            'https://images.unsplash.com/photo-1635776062127-d379bfcba9f8?q=80&w=1000&auto=format&fit=crop',
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.darken,
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Fixed Alignment
                    children: [
                      // Profile Image
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: DecorationImage(
                            image: NetworkImage(
                              _userImage != null && _userImage!.isNotEmpty
                                  ? _userImage!
                                  : 'https://i.pravatar.cc/300',
                            ),
                            fit: BoxFit.cover,
                          ),
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Text Info
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              _userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 6),

                            if (_userPhone.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_iphone_rounded,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  TranslatedText(
                                    _userPhone,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _buildQuickAccessButton(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            color: theme.colorScheme.primary,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
              _loadUserData();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickAccessButton(
            icon: Icons.location_on_outlined,
            label: 'Addresses',
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedAddressesScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickAccessButton(
            icon: Icons.info_outline_rounded,
            label: 'About',
            color: Colors.blue,
            onTap: () {
              final url = FirebaseRemoteConfigService.getAboutUsUrl();
              _launchUrl(url);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickAccessButton(
            icon: Icons.headset_mic_rounded,
            label: 'Support',
            color: Colors.orange,
            onTap: () {
              _launchUrl('https://chat.exanor.com');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TranslatedText(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return TranslatedText(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildModernMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TranslatedText(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLogoutButton(ThemeData theme) {
    return InkWell(
      onTap: _showLogoutConfirmationDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.white),
            SizedBox(width: 12),
            TranslatedText(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
