import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Top-level function to handle background messages
/// Must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  // You can perform background tasks here
}

/// Notification service for handling FCM and on-screen notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _fcmToken;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _adminNotificationSubscription;
  Function(RemoteMessage)? _onMessageHandler;
  BuildContext? _context;
  final Set<String> _shownNotificationIds = {};

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional notification permission');
      } else {
        print('User declined or has not accepted notification permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      print('FCM Token: $_fcmToken');

      // Save token to user document
      await _saveFcmToken(_fcmToken);

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken(newToken);
        print('FCM Token refreshed: $newToken');
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received foreground message: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification opened app: ${message.messageId}');
        _handleNotificationTap(message);
      });

      // Check if app was opened from a notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  /// Save FCM token to user document
  Future<void> _saveFcmToken(String? token) async {
    if (token == null) return;
    
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Set context for showing on-screen notifications
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Listen to Firestore notifications and show on-screen notifications
  void listenToNotifications() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cancel existing subscription
    _notificationSubscription?.cancel();

    // Cancel existing subscriptions
    _notificationSubscription?.cancel();
    _adminNotificationSubscription?.cancel();
    _shownNotificationIds.clear();
    
    // Query for staff notifications
    _notificationSubscription = _db
        .collection('notifications')
        .where('staffUid', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        if (!_shownNotificationIds.contains(doc.id)) {
          final data = doc.data();
          final type = data['type']?.toString() ?? '';
          
          // Skip booking_approval_request notifications (they're handled via pending requests alert)
          if (type == 'booking_approval_request') {
            return;
          }
          
          _shownNotificationIds.add(doc.id);
          _showOnScreenNotification(
            title: data['title']?.toString() ?? 'New Notification',
            message: data['message']?.toString() ?? '',
            notificationId: doc.id,
            notificationData: data,
          );
        }
      }
    }, onError: (e) {
      print('Error listening to staff notifications: $e');
    });
    
    // Query for admin notifications (ownerUid) - for branch admins
    _adminNotificationSubscription = _db
        .collection('notifications')
        .where('ownerUid', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        // Only show if it's an admin notification (no staffUid or targetAdminUid matches user)
        final staffUid = data['staffUid']?.toString();
        final targetAdminUid = data['targetAdminUid']?.toString();
        
        // Show if: no staffUid assigned, or targetAdminUid matches, or it's a general admin notification
        if ((staffUid == null || staffUid != user.uid) && 
            (targetAdminUid == null || targetAdminUid == user.uid)) {
          if (!_shownNotificationIds.contains(doc.id)) {
            _shownNotificationIds.add(doc.id);
            _showOnScreenNotification(
              title: data['title']?.toString() ?? 'New Notification',
              message: data['message']?.toString() ?? '',
              notificationId: doc.id,
              notificationData: data,
            );
          }
        }
      }
    }, onError: (e) {
      print('Error listening to admin notifications: $e');
    });
  }

  /// Show on-screen notification
  void _showOnScreenNotification({
    required String title,
    required String message,
    required String notificationId,
    Map<String, dynamic>? notificationData,
  }) {
    if (_context == null || !_context!.mounted) return;

    // Show a snackbar or overlay notification
    final overlay = Overlay.of(_context!);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _NotificationOverlay(
        title: title,
        message: message,
        onTap: () {
          _handleNotificationTapFromData(notificationData);
          overlayEntry.remove();
        },
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    // Show on-screen notification for foreground messages
    _showOnScreenNotification(
      title: message.notification?.title ?? 'New Notification',
      message: message.notification?.body ?? '',
      notificationId: message.messageId ?? '',
      notificationData: message.data,
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    // Navigate to appropriate screen based on notification data
    final data = message.data;
    _handleNotificationTapFromData(data);
  }

  /// Handle notification tap from data
  void _handleNotificationTapFromData(Map<String, dynamic>? data) {
    if (_context == null || !_context!.mounted || data == null) return;

    final type = data['type']?.toString() ?? '';
    final notificationId = data['notificationId']?.toString() ?? '';
    
    // Mark notification as read
    if (notificationId.isNotEmpty) {
      _db.collection('notifications').doc(notificationId).update({'read': true});
    }
    
    // Navigate based on notification type
    // Note: Navigation will be handled by the screens that use this service
    // The screens can listen to notification taps and navigate accordingly
  }

  /// Dispose resources
  void dispose() {
    _notificationSubscription?.cancel();
    _adminNotificationSubscription?.cancel();
    _shownNotificationIds.clear();
    _context = null;
  }
}

/// Overlay widget for on-screen notifications
class _NotificationOverlay extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationOverlay({
    required this.title,
    required this.message,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFF2D8F).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2D8F).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Color(0xFFFF2D8F),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.message,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9E9E9E),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.onDismiss,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

