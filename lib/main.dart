import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/notification_service.dart';
import 'package:exanor/services/translation_service.dart';
import 'package:exanor/screens/SplashScreen.dart';
import 'package:exanor/screens/onboarding_screen.dart';
import 'package:exanor/screens/simple_phone_registration_screen.dart';
import 'package:exanor/screens/otp_verification_screen.dart';
import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/screens/location_selection_screen.dart';
import 'package:exanor/screens/saved_addresses_screen.dart';
import 'package:exanor/screens/remote_config_debug_screen.dart';
import 'package:exanor/screens/orders_list_screen.dart';
// REMOVED: Deleted screens (chat, subscription, profiles, refer & earn, feed, taxi)

import 'package:exanor/config/theme_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:exanor/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:exanor/services/enhanced_translation_service.dart';
import 'package:exanor/services/rewarded_ads_service.dart';
import 'package:exanor/services/interstitial_ads_service.dart';
import 'package:exanor/services/analytics_service.dart';
import 'package:exanor/services/crashlytics_service.dart';
import 'package:exanor/services/performance_service.dart';
import 'package:exanor/components/navigation_performance_tracker.dart';
import 'package:exanor/screens/refer_and_earn_screen.dart';
import 'package:exanor/widgets/connectivity_overlay.dart';
import 'package:exanor/screens/campaigns_screen.dart';

/// Top-level function to handle background messages
/// This must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  developer.log(
    '📨 Background message received: ${message.messageId}',
    name: 'FCM',
  );

  // Handle background message here
  // You can update local storage, show notifications, etc.

  if (message.notification != null) {
    developer.log(
      '🔔 Background notification: ${message.notification!.title}',
      name: 'FCM',
    );
  }
}

/// Get platform detection data
Map<String, bool> _getPlatformData() {
  return {
    'is_android': !kIsWeb && Platform.isAndroid,
    'is_ios': !kIsWeb && Platform.isIOS,
    'is_web': kIsWeb,
    'is_macos': !kIsWeb && Platform.isMacOS,
    'is_windows': !kIsWeb && Platform.isWindows,
    'is_linux': !kIsWeb && Platform.isLinux,
  };
}

/// Initialize image picker plugin to avoid MissingPluginException
Future<void> _initializeImagePicker() async {
  try {
    // Force initialization of image_picker
    final ImagePicker picker = ImagePicker();
    print('📸 ImagePicker instance created: ${picker.hashCode}');

    // On Android, try to access the plugin early to trigger initialization
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Just accessing the instance isn't enough on some devices
      // Try to get available cameras which forces plugin registration
      try {
        // This will trigger plugin registration but might throw an exception
        // which we can safely ignore as we're just trying to initialize
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1);
        print('📸 ImagePicker pre-initialized successfully');
      } catch (e) {
        // Ignore errors here, we're just trying to initialize the plugin
        print('📸 ImagePicker pre-initialization attempt: $e');
      }
    }

    // On iOS, try a different approach
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final status = await Permission.photos.status;
        print('📸 iOS photo permission status: $status');
      } catch (e) {
        print('📸 iOS permission check error: $e');
      }
    }
  } on MissingPluginException catch (e) {
    print('❌ Error initializing ImagePicker: $e');
  } catch (e) {
    print('❌ Unexpected error initializing ImagePicker: $e');
  }
}

/// Initialize translation services
Future<void> _initializeServices() async {
  try {
    // Initialize basic translation service
    await TranslationService.instance.initialize();

    // Initialize enhanced translation service
    await EnhancedTranslationService.instance.initialize();

    // Preload common translations for better performance
    await EnhancedTranslationService.instance.preloadCommonTranslations();

    // Set up crashlytics for translation services
    await CrashlyticsService.instance.setupTranslationErrorReporting(
      TranslationService.instance.currentLanguageCode,
    );

    print('✅ All translation services initialized successfully');
  } catch (e) {
    print('❌ Error initializing translation services: $e');
  }
}

/// Initialize Mobile Ads SDK
Future<void> _initializeMobileAds() async {
  try {
    await RewardedAdsService.initialize();
    await InterstitialAdsService.initialize();

    // Preload ads for better user experience (don't await these as they can take time)
    RewardedAdsService.instance.preloadAd();
    InterstitialAdsService.instance.preloadAd();

    // Set up crashlytics for ads
    await CrashlyticsService.instance.setupAdsErrorReporting();
  } catch (e) {
    print('❌ Error initializing Mobile Ads SDK: $e');
    rethrow;
  }
}

/// Critical initialization that must complete before showing the app
/// This should be as minimal as possible to reduce startup time
Future<void> _criticalInitialization() async {
  // Only the absolute essentials needed before showing UI
  developer.log('🔧 Critical initialization starting...', name: 'Main');

  try {
    // Load environment variables (needed for API calls)
    await dotenv.load(fileName: ".env");
    developer.log('✅ Environment variables loaded', name: 'Main');
  } catch (e) {
    developer.log('❌ Failed to load .env: $e', name: 'Main');
  }

  // Initialize theme manager (sync operation, very fast)
  ThemeManager().initialize();

  // Initialize Firebase Core (required for other Firebase services)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('✅ Firebase Core initialized', name: 'Main');

    // Set up background message handler (lightweight)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    developer.log('❌ Firebase Core initialization failed: $e', name: 'Main');
  }

  // Set up auth failure callback
  ApiService.setAuthFailureCallback(() {
    runApp(
      MaterialApp(
        home: const SplashScreen(),
        navigatorKey: ApiService.navigatorKey,
      ),
    );
  });
}

/// Background initialization that runs while splash screen is visible
/// These services can take longer as the user is seeing the animation
Future<void> _backgroundInitialization() async {
  developer.log('🔄 Background initialization starting...', name: 'Main');

  // Initialize API Service configuration
  try {
    await ApiService.initializeConfiguration();
    ApiService.logCurrentConfiguration();
    developer.log('✅ API Service configuration initialized', name: 'Main');
  } catch (e) {
    developer.log('❌ API Service configuration failed: $e', name: 'Main');
  }

  // Initialize Performance Tracing (after Firebase is ready)
  try {
    await PerformanceService.instance.initialize();
    await PerformanceService.instance.traceAppStartup();
    developer.log('✅ Performance tracing started', name: 'Main');
  } catch (e) {
    developer.log('❌ Performance tracing failed: $e', name: 'Main');
  }

  // Initialize Crashlytics
  try {
    await CrashlyticsService.instance.initialize();

    FlutterError.onError = (errorDetails) {
      developer.log(
        '💥 Flutter Error: ${errorDetails.exception}',
        name: 'Crashlytics',
      );
      CrashlyticsService.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      developer.log('💥 Platform Error: $error', name: 'Crashlytics');
      CrashlyticsService.instance.recordError(error, stack, fatal: true);
      return true;
    };
    developer.log('✅ Crashlytics initialized', name: 'Main');
  } catch (e) {
    developer.log('❌ Crashlytics initialization failed: $e', name: 'Main');
  }

  // Initialize Remote Config and refresh API configuration
  try {
    await FirebaseRemoteConfigService.initialize();
    await ApiService.refreshConfiguration();
    ApiService.logCurrentConfiguration();
    developer.log('✅ Remote Config initialized', name: 'Main');
  } catch (e) {
    developer.log('❌ Remote Config initialization failed: $e', name: 'Main');
  }

  // Initialize non-critical services in parallel
  await Future.wait([
    // Translation Services
    _initializeServices()
        .then((_) {
          developer.log('✅ Translation Services initialized', name: 'Main');
        })
        .catchError((e) {
          developer.log('❌ Translation Services failed: $e', name: 'Main');
        }),

    // Mobile Ads SDK (skip in debug mode)
    kDebugMode
        ? Future<void>.value()
        : _initializeMobileAds()
              .then((_) {
                developer.log('✅ Mobile Ads SDK initialized', name: 'Main');
              })
              .catchError((e) {
                developer.log('❌ Mobile Ads SDK failed: $e', name: 'Main');
              }),

    // Analytics Service
    Future(() {
      AnalyticsService().initialize();
      developer.log('✅ Analytics Service initialized', name: 'Main');
    }).catchError((e) {
      developer.log('❌ Analytics Service failed: $e', name: 'Main');
    }),
  ]);

  // Complete startup trace
  try {
    await PerformanceService.instance.completeAppStartupTrace();
    developer.log('✅ Background initialization complete', name: 'Main');
  } catch (e) {
    developer.log('❌ Failed to complete startup trace: $e', name: 'Main');
  }
}

/// Completer to signal when background initialization is done
/// The SplashScreen can wait on this before navigating
final Completer<void> backgroundInitComplete = Completer<void>();

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('🚀 main() started - fast startup path', name: 'Main');

  // Only critical initialization before showing UI (minimal, fast)
  await _criticalInitialization();

  developer.log('🎯 Launching app immediately with SplashScreen', name: 'Main');

  // Start the app IMMEDIATELY with SplashScreen
  // This eliminates the "frozen logo" problem
  // Note: Error handling is set up via FlutterError.onError and
  // PlatformDispatcher.instance.onError in _backgroundInitialization()
  runApp(const MyApp());

  // Run background initialization in parallel while splash screen animates
  // The splash screen waits on backgroundInitComplete before navigating
  _backgroundInitialization()
      .then((_) {
        if (!backgroundInitComplete.isCompleted) {
          backgroundInitComplete.complete();
        }
      })
      .catchError((e) {
        developer.log('❌ Background initialization error: $e', name: 'Main');
        if (!backgroundInitComplete.isCompleted) {
          backgroundInitComplete
              .complete(); // Complete anyway so app doesn't hang
        }
      });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialMessage;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();

    // Initialize NotificationService with the navigator key
    NotificationService.initialize(ApiService.navigatorKey);

    // Set up Firebase Messaging listeners according to official documentation
    _setupFirebaseMessaging();
  }

  /// Set up Firebase Messaging listeners following official documentation pattern
  void _setupFirebaseMessaging() async {
    try {
      developer.log(
        '🔔 Setting up Firebase Messaging listeners...',
        name: 'FCM',
      );

      // Request notification permissions
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: true,
            sound: true,
          );

      developer.log(
        '📋 Notification permission: ${settings.authorizationStatus}',
        name: 'FCM',
      );

      // Get initial message (if app was opened from a notification)
      FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
      ) {
        if (message != null) {
          developer.log(
            '📨 Initial message found: ${message.messageId}',
            name: 'FCM',
          );
          setState(() {
            _resolved = true;
            _initialMessage = message.messageId;
          });
          // App was opened from a notification - navigate to splash screen
          _navigateToSplashScreen();
        } else {
          developer.log('📨 No initial message found', name: 'FCM');
          setState(() {
            _resolved = true;
          });
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log(
          '📨 Foreground message received: ${message.messageId}',
          name: 'FCM',
        );

        if (message.notification != null) {
          developer.log(
            '🔔 Foreground notification: ${message.notification!.title}',
            name: 'FCM',
          );
        }

        // Show in-app notification or handle as needed
        // The app is already open, so just show a notification
        if (NotificationService.shouldShowInAppNotification(message)) {
          NotificationService.showInAppNotification(message);
        }
      });

      // Handle notification taps when app is in background or terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        developer.log(
          '📨 Notification tapped - opening splash screen: ${message.messageId}',
          name: 'FCM',
        );

        if (message.notification != null) {
          developer.log(
            '🔔 Opened from notification: ${message.notification!.title}',
            name: 'FCM',
          );
        }

        // Always navigate to splash screen - simplest and most reliable approach
        _navigateToSplashScreen();
      });

      // Get and send FCM token to server
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        developer.log(
          '🔑 FCM token obtained: ${token.substring(0, 50)}...',
          name: 'FCM',
        );
        _sendTokenToServer(token);
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        developer.log(
          '🔄 FCM token refreshed: ${token.substring(0, 50)}...',
          name: 'FCM',
        );
        _sendTokenToServer(token);
      });

      developer.log(
        '✅ Firebase Messaging listeners set up successfully',
        name: 'FCM',
      );
    } catch (e) {
      developer.log('❌ Error setting up Firebase Messaging: $e', name: 'FCM');
    }
  }

  /// Navigate to splash screen - handles all app flow logic
  void _navigateToSplashScreen() {
    try {
      developer.log(
        '🚀 Navigating to splash screen from notification',
        name: 'FCM',
      );

      // Use the navigator key to navigate to splash screen
      if (ApiService.navigatorKey.currentState != null) {
        ApiService.navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
        developer.log('✅ Navigation to splash screen completed', name: 'FCM');
      } else {
        developer.log('❌ Navigator key not available', name: 'FCM');
      }
    } catch (e) {
      developer.log('❌ Error navigating to splash screen: $e', name: 'FCM');
    }
  }

  /// Send FCM token to server
  void _sendTokenToServer(String token) async {
    try {
      developer.log(
        '📤 Checking authentication before sending FCM token...',
        name: 'FCM',
      );

      // Check if user is authenticated before sending token
      final isAuthenticated = await ApiService.isLoggedIn();

      if (!isAuthenticated) {
        developer.log(
          '⚠️ User not authenticated, skipping FCM token submission',
          name: 'FCM',
        );
        return;
      }

      developer.log('📤 Sending FCM token to server...', name: 'FCM');

      // Detect platform
      final platformData = _getPlatformData();

      // Send token to backend server
      ApiService.post(
            '/create-notification-token/',
            body: {'fcm_token': token, ...platformData},
            useBearerToken: true,
          )
          .then((response) {
            developer.log(
              '✅ FCM token sent to server successfully',
              name: 'FCM',
            );
          })
          .catchError((error) {
            developer.log(
              '❌ Failed to send FCM token to server: $error',
              name: 'FCM',
            );
          });
    } catch (e) {
      developer.log('❌ Error in _sendTokenToServer: $e', name: 'FCM');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager(),
      builder: (context, child) {
        return AnimatedTheme(
          duration: ThemeManager.animationDuration,
          curve: ThemeManager.animationCurve,
          data: ThemeManager().getTheme(context),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'exanor',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light, // Templorary force light mode

            navigatorKey: ApiService.navigatorKey,
            navigatorObservers: [
              AnalyticsService().observer,
              NavigationPerformanceObserver(),
            ],
            home: const SplashScreen(),
            // Note: Translation system is now integrated throughout the app
            // - Bottom Navigation: Translated labels for Home, Register, Refer, Messages, Alerts
            // - Category Lists: API responses translated (Professionals, Businesses, Employees, subcategories)
            // - Search Screen: Translated title, placeholders, error messages, and search results
            // - Sliver App Bar: Translated search text, category names, error messages
            // - Universal Translation: All user-facing text automatically translated
            // - Language Selector: Beautiful UI with 20+ languages including 8 Indian languages
            // - Profile Screen: User data and UI text translated
            // - Home Screen: Section headers and help text translated
            // Access language selector: FAB on home screen or language tools in selector
            builder: (context, child) {
              return ConnectivityOverlay(child: child!);
            },
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/phone_registration': (context) =>
                  const SimplePhoneRegistrationScreen(),
              '/otp_verification': (context) =>
                  const OTPVerificationScreen(phoneNumber: ''),
              '/home': (context) => const HomeScreen(),
              '/location_selection': (context) =>
                  const LocationSelectionScreen(),
              '/saved_addresses': (context) => const SavedAddressesScreen(),
              '/remote_config_debug': (context) =>
                  const RemoteConfigDebugScreen(),
              '/orders': (context) => const OrdersListScreen(),
              '/refer_and_earn': (context) => const ReferAndEarnScreen(),
              '/restart_app': (context) => const SplashScreen(),
              '/campaigns': (context) => const CampaignsScreen(),
              // REMOVED: Routes for deleted screens (profiles, chat, subscription, etc.)
            },
          ),
        );
      },
    );
  }
}
