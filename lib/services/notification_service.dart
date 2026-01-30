import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;

/// Notification Service for handling in-app notifications
class NotificationService {
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize the notification service with navigator key
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    developer.log(
      '✅ NotificationService: Initialized with navigator key',
      name: 'Notification',
    );
  }

  /// Show in-app notification for foreground messages
  static Future<void> showInAppNotification(RemoteMessage message) async {
    if (_navigatorKey?.currentContext == null) {
      developer.log(
        '❌ NotificationService: No context available for in-app notification',
        name: 'Notification',
      );
      return;
    }

    final context = _navigatorKey!.currentContext!;
    final notification = message.notification;

    if (notification == null) {
      developer.log(
        '⚠️ NotificationService: No notification data in message',
        name: 'Notification',
      );
      return;
    }

    developer.log(
      '🔔 NotificationService: Showing in-app notification',
      name: 'Notification',
    );

    // 1. Play Haptic Feedback (Graceful handling, runs in parallel)
    Future(() async {
      try {
        // Continuous vibration for ~5 seconds (10 pulses x 500ms)
        for (int i = 0; i < 10; i++) {
          // Stop if context is gone (app closed/backgrounded)
          if (_navigatorKey?.currentContext == null) break;

          await HapticFeedback.vibrate();
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        // Ignore vibration errors
        developer.log(
          '⚠️ NotificationService: Haptics failed (non-fatal): $e',
          name: 'Notification',
        );
      }
    });

    // 2. Play Custom Notification Sound (Graceful handling)
    try {
      final player = AudioPlayer();
      // Configure player for notifications
      await player.setReleaseMode(ReleaseMode.stop);
      // Play the sound
      await player.play(
        AssetSource('notification_tone/system-notification-02-352442.mp3'),
        volume: 0.5, // Reasonable volume
      );
    } catch (e) {
      developer.log(
        '⚠️ NotificationService: Sound playback failed (non-fatal): $e',
        name: 'Notification',
      );
    }

    // Show a premium glassmorphic SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _handleNotificationTap(message);
            },
            borderRadius: BorderRadius.circular(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E).withOpacity(0.90)
                        : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Icon Container with Gradient
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.tertiary,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 2. Vertical Divider
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor.withOpacity(0.15),
                      ),
                      const SizedBox(width: 16),

                      // 3. Text Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (notification.title != null)
                              Text(
                                notification.title!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (notification.title != null &&
                                notification.body != null)
                              const SizedBox(height: 4),
                            if (notification.body != null)
                              Text(
                                notification.body!,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.65),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 20,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 4. Dismiss Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Dismiss',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    developer.log(
      '👆 NotificationService: Notification tapped - opening app',
      name: 'Notification',
    );

    // Simply dismiss the notification snackbar/dialog
    // The app is already open since this is called from foreground notifications
    // No additional navigation is needed
  }

  /// Show a custom dialog for important notifications
  static void showNotificationDialog(RemoteMessage message) {
    if (_navigatorKey?.currentContext == null) {
      developer.log(
        '❌ NotificationService: No context available for dialog',
        name: 'Notification',
      );
      return;
    }

    final context = _navigatorKey!.currentContext!;
    final notification = message.notification;

    if (notification == null) {
      developer.log(
        '⚠️ NotificationService: No notification data in message',
        name: 'Notification',
      );
      return;
    }

    developer.log(
      '📱 NotificationService: Showing notification dialog',
      name: 'Notification',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: notification.title != null
              ? Text(notification.title!)
              : const Text('Notification'),
          content: notification.body != null
              ? Text(notification.body!)
              : const Text('You have a new notification'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Dismiss'),
            ),
            if (message.data.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleNotificationTap(message);
                },
                child: const Text('View'),
              ),
          ],
        );
      },
    );
  }

  /// Check if the app should show in-app notifications
  static bool shouldShowInAppNotification(RemoteMessage message) {
    // You can add logic here to determine when to show in-app notifications
    // For example, don't show if user is in a chat screen and the message is a chat message

    if (_navigatorKey?.currentContext == null) {
      return false;
    }

    // Check if the message has high priority
    final String? priority = message.data['priority'];
    if (priority == 'high') {
      return true;
    }

    // Check if it's a system notification
    final String? type = message.data['type'];
    if (type == 'system' || type == 'announcement') {
      return true;
    }

    // Default: show in-app notification for all foreground messages
    return true;
  }
}
