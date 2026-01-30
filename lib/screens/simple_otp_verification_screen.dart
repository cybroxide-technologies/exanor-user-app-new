import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/screens/account_completion_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class SimpleOTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const SimpleOTPVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<SimpleOTPVerificationScreen> createState() =>
      _SimpleOTPVerificationScreenState();
}

class _SimpleOTPVerificationScreenState
    extends State<SimpleOTPVerificationScreen> {
  String _otpCode = '';
  bool _isLoading = false;
  bool _isResendLoading = false;
  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Grid background colors
  final List<Map<String, dynamic>> _gridItems = [
    {'color': const Color(0xFFFFF7ED), 'icon': Icons.lunch_dining_rounded},
    {'color': const Color(0xFFF0FDF4), 'icon': Icons.eco_rounded},
    {'color': const Color(0xFFEFF6FF), 'icon': Icons.inventory_2_rounded},
    {'color': const Color(0xFFFAF5FF), 'icon': Icons.shopping_bag_rounded},
    {'color': const Color(0xFFFEF2F2), 'icon': Icons.favorite_rounded},
    {'color': const Color(0xFFF0F9FF), 'icon': Icons.local_drink_rounded},
    {'color': const Color(0xFFFFFBEB), 'icon': Icons.egg_alt_rounded},
    {'color': const Color(0xFFFDF4FF), 'icon': Icons.checkroom_rounded},
    {'color': const Color(0xFFECFCCB), 'icon': Icons.spa_rounded},
    {'color': const Color(0xFFF1F5F9), 'icon': Icons.watch_rounded},
    {
      'color': const Color(0xFFEEF2FF),
      'icon': Icons.local_laundry_service_rounded,
    },
    {'color': const Color(0xFFFDF2F8), 'icon': Icons.stroller_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: CircleAvatar(
            backgroundColor: isDark ? Colors.white12 : Colors.white,
            radius: 20,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: theme.colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Background Grid (Matches Registration)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.5,
            child: Opacity(
              opacity: isDark ? 0.3 : 0.6, // Faded for OTP
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  72,
                  16,
                  0,
                ), // Top padding for AppBar
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            top: 0,
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(), // Pushes content to bottom

                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black : Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isDark ? 0.3 : 0.05,
                                  ),
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
                                // Logo and Title - Brand Lockup
                                Column(
                                  children: [
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

                                    // Divider / Subtitle
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          height: 1,
                                          width: 24,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.1),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Verification Code",
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
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.1),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                          height: 1.4,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'We\'ve sent a code to ',
                                          ),
                                          TextSpan(
                                            text: widget.phoneNumber,
                                            style: TextStyle(
                                              color:
                                                  theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    // OTP Boxes
                                    GestureDetector(
                                      onTap: () {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(_focusNode);
                                        SystemChannels.textInput.invokeMethod(
                                          'TextInput.show',
                                        );
                                      },
                                      child: Container(
                                        color: Colors.transparent,
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        child: Wrap(
                                          spacing: 12,
                                          alignment: WrapAlignment.center,
                                          children: List.generate(4, (index) {
                                            final isFilled =
                                                index < _otpCode.length;
                                            final isFocused =
                                                index == _otpCode.length &&
                                                _focusNode.hasFocus;
                                            final char = isFilled
                                                ? _otpCode[index]
                                                : '';

                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF0F172A)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isFocused
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : isDark
                                                      ? Colors.white24
                                                      : theme
                                                            .colorScheme
                                                            .outline
                                                            .withOpacity(0.2),
                                                  width: isFocused ? 2 : 1.5,
                                                ),
                                                boxShadow: isFocused
                                                    ? [
                                                        BoxShadow(
                                                          color: theme
                                                              .colorScheme
                                                              .primary
                                                              .withOpacity(
                                                                0.25,
                                                              ),
                                                          blurRadius: 12,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ]
                                                    : [],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  char,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ),

                                    // Hidden text field - positioned but invisible
                                    // We give it 1x1 size so the system treats it as "visible" for focus purposes
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child: Opacity(
                                        opacity: 0,
                                        child: SizedBox(
                                          width: 1,
                                          height: 1,
                                          child: TextField(
                                            controller: _otpController,
                                            focusNode: _focusNode,
                                            keyboardType: TextInputType.number,
                                            // Remove all borders to prevent the "blue line"
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              counterText: '',
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.transparent,
                                            ),
                                            showCursor: false,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                4,
                                              ),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                _otpCode = value;
                                              });
                                              if (value.length == 4) {
                                                _verifyOTP();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Action Button
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed:
                                        (_otpCode.length == 4 && !_isLoading)
                                        ? _verifyOTP
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      disabledBackgroundColor: theme
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.12),
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
                                            'Verify & Proceed',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Resend Link
                                Center(
                                  child: _isResendLoading
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: theme.colorScheme.primary,
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: _canResend
                                              ? _resendCode
                                              : null,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              _canResend
                                                  ? 'Resend code'
                                                  : 'Resend code in ${_resendTimer}s',
                                              style: GoogleFonts.inter(
                                                color: _canResend
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.4),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _resendCode() async {
    if (!_canResend || _isResendLoading) return;
    setState(() => _isResendLoading = true);

    try {
      final response = await ApiService.post(
        '/send-otp/',
        body: {'phone_number': widget.phoneNumber},
      );

      if (mounted) {
        setState(() => _isResendLoading = false);
        if (response['data'] != null && response['data']['status'] == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verification code resent!',
                style: GoogleFonts.inter(),
              ),
            ),
          );
          _startResendTimer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to resend OTP', style: GoogleFonts.inter()),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResendLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.')),
        );
      }
    }
  }

  void _verifyOTP() async {
    // Minimize keyboard immediately
    FocusScope.of(context).unfocus();

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(
        '/sign-up/',
        body: {
          'phone_number': widget.phoneNumber,
          'otp': _otpCode,
          'signup': true,
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (response['data'] != null) {
          final responseData = response['data'];
          final status = responseData['status'];
          final statusCode = status is int
              ? status
              : int.tryParse(status.toString());

          if (statusCode == 200) {
            if (responseData['access_token'] != null) {
              await _storeToken('access_token', responseData['access_token']);
            }
            if (responseData['csrf_token'] != null) {
              await _storeToken('csrf_token', responseData['csrf_token']);
            }
            if (responseData['user_data'] != null) {
              await _storeUserData(responseData['user_data']);
            }

            final message = responseData['message'];

            // Check for profile completion for both login and signup
            final userData = responseData['user_data'];
            bool needsCompletion = false;

            if (userData != null) {
              final firstName = userData['first_name'];
              if (firstName == 'unnamed' ||
                  firstName == null ||
                  firstName.toString().isEmpty) {
                needsCompletion = true;
              }
            }

            if (message == 'Login successful' || message == 'User created') {
              if (needsCompletion) {
                // Profile incomplete - redirect to completion screen
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountCompletionScreen(
                      accessToken: responseData['access_token'],
                      csrfToken: responseData['csrf_token'],
                      userData: userData ?? {},
                    ),
                  ),
                  (route) => false,
                );
              } else {
                // Profile complete - go to home
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message ?? 'Verification failed')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message'] ?? 'Verification failed'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification failed. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _storeToken(String key, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, token);
  }

  Future<void> _storeUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    Future<void> save(String key, dynamic value) async {
      if (value != null) await prefs.setString(key, value.toString());
    }

    await save('user_id', userData['id']);
    await save('first_name', userData['first_name']);
    await save('last_name', userData['last_name']);
    await save('phone_number', userData['phone_number']);
    await save('email', userData['email']);
    await save('img_url', userData['img_url']);
  }
}
