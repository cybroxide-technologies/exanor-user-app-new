import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/screens/simple_otp_verification_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SimplePhoneRegistrationScreen extends StatefulWidget {
  const SimplePhoneRegistrationScreen({super.key});

  @override
  State<SimplePhoneRegistrationScreen> createState() =>
      _SimplePhoneRegistrationScreenState();
}

class _SimplePhoneRegistrationScreenState
    extends State<SimplePhoneRegistrationScreen> {
  final _phoneController = TextEditingController();
  final _scrollController = ScrollController();
  final _phoneFocusNode = FocusNode();
  // Using 91 as default directly for clean look
  final String _countryCode = '91';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen for focus changes to scroll when keyboard appears
    _phoneFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_phoneFocusNode.hasFocus) {
      // Delay slightly to allow keyboard to start appearing
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // Optimized grid colors to match the "Blinkit" aesthetic (Pastels)
  final List<Map<String, dynamic>> _gridItems = [
    {
      'color': const Color(0xFFFFF7ED),
      'icon': Icons.lunch_dining_rounded,
    }, // Orange tint
    {'color': const Color(0xFFF0FDF4), 'icon': Icons.eco_rounded}, // Green tint
    {
      'color': const Color(0xFFEFF6FF),
      'icon': Icons.inventory_2_rounded,
    }, // Blue tint
    {
      'color': const Color(0xFFFAF5FF),
      'icon': Icons.shopping_bag_rounded,
    }, // Purple tint
    {
      'color': const Color(0xFFFEF2F2),
      'icon': Icons.favorite_rounded,
    }, // Red tint
    {
      'color': const Color(0xFFF0F9FF),
      'icon': Icons.local_drink_rounded,
    }, // Cyan tint
    {
      'color': const Color(0xFFFFFBEB),
      'icon': Icons.egg_alt_rounded,
    }, // Yellow tint
    {
      'color': const Color(0xFFFDF4FF),
      'icon': Icons.checkroom_rounded,
    }, // Pink tint
    {'color': const Color(0xFFECFCCB), 'icon': Icons.spa_rounded}, // Lime
    {'color': const Color(0xFFF1F5F9), 'icon': Icons.watch_rounded}, // Slate
    {
      'color': const Color(0xFFEEF2FF),
      'icon': Icons.local_laundry_service_rounded,
    }, // Indigo
    {'color': const Color(0xFFFDF2F8), 'icon': Icons.stroller_rounded}, // Rose
  ];

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onFocusChange);
    _phoneFocusNode.dispose();
    _scrollController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      // Disable auto-resize to prevent jerk, we handle scrolling manually
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          // 1. Background Grid (Takes up the top portion)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.5, // Occupy top 50%
            child: Opacity(
              opacity: isDark ? 0.3 : 1.0,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                itemCount: _gridItems.length,
                itemBuilder: (context, index) {
                  final item = _gridItems[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? (item['color'] as Color).withOpacity(0.1)
                          : item['color'],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      item['icon'],
                      size: 28,
                      color: isDark ? Colors.white60 : Colors.black87,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Main Content Sheet - Using Align for efficient bottom positioning
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo and Title Row - CLEAN LUXURY REDESIGN
                      Column(
                        children: [
                          // Logo - Larger & Premium
                          // Logo - Big & Clean
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: Image.asset(
                              'assets/icon/exanor_blue.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // "Cool" Editorial Typographic Lockup
                          Column(
                            children: [
                              // Top Line: "YOUR NEEDS" - The "Label" style
                              Text(
                                "YOUR NEEDS",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 4.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Bottom Line: "Under One Umbrella"
                              Text(
                                "Under One Umbrella",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Creative Subtitle - "Unlock your experience"
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 1,
                                width: 24,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.1,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Unlock your experience",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  letterSpacing: 1.2,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 1,
                                width: 24,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Phone Input Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Country Code Section with Classy Flag
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Classy Flag Image (Network)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      'https://flagcdn.com/w40/in.png',
                                      width: 28,
                                      height: 20,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Text(
                                                "🇮🇳",
                                                style: TextStyle(fontSize: 24),
                                              ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    "+$_countryCode",
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Vertical Line Separator
                            Container(
                              height: 24,
                              width: 1,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.15,
                              ),
                            ),

                            // Phone Number Input
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                textAlignVertical: TextAlignVertical.center,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: 0.5,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  hintText: "0000000000",
                                  hintStyle: GoogleFonts.inter(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.2),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  suffixIconConstraints: const BoxConstraints(
                                    maxHeight: 24,
                                    maxWidth: 32,
                                  ),
                                  suffixIcon: _phoneController.text.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () => setState(
                                            () => _phoneController.clear(),
                                          ),
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.6),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Verify Button - Full width, prominent
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitPhoneNumber,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor: theme.colorScheme.onSurface
                                .withOpacity(0.1),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  "Continue",
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "By continuing, you agree to our Terms of Service & Privacy Policy",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Extra space for keyboard
                      SizedBox(height: bottomPadding),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitPhoneNumber() async {
    // Minimize keyboard immediately
    FocusScope.of(context).unfocus();

    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid 10-digit number',
            style: GoogleFonts.inter(),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    // Simulate slight delay for UX feel if super fast
    // await Future.delayed(const Duration(milliseconds: 500));

    try {
      final cleanPhoneNumber = phone.replaceAll(RegExp(r'\D'), '');
      final fullPhoneNumber = '$_countryCode$cleanPhoneNumber';

      print('📞 SimplePhoneRegistration: Sending OTP to: $fullPhoneNumber');

      final response = await ApiService.post(
        '/send-otp/',
        body: {'phone_number': fullPhoneNumber},
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (response['data'] != null && response['data']['status'] == 200) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SimpleOTPVerificationScreen(phoneNumber: fullPhoneNumber),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['data']?['message'] ?? 'Failed to send OTP',
              ),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.')),
        );
      }
    }
  }
}
