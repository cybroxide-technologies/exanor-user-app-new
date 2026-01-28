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
  // Using 91 as default directly for clean look
  final String _countryCode = '91';
  bool _isLoading = false;

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
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      // Important: False here to manually handle animation for smoothness
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

          // 2. Main Content Sheet
          // Using a Column with Spacer allows the sheet to sit at the bottom,
          // and gets pushed up when keyboard appears (because of resizeToAvoidBottomInset).
          // 2. Main Content Sheet (Scrollable to prevent overflow)
          // 2. Main Content Sheet
          AnimatedPositioned(
            duration: const Duration(milliseconds: 100), // Fast smoothing
            curve: Curves.easeOut,
            top: 0,
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: Column(
              children: [
                const Spacer(),

                // The "Sheet" Container
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10, // Matte/Sharper
                        offset: const Offset(0, -2), // Closer
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Wrap content tightly
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo and Title Row
                      Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icon/exanor_blue.png',
                              // Removed color tint to show original logo
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),

                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "YOUR NEEDS",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.0,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "Under One Umbrella",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.9),
                                  height: 1.0,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Log in or Sign up",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Phone Input Field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(
                                  0xFFF1F5F9,
                                ), // Slight grey fill instead of white to define area without border
                          borderRadius: BorderRadius.circular(16),
                          // Border removed as requested
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "+$_countryCode",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Container(
                              height: 24,
                              width: 1.5,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textAlignVertical: TextAlignVertical.center,
                                // Trigger rebuild to show/hide suffix icon
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
                                  contentPadding: EdgeInsets.zero,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  hintText: "0000000000",
                                  hintStyle: GoogleFonts.inter(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(
                                          0.2,
                                        ), // More subtle placeholder
                                    fontSize: 18, // Match input size
                                    fontWeight: FontWeight.w600,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  suffixIconConstraints: const BoxConstraints(
                                    maxHeight: 24,
                                    maxWidth: 40,
                                  ),
                                  suffixIcon: _phoneController.text.isNotEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _phoneController.clear(),
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.6),
                                              ),
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
                            backgroundColor: theme
                                .colorScheme
                                .primary, // Typically Green/Brand color
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitPhoneNumber() async {
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
