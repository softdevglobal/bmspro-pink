import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuditActionType {
  create,
  update,
  delete,
  statusChange,
  login,
  logout,
  other,
}

enum AuditEntityType {
  booking,
  service,
  staff,
  branch,
  customer,
  settings,
  auth,
  userProfile,
}

class AuditLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current user's info for audit logging
  static Future<Map<String, String>?> _getCurrentUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      return {
        'uid': user.uid,
        'name': data?['name'] ?? data?['displayName'] ?? user.displayName ?? 'User',
        'role': data?['role'] ?? 'unknown',
        'ownerUid': data?['ownerUid'] ?? user.uid,
      };
    } catch (e) {
      return {
        'uid': user.uid,
        'name': user.displayName ?? 'User',
        'role': 'unknown',
        'ownerUid': user.uid,
      };
    }
  }

  /// Create an audit log entry
  static Future<void> createAuditLog({
    required String action,
    required AuditActionType actionType,
    required AuditEntityType entityType,
    String? entityId,
    String? entityName,
    String? details,
    String? previousValue,
    String? newValue,
    String? branchId,
    String? branchName,
  }) async {
    try {
      final userInfo = await _getCurrentUserInfo();
      if (userInfo == null) return;

      final logData = {
        'ownerUid': userInfo['ownerUid'],
        'action': action,
        'actionType': actionType.name,
        'entityType': entityType.name,
        'entityId': entityId,
        'entityName': entityName,
        'performedBy': userInfo['uid'],
        'performedByName': userInfo['name'],
        'performedByRole': userInfo['role'],
        'details': details,
        'previousValue': previousValue,
        'newValue': newValue,
        'branchId': branchId,
        'branchName': branchName,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Remove null values
      logData.removeWhere((key, value) => value == null);

      await _firestore.collection('auditLogs').add(logData);
    } catch (e) {
      // Don't throw - audit logging should not break the main flow
      print('Failed to create audit log: $e');
    }
  }

  // ==================== BOOKING AUDIT HELPERS ====================

  static Future<void> logBookingCreated({
    required String bookingId,
    String? bookingCode,
    required String clientName,
    required String serviceName,
    String? branchName,
    String? staffName,
  }) async {
    await createAuditLog(
      action: 'Booking created for $clientName',
      actionType: AuditActionType.create,
      entityType: AuditEntityType.booking,
      entityId: bookingId,
      entityName: bookingCode ?? bookingId,
      details: 'Service: $serviceName${staffName != null ? ', Staff: $staffName' : ''}',
      branchName: branchName,
    );
  }

  static Future<void> logBookingStatusChanged({
    required String bookingId,
    String? bookingCode,
    required String clientName,
    required String previousStatus,
    required String newStatus,
    String? details,
    String? branchName,
  }) async {
    await createAuditLog(
      action: 'Booking status changed: $previousStatus → $newStatus',
      actionType: AuditActionType.statusChange,
      entityType: AuditEntityType.booking,
      entityId: bookingId,
      entityName: bookingCode ?? 'Booking for $clientName',
      previousValue: previousStatus,
      newValue: newStatus,
      details: details,
      branchName: branchName,
    );
  }

  static Future<void> logBookingStaffResponse({
    required String bookingId,
    String? bookingCode,
    required String clientName,
    required bool accepted,
    String? serviceName,
    String? rejectionReason,
    String? branchName,
  }) async {
    final actionText = accepted ? 'accepted' : 'rejected';
    await createAuditLog(
      action: 'Staff $actionText booking${serviceName != null ? ' for service: $serviceName' : ''}',
      actionType: AuditActionType.statusChange,
      entityType: AuditEntityType.booking,
      entityId: bookingId,
      entityName: bookingCode ?? 'Booking for $clientName',
      details: !accepted && rejectionReason != null ? 'Reason: $rejectionReason' : null,
      branchName: branchName,
    );
  }

  // ==================== SERVICE AUDIT HELPERS ====================

  static Future<void> logServiceCreated({
    required String serviceId,
    required String serviceName,
    required double price,
  }) async {
    await createAuditLog(
      action: 'Service created: $serviceName',
      actionType: AuditActionType.create,
      entityType: AuditEntityType.service,
      entityId: serviceId,
      entityName: serviceName,
      details: 'Price: \$${price.toStringAsFixed(2)}',
    );
  }

  static Future<void> logServiceUpdated({
    required String serviceId,
    required String serviceName,
    String? changes,
  }) async {
    await createAuditLog(
      action: 'Service updated: $serviceName',
      actionType: AuditActionType.update,
      entityType: AuditEntityType.service,
      entityId: serviceId,
      entityName: serviceName,
      details: changes,
    );
  }

  static Future<void> logServiceDeleted({
    required String serviceId,
    required String serviceName,
  }) async {
    await createAuditLog(
      action: 'Service deleted: $serviceName',
      actionType: AuditActionType.delete,
      entityType: AuditEntityType.service,
      entityId: serviceId,
      entityName: serviceName,
    );
  }

  // ==================== BRANCH AUDIT HELPERS ====================

  static Future<void> logBranchCreated({
    required String branchId,
    required String branchName,
    String? address,
  }) async {
    await createAuditLog(
      action: 'Branch created: $branchName',
      actionType: AuditActionType.create,
      entityType: AuditEntityType.branch,
      entityId: branchId,
      entityName: branchName,
      details: address != null ? 'Address: $address' : null,
      branchId: branchId,
      branchName: branchName,
    );
  }

  static Future<void> logBranchUpdated({
    required String branchId,
    required String branchName,
    String? changes,
  }) async {
    await createAuditLog(
      action: 'Branch updated: $branchName',
      actionType: AuditActionType.update,
      entityType: AuditEntityType.branch,
      entityId: branchId,
      entityName: branchName,
      details: changes,
      branchId: branchId,
      branchName: branchName,
    );
  }

  // ==================== STAFF AUDIT HELPERS ====================

  static Future<void> logStaffCreated({
    required String staffId,
    required String staffName,
    required String staffRole,
    String? branchName,
  }) async {
    await createAuditLog(
      action: 'Staff member created: $staffName',
      actionType: AuditActionType.create,
      entityType: AuditEntityType.staff,
      entityId: staffId,
      entityName: staffName,
      details: 'Role: $staffRole${branchName != null ? ', Branch: $branchName' : ''}',
      branchName: branchName,
    );
  }

  static Future<void> logStaffUpdated({
    required String staffId,
    required String staffName,
    String? changes,
  }) async {
    await createAuditLog(
      action: 'Staff member updated: $staffName',
      actionType: AuditActionType.update,
      entityType: AuditEntityType.staff,
      entityId: staffId,
      entityName: staffName,
      details: changes,
    );
  }

  static Future<void> logStaffStatusChanged({
    required String staffId,
    required String staffName,
    required String previousStatus,
    required String newStatus,
  }) async {
    await createAuditLog(
      action: 'Staff status changed: $staffName ($previousStatus → $newStatus)',
      actionType: AuditActionType.statusChange,
      entityType: AuditEntityType.staff,
      entityId: staffId,
      entityName: staffName,
      previousValue: previousStatus,
      newValue: newStatus,
    );
  }

  // ==================== AUTH AUDIT HELPERS ====================

  static Future<void> logUserLogin() async {
    final userInfo = await _getCurrentUserInfo();
    if (userInfo == null) return;

    await createAuditLog(
      action: 'User logged in: ${userInfo['name']}',
      actionType: AuditActionType.login,
      entityType: AuditEntityType.auth,
      entityId: userInfo['uid'],
      entityName: userInfo['name']!,
    );
  }

  static Future<void> logUserLogout() async {
    final userInfo = await _getCurrentUserInfo();
    if (userInfo == null) return;

    await createAuditLog(
      action: 'User logged out: ${userInfo['name']}',
      actionType: AuditActionType.logout,
      entityType: AuditEntityType.auth,
      entityId: userInfo['uid'],
      entityName: userInfo['name']!,
    );
  }

  // ==================== SETTINGS AUDIT HELPERS ====================

  static Future<void> logSettingsUpdated({
    required String settingName,
    String? previousValue,
    String? newValue,
  }) async {
    await createAuditLog(
      action: 'Settings updated: $settingName',
      actionType: AuditActionType.update,
      entityType: AuditEntityType.settings,
      entityName: settingName,
      previousValue: previousValue,
      newValue: newValue,
    );
  }
}

