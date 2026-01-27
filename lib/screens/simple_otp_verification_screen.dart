import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:exanor/components/otp_input_section.dart';
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
    extends State<SimpleOTPVerificationScreen>
    with SingleTickerProviderStateMixin {
  String _otpCode = '';
  bool _isLoading = false;
  bool _isResendLoading = false;
  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _startResendTimer();

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
    _timer?.cancel();
    _animationController.dispose();
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

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Elegant Background
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
                height: size.height * 0.85,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          "Verify code",
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(
                                text: "Check your SMS for the code sent to ",
                              ),
                              TextSpan(
                                text: widget.phoneNumber,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        // OTP Input
                        Center(
                          child: OTPInputSection(
                            otpCode: _otpCode,
                            onChanged: (code) {
                              setState(() => _otpCode = code);
                            },
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Verify Button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _otpCode.length == 4 && !_isLoading
                                ? _verifyOTP
                                : null,
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
                                        'Verify',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Resend Code
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isResendLoading)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: _canResend ? _resendCode : null,
                                  child: Text(
                                    _canResend
                                        ? 'Resend Code'
                                        : 'Resend in ${_resendTimer}s',
                                    style: GoogleFonts.outfit(
                                      color: _canResend
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface
                                                .withOpacity(0.4),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 2),
                        const SizedBox(height: 20),
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
          _showSnackBar('Verification code resent!', isError: false);
          _startResendTimer();
        } else {
          _showSnackBar('Failed to resend OTP');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResendLoading = false);
        _showSnackBar('Network error. Please try again.');
      }
    }
  }

  void _verifyOTP() async {
    setState(() => _isLoading = true);

    try {
      print('📞 Verifying OTP for phone: ${widget.phoneNumber}');

      final response = await ApiService.post(
        '/sign-up/',
        body: {
          'phone_number': widget.phoneNumber,
          'otp': _otpCode,
          'signup': true,
        },
      );

      if (response['headers'] != null) {
        await _saveCookiesFromHeaders(response['headers']);
      }

      if (mounted) {
        setState(() => _isLoading = false);

        if (response['data'] != null) {
          final responseData = response['data'];
          final status = responseData['status'];
          final statusCode = status is int
              ? status
              : int.tryParse(
                  status.toString(),
                ); // Handle potential String "200"

          if (statusCode == 200) {
            print(
              '🎉 SimpleOTP: OTP Verification Successful! Storing tokens...',
            );
            print(
              '📦 SimpleOTP: Response Data Keys: ${responseData.keys.toList()}',
            );

            // Save tokens and user data
            if (responseData['access_token'] != null) {
              print(
                '✅ SimpleOTP: Storing access_token: ${responseData['access_token'].substring(0, 20)}...',
              );
              await _storeToken('access_token', responseData['access_token']);
            } else {
              print('❌ SimpleOTP: No access_token in response!');
            }

            // Extract refresh_token from Set-Cookie header
            if (response['headers'] != null) {
              final headers = response['headers'] as Map<String, dynamic>;
              final setCookieHeader = headers['set-cookie'];

              print('🍪 SimpleOTP: Set-Cookie header: $setCookieHeader');

              if (setCookieHeader != null) {
                String? refreshToken;

                // The set-cookie header can be a String or List
                if (setCookieHeader is String) {
                  refreshToken = _extractRefreshTokenFromCookie(
                    setCookieHeader,
                  );
                } else if (setCookieHeader is List) {
                  // Multiple cookies, find the refresh_token one
                  for (var cookie in setCookieHeader) {
                    refreshToken = _extractRefreshTokenFromCookie(
                      cookie.toString(),
                    );
                    if (refreshToken != null) break;
                  }
                }

                if (refreshToken != null) {
                  print(
                    '✅ SimpleOTP: Extracted refresh_token from cookie: ${refreshToken.substring(0, 20)}...',
                  );
                  await _storeToken('refresh_token', refreshToken);
                } else {
                  print(
                    '❌ SimpleOTP: Could not extract refresh_token from Set-Cookie header!',
                  );
                }
              } else {
                print('❌ SimpleOTP: No Set-Cookie header found!');
              }
            }

            if (responseData['csrf_token'] != null) {
              print('✅ SimpleOTP: Storing csrf_token');
              await _storeToken('csrf_token', responseData['csrf_token']);
            }

            if (responseData['user_data'] != null) {
              print(
                '✅ SimpleOTP: Storing user_data: ${responseData['user_data']}',
              );
              await _storeUserData(responseData['user_data']);
            } else {
              print('❌ SimpleOTP: No user_data in response!');
            }

            final message = responseData['message'];

            if (message == 'Login successful') {
              _navigateHome();
            } else if (message == 'User created') {
              // Check profile completeness
              final userData = responseData['user_data'];
              // Simple check for completion
              bool needsCompletion = false;
              if (userData != null) {
                final firstName = userData['first_name'];
                if (firstName == 'unnamed' || firstName == null)
                  needsCompletion = true;
              }

              if (needsCompletion) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountCompletionScreen(
                      accessToken: responseData['access_token'],
                      csrfToken: responseData['csrf_token'],
                      userData: userData,
                    ),
                  ),
                  (route) => false,
                );
              } else {
                _navigateHome();
              }
            } else {
              _showSnackBar(message ?? 'Verification failed');
            }
          } else {
            _showSnackBar(responseData['message'] ?? 'Verification failed');
          }
        } else {
          _showSnackBar('Invalid response from server');
        }
      }
    } catch (e) {
      print('❌ Verification Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Verification failed. Please try again.');
      }
    }
  }

  void _navigateHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _storeToken(String key, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, token);
  }

  Future<void> _storeUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    // Helper to safely store strings
    Future<void> save(String key, dynamic value) async {
      if (value != null) await prefs.setString(key, value.toString());
    }

    await save('user_id', userData['id']);
    await save('first_name', userData['first_name']);
    await save('last_name', userData['last_name']);
    await save('phone_number', userData['phone_number']);
    await save('email', userData['email']);
    await save('img_url', userData['img_url']);
    // ... add others as needed
  }

  /// Extract refresh_token value from Set-Cookie header
  /// Cookie format: "refresh_token=<token_value>; Domain=...; Path=...; ..."
  String? _extractRefreshTokenFromCookie(String cookieString) {
    if (!cookieString.contains('refresh_token=')) {
      return null;
    }

    try {
      // Find the refresh_token= part
      final startIndex = cookieString.indexOf('refresh_token=');
      if (startIndex == -1) return null;

      // Extract everything after "refresh_token="
      final afterEquals = cookieString.substring(
        startIndex + 'refresh_token='.length,
      );

      // The token value ends at the first semicolon or end of string
      final endIndex = afterEquals.indexOf(';');
      final tokenValue = endIndex == -1
          ? afterEquals.trim()
          : afterEquals.substring(0, endIndex).trim();

      return tokenValue.isNotEmpty ? tokenValue : null;
    } catch (e) {
      print('❌ Error extracting refresh_token from cookie: $e');
      return null;
    }
  }

  Future<void> _saveCookiesFromHeaders(Map<String, String> headers) async {
    try {
      final setCookies = headers.entries
          .where((entry) => entry.key.toLowerCase() == 'set-cookie')
          .toList();

      if (setCookies.isEmpty) return;

      for (final cookie in setCookies) {
        await _parseCookieString(cookie.value);
      }
    } catch (e) {
      print('❌ Error saving cookies: $e');
    }
  }

  Future<void> _parseCookieString(String cookieString) async {
    try {
      final parts = cookieString.split(';');
      if (parts.isEmpty) return;

      final nameValue = parts[0].trim();
      final separatorIndex = nameValue.indexOf('=');
      if (separatorIndex == -1) return;

      final name = nameValue.substring(0, separatorIndex).trim();
      final value = nameValue.substring(separatorIndex + 1).trim();

      final prefs = await SharedPreferences.getInstance();

      if (name.toLowerCase() == 'refresh_token' ||
          name.toLowerCase() == 'refreshtoken') {
        await prefs.setString('refresh_token_cookie', value);
      } else if (name.toLowerCase() == 'csrf_token' ||
          name.toLowerCase() == 'csrftoken') {
        await prefs.setString('csrf_token_cookie', value);
      }
    } catch (e) {
      print('❌ Error parsing cookie: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
