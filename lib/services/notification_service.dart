import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../screens/appointment_requests_page.dart';
import '../screens/owner_bookings_page.dart';
import 'app_initializer.dart';

/// Top-level function to handle background messages
/// Must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
  
  // Note: When the app is in the background or terminated,
  // FCM automatically displays the notification on Android and iOS.
  // This handler is for any additional processing you might need.
  
  // You can perform background tasks here, such as:
  // - Updating local database
  // - Scheduling local notifications
  // - Processing notification data
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
  StreamSubscription<QuerySnapshot>? _branchAdminNotificationSubscription;
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

      // Handle background messages (when app is opened from notification while in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification opened app from background: ${message.messageId}');
        _handleNotificationTap(message);
      });

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      print('Error initializing notification service: $e');
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
      });
      print('FCM token saved to users collection');
    } catch (e) {
      print('Error saving FCM token to users collection: $e');
      // Try to create the document if it doesn't exist
      try {
        await _db.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('FCM token saved to users collection (merged)');
      } catch (e2) {
        print('Error saving FCM token (merge attempt): $e2');
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
        print('FCM token also saved to salon_staff collection');
      }
    } catch (e) {
      // It's okay if this fails - user might not be in salon_staff collection
      print('Could not save FCM token to salon_staff (user may not be staff): $e');
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
    _notificationSubscription = _db
        .collection('notifications')
        .where('staffUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
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
          if (data == null) {
            continue;
          }
          
          // Skip if we've already shown this notification
          if (_shownNotificationIds.contains(doc.id)) {
            continue;
          }
          
          final type = data['type']?.toString() ?? '';
          
          // Skip booking_approval_request notifications (they're handled via pending requests alert)
          if (type == 'booking_approval_request') {
            continue;
          }
          
          // Only show if unread
          if (data['read'] == true) {
            continue;
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
    
    // Query for admin notifications (ownerUid) - only listen for NEW ones
    // This includes notifications where owner is directly the recipient (staff created bookings, etc.)
    bool isInitialAdminLoad = true;
    _adminNotificationSubscription = _db
        .collection('notifications')
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
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
          if (data == null) {
            continue;
          }
          
          // Skip if we've already shown this notification
          if (_shownNotificationIds.contains(doc.id)) {
            continue;
          }
          
          final type = data['type']?.toString() ?? '';
          final staffUid = data['staffUid']?.toString();
          final targetAdminUid = data['targetAdminUid']?.toString();
          final targetOwnerUid = data['targetOwnerUid']?.toString();
          
          // Show notification if:
          // 1. It's a staff_booking_created or booking_engine_new_booking notification and user is the owner, OR
          // 2. It's a general admin notification (no staffUid or targetAdminUid matches)
          bool shouldShow = false;
          
          if ((type == 'staff_booking_created' || type == 'booking_engine_new_booking') && 
              (targetOwnerUid == user.uid || data['ownerUid'] == user.uid)) {
            // Booking created notification - always show to owner
            shouldShow = true;
          } else if ((staffUid == null || staffUid != user.uid) && 
              (targetAdminUid == null || targetAdminUid == user.uid)) {
            // General admin notification
            shouldShow = true;
          }
          
          if (shouldShow) {
            // Only show if unread
            if (data['read'] == true) {
              continue;
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
      }
    }, onError: (e) {
      print('Error listening to admin notifications: $e');
    });
    
    // Query for branch admin notifications (branchAdminUid or targetAdminUid)
    bool isInitialBranchAdminLoad = true;
    _branchAdminNotificationSubscription = _db
        .collection('notifications')
        .where('branchAdminUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
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
          if (data == null) {
            continue;
          }
          
          // Skip if we've already shown this notification
          if (_shownNotificationIds.contains(doc.id)) {
            continue;
          }
          
          // Only show if unread
          if (data['read'] == true) {
            continue;
          }
          
          _shownNotificationIds.add(doc.id);
          _showOnScreenNotification(
            title: data['title']?.toString() ?? 'New Booking',
            message: data['message']?.toString() ?? '',
            notificationId: doc.id,
            notificationData: data,
          );
        }
      }
    }, onError: (e) {
      print('Error listening to branch admin notifications: $e');
    });
    
    // Also listen for targetAdminUid notifications (for reassignments, etc.)
    bool isInitialTargetAdminLoad = true;
    _db
        .collection('notifications')
        .where('targetAdminUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
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
          if (data == null) {
            continue;
          }
          
          // Skip if we've already shown this notification
          if (_shownNotificationIds.contains(doc.id)) {
            continue;
          }
          
          // Skip if it was already shown via branchAdminUid query
          final branchAdminUid = data['branchAdminUid']?.toString();
          if (branchAdminUid == user.uid) {
            continue; // Already handled by branchAdminUid subscription
          }
          
          // Only show if unread
          if (data['read'] == true) {
            continue;
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
      print('Error listening to target admin notifications: $e');
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
      if (type == 'booking_approval_request' || 
          type == 'staff_assignment' || 
          type == 'staff_reassignment') {
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => const AppointmentRequestsPage(),
          ),
        );
      } else if (type == 'branch_booking_created' || 
                 type == 'booking_needs_assignment' ||
                 type == 'booking_confirmed' ||
                 type == 'booking_status_changed' ||
                 type == 'staff_booking_created' ||
                 type == 'booking_engine_new_booking') {
        // Navigate to bookings page for owner/branch admin notifications
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

