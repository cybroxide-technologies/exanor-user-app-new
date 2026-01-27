import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:exanor/screens/otp_verification_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/enhanced_translation_service.dart';
import 'package:exanor/components/language_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneRegistrationScreen extends StatefulWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  State<PhoneRegistrationScreen> createState() =>
      _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState extends State<PhoneRegistrationScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  CountryCode _selectedCountry = CountryCode.fromCountryCode('IN');
  bool _isLoading = false;

  // Enhanced translation service
  final EnhancedTranslationService _enhancedTranslation =
      EnhancedTranslationService.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Disabled automatic language selector to prevent navigation conflicts
    // User can still manually select language using the button below
    // _checkFirstTimeLanguageSelection();
  }

  // Commented out to prevent navigation conflicts
  // User can still manually select language using the button in the UI
  /*
  Future<void> _checkFirstTimeLanguageSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedLanguage = prefs.getString('selected_language');

      // Check if no language has been selected (first time launch)
      // or if language is still set to default English
      if (selectedLanguage == null) {
        // Wait for the widget to build, then show language selector
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showFirstTimeLanguageSelector();
          }
        });
      }
    } catch (e) {
      print('❌ Error checking first-time language selection: $e');
    }
  }

  Future<void> _showFirstTimeLanguageSelector() async {
    try {
      await showLanguageSelector(
        context,
        navigateToSplashOnSelection:
            false, // Changed to false to prevent navigation issues
        onLanguageSelected: (language) {
          print('🌐 First-time language selected: ${language.name}');
        },
      );
    } catch (e) {
      print('❌ Error showing first-time language selector: $e');
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Dynamic Background
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withOpacity(0.15),
              ),
            ),
          ),
          // Blur effect for glassmorphism
          Positioned.fill(
            child: Container(color: theme.colorScheme.surface.withOpacity(0.9)),
          ),

          UniversalTranslationWrapper(
            excludePatterns: [
              '+',
              '@',
              '.com',
              'API',
            ], // Don't translate phone numbers, technical terms
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),

                      // Header with Logo
                      Center(
                        child: Hero(
                          tag: 'app_logo',
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.2,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icon/exanor_icon_512x512px.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Welcome Text
                      FadeTransition(
                        opacity: const AlwaysStoppedAnimation(1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              'Welcome Back',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TranslatedText(
                              'Enter your number to continue',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Glassmorphic Input Container
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.1),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              'Phone Number',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // Country Code Picker
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainer
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withOpacity(0.2),
                                    ),
                                  ),
                                  child: CountryCodePicker(
                                    onChanged: (CountryCode countryCode) {
                                      setState(() {
                                        _selectedCountry = countryCode;
                                      });
                                    },
                                    initialSelection: 'IN',
                                    favorite: const ['+91', 'IN'],
                                    showCountryOnly: false,
                                    showOnlyCountryWhenClosed: false,
                                    alignLeft: false,
                                    showFlag: true,
                                    showFlagMain: true,
                                    flagWidth: 24,
                                    padding: EdgeInsets.zero,
                                    textStyle: theme.textTheme.bodyLarge
                                        ?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    searchDecoration: InputDecoration(
                                      hintText: 'Search country',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Phone Number Field
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9]'),
                                      ),
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      if (value.length != 10) {
                                        return 'Invalid number';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      hintText: '98765 43210',
                                      hintStyle: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.3),
                                          ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Continue Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitPhoneNumber,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.zero,
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TranslatedText(
                                      'Continue',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
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

                      const SizedBox(height: 32),

                      // Language Selection
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            await showLanguageSelector(
                              context,
                              navigateToSplashOnSelection: false,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.language,
                                  size: 16,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                                const SizedBox(width: 8),
                                TranslatedText(
                                  'Change Language',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Format phone number to 12 digits (e.g., 918822036338)
        final cleanPhoneNumber = _phoneController.text.replaceAll(
          RegExp(r'\D'),
          '',
        );
        final countryCode =
            _selectedCountry.dialCode?.replaceAll('+', '') ?? '91';
        final fullPhoneNumber = '$countryCode$cleanPhoneNumber';

        print('📞 Sending OTP to: $fullPhoneNumber');

        // Send OTP API call
        final response = await ApiService.post(
          '/send-otp/',
          body: {'phone_number': fullPhoneNumber},
        );

        print('📨 Send OTP Response: $response');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Check if response status is 200
          // Response format: {"status":200,"message":"OTP Sent"}
          if (response['data'] != null && response['data']['status'] == 200) {
            print('✅ OTP sent successfully');

            // Navigate to OTP verification screen
            // Pass the full numeric phone number (e.g., 918822036338)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationScreen(
                  phoneNumber:
                      fullPhoneNumber, // Pass full numeric phone number
                ),
              ),
            );
          } else {
            // Show error message
            print('❌ Failed to send OTP: ${response['data']}');
            _showErrorSnackBar('Failed to send OTP. Please try again.');
          }
        }
      } catch (e) {
        print('❌ Error sending OTP: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar(
            'Network error. Please check your connection and try again.',
          );
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TranslatedText(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
