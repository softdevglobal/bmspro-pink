import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../screens/appointment_requests_page.dart';
import '../screens/owner_bookings_page.dart';
import 'app_initializer.dart';

/// Top-level function to handle background messages
/// Must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Background FCM message received!');
  print('📩 Message ID: ${message.messageId}');
  print('📩 Notification Title: ${message.notification?.title}');
  print('📩 Notification Body: ${message.notification?.body}');
  print('📩 Data: ${message.data}');
  
  // IMPORTANT: For messages WITH notification payload, FCM automatically shows them
  // when the app is in background/terminated. No action needed.
  
  // For data-only messages, we need to show a local notification
  if (message.notification == null && message.data.isNotEmpty) {
    await _showBackgroundNotification(message);
  }
}

/// Show a local notification for background data messages
/// This is only called for data-only messages (no notification payload)
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Initialize the plugin for background use
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  
  // Create the notification channel for Android (required for Android 8.0+)
  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'appointments',
      'Booking Notifications',
      description: 'Notifications for booking appointments and updates',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'appointments',
    'Booking Notifications',
    channelDescription: 'Notifications for booking appointments and updates',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    playSound: true,
    enableVibration: true,
  );
  
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  
  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );
  
  final title = message.data['title'] ?? 'New Notification';
  final body = message.data['message'] ?? message.data['body'] ?? '';
  
  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    notificationDetails,
    payload: message.data['bookingId'] ?? '',
  );
  
  print('📩 Background local notification shown: $title');
}

/// Notification service for handling FCM and on-screen notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _adminNotificationSubscription;
  StreamSubscription<QuerySnapshot>? _branchAdminNotificationSubscription;
  BuildContext? _context;
  final Set<String> _shownNotificationIds = {};
  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      print('NotificationService already initialized');
      return;
    }
    
    try {
      // Initialize local notifications first
      await _initializeLocalNotifications();
      
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ User granted provisional notification permission');
      } else {
        print('❌ User declined or has not accepted notification permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      print('📱 FCM Token: $_fcmToken');

      // Save token to user document
      await _saveFcmToken(_fcmToken);

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken(newToken);
        print('📱 FCM Token refreshed: $newToken');
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📩 Received foreground message: ${message.messageId}');
        print('📩 Title: ${message.notification?.title}');
        print('📩 Body: ${message.notification?.body}');
        print('📩 Data: ${message.data}');
        _handleForegroundMessage(message);
      });

      // Handle background messages (when app is opened from notification while in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📩 Notification opened app from background: ${message.messageId}');
        _handleNotificationTap(message);
      });

      // Note: Background message handler is registered in main.dart
      // FirebaseMessaging.onBackgroundMessage must be called before runApp()
      
      // Subscribe to topics for broader notification targeting
      await _subscribeToTopics();
      
      _isInitialized = true;
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }
  
  /// Initialize flutter_local_notifications
  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    
    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'appointments',
        'Booking Notifications',
        description: 'Notifications for booking appointments and updates',
        importance: Importance.high,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
    
    print('✅ Local notifications initialized');
  }
  
  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    print('📩 Local notification tapped: ${response.payload}');
    // Navigate based on payload
    if (_context != null && _context!.mounted && response.payload != null) {
      final bookingId = response.payload;
      if (bookingId != null && bookingId.isNotEmpty) {
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => const AppointmentRequestsPage(),
          ),
        );
      }
    }
  }
  
  /// Subscribe to FCM topics
  Future<void> _subscribeToTopics() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Subscribe to user-specific topic
      await _messaging.subscribeToTopic('user_${user.uid}');
      print('📢 Subscribed to topic: user_${user.uid}');
    } catch (e) {
      print('⚠️ Error subscribing to topics: $e');
    }
  }

  /// Save FCM token to user document (and salon_staff if exists)
  Future<void> _saveFcmToken(String? token) async {
    if (token == null) return;
    
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Save to users collection
      await _db.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
      print('✅ FCM token saved to users collection');
    } catch (e) {
      print('⚠️ Error saving FCM token to users collection: $e');
      // Try to create the document if it doesn't exist
      try {
        await _db.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
        }, SetOptions(merge: true));
        print('✅ FCM token saved to users collection (merged)');
      } catch (e2) {
        print('❌ Error saving FCM token (merge attempt): $e2');
      }
    }
    
    // Also try to save to salon_staff collection (for branch admins and staff)
    try {
      final staffDoc = await _db.collection('salon_staff').doc(user.uid).get();
      if (staffDoc.exists) {
        await _db.collection('salon_staff').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token also saved to salon_staff collection');
      }
    } catch (e) {
      // It's okay if this fails - user might not be in salon_staff collection
      print('⚠️ Could not save FCM token to salon_staff (user may not be staff): $e');
    }
  }

  /// Set context for showing on-screen notifications
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Listen to Firestore notifications and show on-screen notifications
  /// Only shows NEW notifications that arrive while app is running, not old unread ones
  void listenToNotifications() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cancel existing subscriptions
    _notificationSubscription?.cancel();
    _adminNotificationSubscription?.cancel();
    _branchAdminNotificationSubscription?.cancel();
    _shownNotificationIds.clear();
    
    // Track if this is the first snapshot (initial load) - we skip showing those notifications
    bool isInitialLoad = true;
    
    // Query for staff notifications - only listen for NEW ones (created after we started listening)
    // Note: Removed orderBy to avoid needing composite indexes - we only care about new docs
    _notificationSubscription = _db
        .collection('notifications')
        .where('staffUid', isEqualTo: user.uid)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      // Skip the initial snapshot - only process changes that happen AFTER we start listening
      if (isInitialLoad) {
        isInitialLoad = false;
        // Don't show any notifications from the initial load
        return;
      }
      
      // Only process NEW notifications (documents that were added after we started listening)
      for (final change in snapshot.docChanges) {
        // Only show if it's a new document (added), not modified or existing
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          
          // Skip if data is null
          if (data == null) continue;
          
          // Skip if we've already shown this notification
          if (_shownNotificationIds.contains(doc.id)) continue;
          
          final type = data['type']?.toString() ?? '';
          
          // Show all notification types to staff
          // Only skip if already read
          if (data['read'] == true) continue;
          
          _shownNotificationIds.add(doc.id);
          _showOnScreenNotification(
            title: data['title']?.toString() ?? 'New Notification',
            message: data['message']?.toString() ?? '',
            notificationId: doc.id,
            notificationData: data,
          );
          
          // Also show a local notification for better visibility
          _showLocalNotification(
            id: doc.id.hashCode,
            title: data['title']?.toString() ?? 'New Notification',
            body: data['message']?.toString() ?? '',
            payload: doc.id,
          );
        }
      }
    }, onError: (e) {
      print('❌ Error listening to staff notifications: $e');
    });
    
    // Query for admin notifications (ownerUid) - only listen for NEW ones
    // This includes notifications where owner is directly the recipient (staff created bookings, etc.)
    // Note: Removed orderBy to avoid needing composite indexes
    bool isInitialAdminLoad = true;
    _adminNotificationSubscription = _db
        .collection('notifications')
        .where('ownerUid', isEqualTo: user.uid)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      // Skip the initial snapshot
      if (isInitialAdminLoad) {
        isInitialAdminLoad = false;
        return;
      }
      
      // Only process NEW notifications
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          
          // Skip if data is null
          if (data == null) continue;
          
          // Skip if we've already shown this notification
          if (_shownNotificationIds.contains(doc.id)) continue;
          
          final type = data['type']?.toString() ?? '';
          final staffUid = data['staffUid']?.toString();
          final targetAdminUid = data['targetAdminUid']?.toString();
          final targetOwnerUid = data['targetOwnerUid']?.toString();
          
          // Show notification if:
          // 1. It's explicitly targeted to the owner (targetOwnerUid matches)
          // 2. It's a staff_booking_created or booking_engine_new_booking notification
          // 3. It's a booking_needs_assignment notification (unassigned bookings)
          bool shouldShow = false;
          
          if (targetOwnerUid == user.uid) {
            shouldShow = true;
          } else if (type == 'staff_booking_created' || 
                     type == 'booking_engine_new_booking' ||
                     type == 'booking_needs_assignment') {
            shouldShow = true;
          } else if ((staffUid == null || staffUid != user.uid) && 
              (targetAdminUid == null || targetAdminUid == user.uid)) {
            // General admin notification
            shouldShow = true;
          }
          
          if (shouldShow) {
            // Only show if unread
            if (data['read'] == true) continue;
            
            _shownNotificationIds.add(doc.id);
            _showOnScreenNotification(
              title: data['title']?.toString() ?? 'New Notification',
              message: data['message']?.toString() ?? '',
              notificationId: doc.id,
              notificationData: data,
            );
            
            // Also show a local notification for better visibility
            _showLocalNotification(
              id: doc.id.hashCode,
              title: data['title']?.toString() ?? 'New Notification',
              body: data['message']?.toString() ?? '',
              payload: doc.id,
            );
          }
        }
      }
    }, onError: (e) {
      print('❌ Error listening to admin notifications: $e');
    });
    
    // Query for branch admin notifications (branchAdminUid or targetAdminUid)
    // Note: Removed orderBy to avoid needing composite indexes
    bool isInitialBranchAdminLoad = true;
    _branchAdminNotificationSubscription = _db
        .collection('notifications')
        .where('branchAdminUid', isEqualTo: user.uid)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      // Skip the initial snapshot
      if (isInitialBranchAdminLoad) {
        isInitialBranchAdminLoad = false;
        return;
      }
      
      // Only process NEW notifications
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          
          // Skip if data is null
          if (data == null) continue;
          
          // Skip if we've already shown this notification
          if (_shownNotificationIds.contains(doc.id)) continue;
          
          // Only show if unread
          if (data['read'] == true) continue;
          
          _shownNotificationIds.add(doc.id);
          _showOnScreenNotification(
            title: data['title']?.toString() ?? 'New Booking',
            message: data['message']?.toString() ?? '',
            notificationId: doc.id,
            notificationData: data,
          );
          
          // Also show a local notification for better visibility
          _showLocalNotification(
            id: doc.id.hashCode,
            title: data['title']?.toString() ?? 'New Booking',
            body: data['message']?.toString() ?? '',
            payload: doc.id,
          );
        }
      }
    }, onError: (e) {
      print('❌ Error listening to branch admin notifications: $e');
    });
    
    // Also listen for targetAdminUid notifications (for reassignments, etc.)
    // Note: Removed orderBy to avoid needing composite indexes
    bool isInitialTargetAdminLoad = true;
    _db
        .collection('notifications')
        .where('targetAdminUid', isEqualTo: user.uid)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      // Skip the initial snapshot
      if (isInitialTargetAdminLoad) {
        isInitialTargetAdminLoad = false;
        return;
      }
      
      // Only process NEW notifications
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          
          // Skip if data is null
          if (data == null) continue;
          
          // Skip if we've already shown this notification
          if (_shownNotificationIds.contains(doc.id)) continue;
          
          // Skip if it was already shown via branchAdminUid query
          final branchAdminUid = data['branchAdminUid']?.toString();
          if (branchAdminUid == user.uid) continue;
          
          // Only show if unread
          if (data['read'] == true) continue;
          
          _shownNotificationIds.add(doc.id);
          _showOnScreenNotification(
            title: data['title']?.toString() ?? 'New Notification',
            message: data['message']?.toString() ?? '',
            notificationId: doc.id,
            notificationData: data,
          );
          
          // Also show a local notification for better visibility
          _showLocalNotification(
            id: doc.id.hashCode,
            title: data['title']?.toString() ?? 'New Notification',
            body: data['message']?.toString() ?? '',
            payload: doc.id,
          );
        }
      }
    }, onError: (e) {
      print('❌ Error listening to target admin notifications: $e');
    });
  }
  
  /// Show a local notification using flutter_local_notifications
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'appointments',
      'Booking Notifications',
      channelDescription: 'Notifications for booking appointments and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Show on-screen notification overlay
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
    // Show local notification for foreground messages
    final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
    final body = message.notification?.body ?? message.data['message'] ?? '';
    
    _showLocalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: message.data['bookingId'] ?? message.data['notificationId'] ?? '',
    );
    
    // Also show on-screen notification overlay
    _showOnScreenNotification(
      title: title,
      message: body,
      notificationId: message.messageId ?? '',
      notificationData: message.data,
    );
  }

  /// Handle notification tap (when app is opened from background)
  void _handleNotificationTap(RemoteMessage message) {
    // Mark notification as read
    _handleNotificationTapFromData(message.data);
    
    // Use AppInitializer for consistent navigation handling
    if (_context != null && _context!.mounted) {
      AppInitializer.handleNotificationTap(message, _context);
    } else {
      // If context is not available, try to get it from navigator key
      final navigator = AppInitializer().navigatorKey.currentState;
      if (navigator != null) {
        AppInitializer.handleNotificationTap(message, navigator.context);
      }
    }
  }

  /// Handle notification tap from data (marks notification as read and navigates)
  void _handleNotificationTapFromData(Map<String, dynamic>? data) {
    if (data == null) return;

    final notificationId = data['notificationId']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    
    // Mark notification as read in Firestore
    if (notificationId.isNotEmpty) {
      _db.collection('notifications').doc(notificationId).update({'read': true}).catchError((e) {
        debugPrint('Error marking notification as read: $e');
      });
    }
    
    // Navigate based on notification type
    if (_context != null && _context!.mounted) {
      if (type == 'booking_approval_request') {
        // Only booking approval requests go to AppointmentRequestsPage (for staff)
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => const AppointmentRequestsPage(),
          ),
        );
      } else if (type == 'staff_assignment' || 
                 type == 'staff_reassignment' ||
                 type == 'branch_booking_created' || 
                 type == 'booking_needs_assignment' ||
                 type == 'booking_confirmed' ||
                 type == 'booking_status_changed' ||
                 type == 'staff_booking_created' ||
                 type == 'booking_engine_new_booking' ||
                 type == 'booking_assigned' ||
                 type == 'booking_completed' ||
                 type == 'booking_canceled') {
        // All booking-related notifications go to OwnerBookingsPage
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => const OwnerBookingsPage(),
          ),
        );
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationSubscription?.cancel();
    _adminNotificationSubscription?.cancel();
    _branchAdminNotificationSubscription?.cancel();
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
