import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Service for sending FCM push notifications via the admin panel API
class FcmPushService {
  static final FcmPushService _instance = FcmPushService._internal();
  factory FcmPushService() => _instance;
  FcmPushService._internal();

  // Admin panel API base URL
  static const String _apiBaseUrl = 'https://bmspro-pink-adminpanel.vercel.app';

  /// Send FCM push notification to a specific user (staff, owner, etc.)
  /// 
  /// [targetUid] - The UID of the user to send the notification to
  /// [title] - Notification title
  /// [message] - Notification body message
  /// [data] - Additional data payload (optional)
  Future<bool> sendPushNotification({
    required String targetUid,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ FcmPushService: No authenticated user, cannot send push notification');
        return false;
      }

      final token = await user.getIdToken();
      if (token == null) {
        debugPrint('⚠️ FcmPushService: Could not get auth token');
        return false;
      }

      debugPrint('📤 FcmPushService: Sending push notification to $targetUid');
      debugPrint('📤 Title: $title');
      
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/notifications/send-push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'staffUid': targetUid, // API expects staffUid but works for any user
          'title': title,
          'message': message,
          'data': data ?? {},
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('❌ FcmPushService: Request timed out');
          return http.Response('{"error": "Request timeout"}', 408);
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FcmPushService: Push notification sent successfully to $targetUid');
        return true;
      } else {
        debugPrint('❌ FcmPushService: Failed to send push notification: ${response.statusCode}');
        debugPrint('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ FcmPushService: Error sending push notification: $e');
      return false;
    }
  }

  /// Send booking notification to salon owner when staff creates a booking
  Future<bool> sendOwnerBookingNotification({
    required String ownerUid,
    required String bookingId,
    required String bookingCode,
    required String clientName,
    required String serviceNames,
    required String dateStr,
    required String timeStr,
    required String branchName,
    required String creatorName,
    required String creatorRole,
  }) async {
    final roleLabel = creatorRole == 'salon_branch_admin' ? 'Branch Admin' : 'Staff';
    final title = 'New Booking Created by $roleLabel';
    final message = '$creatorName created a booking for $clientName - $serviceNames at $branchName on $dateStr at $timeStr';

    return sendPushNotification(
      targetUid: ownerUid,
      title: title,
      message: message,
      data: {
        'type': 'staff_booking_created',
        'bookingId': bookingId,
        'bookingCode': bookingCode,
      },
    );
  }

  /// Send booking notification to assigned staff member
  Future<bool> sendStaffAssignmentNotification({
    required String staffUid,
    required String bookingId,
    required String bookingCode,
    required String clientName,
    required String serviceNames,
    required String dateStr,
    required String timeStr,
    required String branchName,
  }) async {
    final title = 'New Appointment Request';
    final message = 'You have a new appointment request from $clientName for $serviceNames on $dateStr at $timeStr at $branchName. Please accept or reject this booking.';

    return sendPushNotification(
      targetUid: staffUid,
      title: title,
      message: message,
      data: {
        'type': 'staff_assignment',
        'bookingId': bookingId,
        'bookingCode': bookingCode,
      },
    );
  }

  /// Send booking confirmation notification to staff
  Future<bool> sendStaffBookingConfirmedNotification({
    required String staffUid,
    required String bookingId,
    required String bookingCode,
    required String clientName,
    required String serviceNames,
    required String dateStr,
    required String timeStr,
  }) async {
    final title = 'Booking Confirmed';
    final message = 'Your booking with $clientName for $serviceNames on $dateStr at $timeStr has been confirmed.';

    return sendPushNotification(
      targetUid: staffUid,
      title: title,
      message: message,
      data: {
        'type': 'booking_confirmed',
        'bookingId': bookingId,
        'bookingCode': bookingCode,
      },
    );
  }

  /// Send notification to owner about unassigned booking
  Future<bool> sendUnassignedBookingNotification({
    required String ownerUid,
    required String bookingId,
    required String bookingCode,
    required String clientName,
    required String serviceNames,
    required String dateStr,
    required String timeStr,
    required String branchName,
    required String source, // 'booking_engine' or 'admin_panel'
  }) async {
    final sourceLabel = source == 'booking_engine' ? 'Booking Engine' : 'Admin Panel';
    final title = 'New Unassigned Booking';
    final message = 'New booking from $clientName for $serviceNames on $dateStr at $timeStr at $branchName needs staff assignment. Source: $sourceLabel';

    return sendPushNotification(
      targetUid: ownerUid,
      title: title,
      message: message,
      data: {
        'type': 'booking_needs_assignment',
        'bookingId': bookingId,
        'bookingCode': bookingCode,
        'source': source,
      },
    );
  }
}

