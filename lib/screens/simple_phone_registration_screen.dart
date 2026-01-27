import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:exanor/screens/simple_otp_verification_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // Add this import

class SimplePhoneRegistrationScreen extends StatefulWidget {
  const SimplePhoneRegistrationScreen({super.key});

  @override
  State<SimplePhoneRegistrationScreen> createState() =>
      _SimplePhoneRegistrationScreenState();
}

class _SimplePhoneRegistrationScreenState
    extends State<SimplePhoneRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();

  CountryCode _selectedCountry = CountryCode.fromCountryCode('IN');
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    print('📱 SimplePhoneRegistrationScreen: initState called');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    print('📱 SimplePhoneRegistrationScreen: dispose called');
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Elegant Background - Subtle Mesh/Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 1.0],
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainer.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                height: size.height * 0.88,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),

                        // Icon or Brand Mark (Minimal)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.phone_iphone_rounded,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Standard, Professional Header
                        Text(
                          "Enter your mobile number",
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We will send you a confirmation code to verify your identity.",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Input Container
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withOpacity(
                                  0.05,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              // Country Code Picker
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLow
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CountryCodePicker(
                                  onChanged: (code) =>
                                      setState(() => _selectedCountry = code),
                                  initialSelection: 'IN',
                                  favorite: const ['+91', 'IN'],
                                  showFlag: true, // Show flag in main view
                                  showFlagDialog: true, // Show flags in list
                                  showCountryOnly: false,
                                  alignLeft: false,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  textStyle: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  dialogTextStyle: GoogleFonts.outfit(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  searchDecoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    hintText: 'Search country',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Phone Input
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                    letterSpacing: 0.5,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty)
                                      return null;
                                    if (value.length != 10) return null;
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: '00000 00000',
                                    hintStyle: GoogleFonts.outfit(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.2),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Premium Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitPhoneNumber,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              shadowColor: theme.colorScheme.primary
                                  .withOpacity(0.4),
                              padding: EdgeInsets.zero,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: theme.colorScheme.onPrimary,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Continue',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Safe Terms
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Standard data rates may apply',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.4,
                                ),
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
          ),
        ],
      ),
    );
  }

  void _submitPhoneNumber() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty || phone.length != 10) {
      _showErrorSnackBar("Please enter a valid 10-digit mobile number");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cleanPhoneNumber = phone.replaceAll(RegExp(r'\D'), '');
      final countryCode =
          _selectedCountry.dialCode?.replaceAll('+', '') ?? '91';
      final fullPhoneNumber = '$countryCode$cleanPhoneNumber';

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
          _showErrorSnackBar(
            response['data']?['message'] ?? 'Failed to send OTP',
          );
        }
      }
    } catch (e) {
      print('❌ SimplePhoneRegistration Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Network error. Please try again.');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
