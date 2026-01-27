import 'package:flutter/material.dart';

import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/screens/onboarding_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/in_app_update_service.dart';
import 'package:exanor/services/user_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as developer;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    developer.log(
      '🚀 SplashScreen: initState called - starting splash screen',
      name: 'SplashScreen',
    );
    _initAnimations();
    _startAnimations();
    _startTimer();
  }

  void _initAnimations() {
    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Scale animation controller
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Shimmer animation controller
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Define animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    // Start animations with delays
    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scaleController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _shimmerController.repeat(reverse: true);
      }
    });
  }

  void _startTimer() {
    developer.log(
      '⏰ SplashScreen: Starting 3-second timer',
      name: 'SplashScreen',
    );
    _timer = Timer(const Duration(seconds: 3), () async {
      developer.log(
        '⏰ SplashScreen: Timer completed, starting navigation',
        name: 'SplashScreen',
      );
      if (mounted) {
        await _waitForConfigurationAndNavigate();
      }
    });
  }

  Future<void> _waitForConfigurationAndNavigate() async {
    developer.log(
      '🔄 SplashScreen: Waiting for API configuration to complete...',
      name: 'SplashScreen',
    );

    // Wait for API service configuration to complete
    try {
      // Check if configuration is already ready
      final config = ApiService.getCurrentConfiguration();
      developer.log(
        '📊 SplashScreen: Current config status: $config',
        name: 'SplashScreen',
      );

      if (!config['isConfigurationCached']) {
        developer.log(
          '⏳ SplashScreen: API configuration not ready, waiting...',
          name: 'SplashScreen',
        );

        // Initialize configuration if not already done
        await ApiService.initializeConfiguration();
        developer.log(
          '✅ SplashScreen: API configuration completed',
          name: 'SplashScreen',
        );
      } else {
        developer.log(
          '✅ SplashScreen: API configuration already ready',
          name: 'SplashScreen',
        );
      }
    } catch (e) {
      developer.log(
        '❌ SplashScreen: Error waiting for configuration: $e',
        name: 'SplashScreen',
      );
      // Continue anyway - API service will use defaults
    }

    // Check for critical updates after configuration is ready
    developer.log(
      '🔍 SplashScreen: Checking for critical app updates...',
      name: 'SplashScreen',
    );
    try {
      if (mounted) {
        await InAppUpdateService.instance.checkForCriticalUpdates(context);
        developer.log(
          '✅ SplashScreen: Update check completed',
          name: 'SplashScreen',
        );
      }
    } catch (e) {
      developer.log(
        '❌ SplashScreen: Error checking for updates: $e',
        name: 'SplashScreen',
      );
      // Continue anyway - updates are not critical for app startup
    }

    // Now proceed with auth check and navigation
    await _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');
      final userId = prefs.getString('user_id');
      final firstName = prefs.getString('first_name');

      // DETAILED DEBUG LOGGING
      developer.log(
        '🔍 SplashScreen: Token Check Debug Info:',
        name: 'SplashScreen',
      );
      developer.log(
        '   Access Token: ${accessToken != null ? "EXISTS (${accessToken.substring(0, 20)}...)" : "NULL"}',
        name: 'SplashScreen',
      );
      developer.log(
        '   Refresh Token: ${refreshToken != null ? "EXISTS (${refreshToken.substring(0, 20)}...)" : "NULL"}',
        name: 'SplashScreen',
      );
      developer.log('   User ID: ${userId ?? "NULL"}', name: 'SplashScreen');
      developer.log(
        '   First Name: ${firstName ?? "NULL"}',
        name: 'SplashScreen',
      );

      if (mounted) {
        if (accessToken != null && refreshToken != null) {
          // Tokens exist, but let's verify if they are valid
          developer.log(
            '🔐 SplashScreen: BOTH TOKENS FOUND - Verifying session with API...',
            name: 'SplashScreen',
          );

          try {
            await UserService.viewUserData();
            developer.log(
              '✅ SplashScreen: Session verified successfully! Navigating to HomeScreen',
              name: 'SplashScreen',
            );
          } catch (e) {
            developer.log(
              '⚠️ SplashScreen: Session verification threw error: $e (Type: ${e.runtimeType})',
              name: 'SplashScreen',
            );

            if (e is ApiAuthException) {
              developer.log(
                '❌ SplashScreen: Auth Exception detected (${e.statusCode}), clearing session...',
                name: 'SplashScreen',
              );
              _handleInvalidSession();
              return;
            }

            developer.log(
              '⚠️ SplashScreen: Non-auth error, but tokens exist. Proceeding to Home anyway.',
              name: 'SplashScreen',
            );
            // Fallthrough to navigation
          }

          if (mounted) {
            developer.log(
              '🏠 SplashScreen: Navigating to HomeScreen NOW',
              name: 'SplashScreen',
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        } else {
          // No tokens found, navigate to OnboardingScreen
          developer.log(
            '❌ SplashScreen: TOKENS MISSING - Access: ${accessToken != null}, Refresh: ${refreshToken != null}',
            name: 'SplashScreen',
          );
          developer.log(
            '🚪 SplashScreen: Navigating to OnboardingScreen',
            name: 'SplashScreen',
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    } catch (e) {
      // If there's an error checking tokens, default to onboarding
      developer.log(
        '❌ SplashScreen: EXCEPTION in _checkAuthAndNavigate: $e',
        name: 'SplashScreen',
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  Future<void> _handleInvalidSession() async {
    // Clear tokens just in case
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_id');
    } catch (e) {
      // ignore
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _fadeAnimation,
            _scaleAnimation,
            _shimmerAnimation,
          ]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Base logo
                        Image.asset(
                          'assets/icon/exanor_icon_512x512px.png',
                          width: 200,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if the image doesn't exist
                            return Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3), // Flutter blue
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.flutter_dash,
                                size: 100,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),

                        // Shimmer overlay
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Transform.translate(
                              offset: Offset(_shimmerAnimation.value * 100, 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.7),
                                      Colors.white.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                                  ),
                                ),
                                width: 100,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
