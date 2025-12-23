import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_service.dart';

/// Staff check-in record model
class StaffCheckInRecord {
  final String? id;
  final String staffId;
  final String staffName;
  final String? staffRole;
  final String branchId;
  final String branchName;
  final String ownerUid;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double staffLatitude;
  final double staffLongitude;
  final double branchLatitude;
  final double branchLongitude;
  final double distanceFromBranch;
  final bool isWithinRadius;
  final double allowedRadius;
  final String status;
  final String? note;

  StaffCheckInRecord({
    this.id,
    required this.staffId,
    required this.staffName,
    this.staffRole,
    required this.branchId,
    required this.branchName,
    required this.ownerUid,
    required this.checkInTime,
    this.checkOutTime,
    required this.staffLatitude,
    required this.staffLongitude,
    required this.branchLatitude,
    required this.branchLongitude,
    required this.distanceFromBranch,
    required this.isWithinRadius,
    required this.allowedRadius,
    required this.status,
    this.note,
  });

  factory StaffCheckInRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffCheckInRecord(
      id: doc.id,
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      staffRole: data['staffRole'],
      branchId: data['branchId'] ?? '',
      branchName: data['branchName'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      checkInTime: (data['checkInTime'] as Timestamp).toDate(),
      checkOutTime: data['checkOutTime'] != null
          ? (data['checkOutTime'] as Timestamp).toDate()
          : null,
      staffLatitude: (data['staffLatitude'] ?? 0).toDouble(),
      staffLongitude: (data['staffLongitude'] ?? 0).toDouble(),
      branchLatitude: (data['branchLatitude'] ?? 0).toDouble(),
      branchLongitude: (data['branchLongitude'] ?? 0).toDouble(),
      distanceFromBranch: (data['distanceFromBranch'] ?? 0).toDouble(),
      isWithinRadius: data['isWithinRadius'] ?? false,
      allowedRadius: (data['allowedRadius'] ?? 100).toDouble(),
      status: data['status'] ?? 'checked_in',
      note: data['note'],
    );
  }

  String get hoursWorked {
    if (checkOutTime == null) return 'In progress';
    final diff = checkOutTime!.difference(checkInTime);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

/// Branch model for check-in
class BranchForCheckIn {
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final double allowedRadius;
  final String ownerUid;

  BranchForCheckIn({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.allowedRadius,
    required this.ownerUid,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory BranchForCheckIn.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>?;
    return BranchForCheckIn(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: location?['latitude']?.toDouble(),
      longitude: location?['longitude']?.toDouble(),
      allowedRadius: (data['allowedCheckInRadius'] ?? 100).toDouble(),
      ownerUid: data['ownerUid'] ?? '',
    );
  }
}

/// Check-in result
class CheckInResult {
  final bool success;
  final String message;
  final String? checkInId;
  final double? distanceFromBranch;
  final bool? isWithinRadius;

  CheckInResult({
    required this.success,
    required this.message,
    this.checkInId,
    this.distanceFromBranch,
    this.isWithinRadius,
  });
}

/// Check-out result
class CheckOutResult {
  final bool success;
  final String message;
  final String? hoursWorked;

  CheckOutResult({
    required this.success,
    required this.message,
    this.hoursWorked,
  });
}

/// Staff check-in service
class StaffCheckInService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get available branches for check-in
  static Future<List<BranchForCheckIn>> getBranchesForCheckIn() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user's ownerUid
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final ownerUid = userData['ownerUid'] ?? user.uid;

      // Get branches for this owner
      final branchesQuery = await _db
          .collection('branches')
          .where('ownerUid', isEqualTo: ownerUid)
          .where('status', isEqualTo: 'Active')
          .get();

      return branchesQuery.docs
          .map((doc) => BranchForCheckIn.fromFirestore(doc))
          .where((b) => b.hasLocation)
          .toList();
    } catch (e) {
      print('Error getting branches: $e');
      return [];
    }
  }

  /// Perform staff check-in
  static Future<CheckInResult> checkIn({
    required String branchId,
    required double staffLatitude,
    required double staffLongitude,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return CheckInResult(success: false, message: 'Not authenticated');
      }

      // Get user data
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return CheckInResult(success: false, message: 'User data not found');
      }

      final userData = userDoc.data()!;
      final staffName = userData['displayName'] ?? userData['name'] ?? 'Unknown';
      final staffRole = userData['staffRole'] ?? userData['role'] ?? 'Staff';
      final ownerUid = userData['ownerUid'] ?? user.uid;

      // Get branch data
      final branchDoc = await _db.collection('branches').doc(branchId).get();
      if (!branchDoc.exists) {
        return CheckInResult(success: false, message: 'Branch not found');
      }

      final branchData = branchDoc.data()!;
      final branchName = branchData['name'] ?? 'Unknown Branch';
      final location = branchData['location'] as Map<String, dynamic>?;

      if (location == null ||
          location['latitude'] == null ||
          location['longitude'] == null) {
        return CheckInResult(
          success: false,
          message: 'Branch location not configured. Please contact your administrator.',
        );
      }

      final branchLat = location['latitude'].toDouble();
      final branchLon = location['longitude'].toDouble();
      final allowedRadius =
          (branchData['allowedCheckInRadius'] ?? 100).toDouble();

      // Calculate distance
      final distance = LocationService.calculateDistance(
        staffLatitude,
        staffLongitude,
        branchLat,
        branchLon,
      );
      final isWithinRadius = distance <= allowedRadius;

      // Check for existing active check-in
      final activeCheckIn = await _db
          .collection('staff_check_ins')
          .where('staffId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'checked_in')
          .get();

      if (activeCheckIn.docs.isNotEmpty) {
        final existingBranch = activeCheckIn.docs.first.data()['branchName'];
        return CheckInResult(
          success: false,
          message:
              'You already have an active check-in at $existingBranch. Please check out first.',
          isWithinRadius: isWithinRadius,
          distanceFromBranch: distance,
        );
      }

      // Validate location
      if (!isWithinRadius) {
        return CheckInResult(
          success: false,
          message:
              'You are ${LocationService.formatDistance(distance)} away from $branchName. You must be within ${LocationService.formatDistance(allowedRadius)} to check in.',
          isWithinRadius: false,
          distanceFromBranch: distance,
        );
      }

      // Create check-in record
      final checkInDoc = await _db.collection('staff_check_ins').add({
        'staffId': user.uid,
        'staffName': staffName,
        'staffRole': staffRole,
        'branchId': branchId,
        'branchName': branchName,
        'ownerUid': ownerUid,
        'checkInTime': FieldValue.serverTimestamp(),
        'checkOutTime': null,
        'staffLatitude': staffLatitude,
        'staffLongitude': staffLongitude,
        'branchLatitude': branchLat,
        'branchLongitude': branchLon,
        'distanceFromBranch': distance.round(),
        'isWithinRadius': true,
        'allowedRadius': allowedRadius,
        'status': 'checked_in',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return CheckInResult(
        success: true,
        message: 'Successfully checked in at $branchName',
        checkInId: checkInDoc.id,
        isWithinRadius: true,
        distanceFromBranch: distance,
      );
    } catch (e) {
      print('Check-in error: $e');
      return CheckInResult(
        success: false,
        message: 'Failed to check in. Please try again.',
      );
    }
  }

  /// Perform staff check-out
  static Future<CheckOutResult> checkOut(String checkInId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return CheckOutResult(success: false, message: 'Not authenticated');
      }

      final checkInDoc =
          await _db.collection('staff_check_ins').doc(checkInId).get();
      if (!checkInDoc.exists) {
        return CheckOutResult(success: false, message: 'Check-in not found');
      }

      final checkInData = checkInDoc.data()!;
      if (checkInData['staffId'] != user.uid) {
        return CheckOutResult(
          success: false,
          message: 'This check-in does not belong to you',
        );
      }

      if (checkInData['status'] != 'checked_in') {
        return CheckOutResult(success: false, message: 'Already checked out');
      }

      await _db.collection('staff_check_ins').doc(checkInId).update({
        'checkOutTime': FieldValue.serverTimestamp(),
        'status': 'checked_out',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Calculate hours worked
      final checkInTime = (checkInData['checkInTime'] as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(checkInTime);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      return CheckOutResult(
        success: true,
        message: 'Successfully checked out',
        hoursWorked: '${hours}h ${minutes}m',
      );
    } catch (e) {
      print('Check-out error: $e');
      return CheckOutResult(
        success: false,
        message: 'Failed to check out. Please try again.',
      );
    }
  }

  /// Get active check-in for current user
  static Future<StaffCheckInRecord?> getActiveCheckIn() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final query = await _db
          .collection('staff_check_ins')
          .where('staffId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'checked_in')
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return StaffCheckInRecord.fromFirestore(query.docs.first);
    } catch (e) {
      print('Error getting active check-in: $e');
      return null;
    }
  }

  /// Get check-in history for current user
  static Future<List<StaffCheckInRecord>> getCheckInHistory({int limit = 30}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final query = await _db
          .collection('staff_check_ins')
          .where('staffId', isEqualTo: user.uid)
          .orderBy('checkInTime', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => StaffCheckInRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting check-in history: $e');
      return [];
    }
  }

  /// Stream active check-in status
  static Stream<StaffCheckInRecord?> streamActiveCheckIn() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .collection('staff_check_ins')
        .where('staffId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'checked_in')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return StaffCheckInRecord.fromFirestore(snap.docs.first);
    });
  }
}
