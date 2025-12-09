import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'walk_in_booking_page.dart';

class OwnerBookingsPage extends StatefulWidget {
  const OwnerBookingsPage({super.key});

  @override
  State<OwnerBookingsPage> createState() => _OwnerBookingsPageState();
}

class _OwnerBookingsPageState extends State<OwnerBookingsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  // Live booking data from Firestore (bookings + bookingRequests for this owner)
  List<_Booking> _bookings = [];
  // List of available staff
  List<Map<String, dynamic>> _staffList = [];
  // List of services for staff assignment validation
  List<Map<String, dynamic>> _servicesList = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingRequestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _staffSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _servicesSub;

  bool _loading = true;
  String? _error;
  
  // User role and branch for filtering
  String? _userRole;
  String? _userBranchId;
  String? _ownerUid;

  @override
  void initState() {
    super.initState();
    _loadUserContextAndListen();
  }
  
  Future<void> _loadUserContextAndListen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = "Not signed in";
      });
      return;
    }

    // Fetch user document to get role and branchId
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        _userRole = (data['role'] ?? '').toString();
        _userBranchId = (data['branchId'] ?? '').toString();
        
        // Determine ownerUid based on role
        if (_userRole == 'salon_owner') {
          _ownerUid = user.uid;
        } else if (data['ownerUid'] != null) {
          _ownerUid = data['ownerUid'].toString();
        } else {
          _ownerUid = user.uid;
        }
      } else {
        _ownerUid = user.uid;
      }
    } catch (e) {
      debugPrint('Error loading user context: $e');
      _ownerUid = user.uid;
    }

    // Now start listening with the proper context
    _listenToBookings();
    _listenToStaff();
    _listenToServices();
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _bookingRequestsSub?.cancel();
    _staffSub?.cancel();
    _servicesSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToServices() {
    if (_ownerUid == null) return;

    _servicesSub = FirebaseFirestore.instance
        .collection('services')
        .where('ownerUid', isEqualTo: _ownerUid)
        .snapshots()
        .listen((snap) {
      final List<Map<String, dynamic>> loaded = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        loaded.add({
          'id': doc.id,
          'name': (data['name'] ?? '').toString(),
          'staffIds': List<String>.from(data['staffIds'] ?? []),
        });
      }
      if (mounted) {
        setState(() {
          _servicesList = loaded;
        });
      }
    }, onError: (e) {
      debugPrint("Error fetching services: $e");
    });
  }

  void _listenToStaff() {
    if (_ownerUid == null) return;

    final bool isBranchAdmin = _userRole == 'salon_branch_admin' && _userBranchId != null && _userBranchId!.isNotEmpty;

    // Listen to users where ownerUid matches
    // and role is 'salon_staff' or 'salon_branch_admin'
    _staffSub = FirebaseFirestore.instance
        .collection('users')
        .where('ownerUid', isEqualTo: _ownerUid)
        .snapshots()
        .listen((snap) {
      final List<Map<String, dynamic>> loaded = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final role = (data['role'] ?? '').toString();
        if (role == 'salon_staff' || role == 'salon_branch_admin') {
          final staffBranchId = (data['branchId'] ?? '').toString();
          // For branch admins, only show staff from their branch
          if (isBranchAdmin && staffBranchId != _userBranchId) continue;
          
          loaded.add({
            'id': doc.id,
            'name': (data['displayName'] ?? data['name'] ?? 'Unknown').toString(),
            'role': (data['staffRole'] ?? data['role'] ?? 'Staff').toString(),
            'avatarUrl': (data['photoURL'] ?? data['avatarUrl']).toString(),
            'branchId': staffBranchId,
            'weeklySchedule': data['weeklySchedule'] as Map<String, dynamic>?,
          });
        }
      }
      if (mounted) {
        setState(() {
          _staffList = loaded;
        });
      }
    }, onError: (e) {
      debugPrint("Error fetching staff: $e");
    });
  }

  void _listenToBookings() {
    if (_ownerUid == null) {
      setState(() {
        _loading = false;
        _error = "Not signed in";
      });
      return;
    }

    final bool isBranchAdmin = _userRole == 'salon_branch_admin' && _userBranchId != null && _userBranchId!.isNotEmpty;

    List<_Booking> bookingsData = [];
    List<_Booking> bookingRequestsData = [];

    void mergeAndSet() {
      // Merge and deduplicate by an internal key (client+date+time+service as fallback)
      final Map<String, _Booking> map = {};
      for (final b in bookingsData) {
        // For branch admins, filter by branchId
        if (isBranchAdmin && b.branchId != _userBranchId) continue;
        map[b.mergeKey] = b;
      }
      for (final b in bookingRequestsData) {
        // For branch admins, filter by branchId
        if (isBranchAdmin && b.branchId != _userBranchId) continue;
        map[b.mergeKey] = b;
      }
      final merged = map.values.toList()
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

      if (mounted) {
        setState(() {
          _bookings = merged;
          _loading = false;
        });
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerUid', isEqualTo: _ownerUid)
        .snapshots()
        .listen(
      (snap) {
        bookingsData = snap.docs
            .map((d) => _Booking.fromDoc(d, collection: 'bookings'))
            .toList();
        mergeAndSet();
      },
      onError: (e) {
        if (mounted) {
          setState(() => _error ??= e.toString());
        }
      },
    );

    _bookingRequestsSub = FirebaseFirestore.instance
        .collection('bookingRequests')
        .where('ownerUid', isEqualTo: _ownerUid)
        .snapshots()
        .listen(
      (snap) {
        bookingRequestsData = snap.docs
            .map((d) => _Booking.fromDoc(d, collection: 'bookingRequests'))
            .toList();
        mergeAndSet();
      },
      onError: (e) {
        if (mounted) {
          setState(() => _error ??= e.toString());
        }
      },
    );
  }

  Future<void> _updateBookingStatus(_Booking booking, String newStatus,
      {List<Map<String, dynamic>>? updatedServices}) async {
    final db = FirebaseFirestore.instance;
    try {
      // Check if services need update
      final bool hasServicesUpdate = updatedServices != null && updatedServices.isNotEmpty;

      // If confirming a booking request, move it to 'bookings' collection
      if (booking.collection == 'bookingRequests' && newStatus == 'confirmed') {
        // Update services array in the booking request itself first (cleaner logic)
        // This ensures the object we copy from is up to date, though we construct newData manually below.
        
        final newData = Map<String, dynamic>.from(booking.rawData);
        newData['status'] = 'confirmed';
        newData['updatedAt'] = FieldValue.serverTimestamp();
        
        // Ensure services are updated in the new booking document
        if (hasServicesUpdate) {
          newData['services'] = updatedServices;
        }

        if (newData['createdAt'] == null) {
          newData['createdAt'] = FieldValue.serverTimestamp();
        }

        // Remove top-level staff fields if they exist to avoid confusion
        // Only if we have services list, otherwise keep them for legacy support
        if (hasServicesUpdate || (newData['services'] != null && (newData['services'] as List).isNotEmpty)) {
          newData.remove('staffId');
          newData.remove('staffName');
        }

        // Add to bookings
        final ref = await db.collection('bookings').add(newData);
        // Delete from bookingRequests
        await db.collection('bookingRequests').doc(booking.id).delete();
        
        // Create notification
        await _createNotification(
          bookingId: ref.id,
          booking: booking,
          newStatus: 'Confirmed',
          updatedServices: updatedServices,
        );

      } else {
        // Update existing booking
        final Map<String, dynamic> updateData = {'status': newStatus};
        
        // CRITICAL FIX: Also update services array in the existing document if provided
        if (hasServicesUpdate) {
          updateData['services'] = updatedServices;
          
          // Also clean up top-level fields if they exist
          updateData['staffId'] = FieldValue.delete();
          updateData['staffName'] = FieldValue.delete();
        }

        await db
            .collection(booking.collection)
            .doc(booking.id)
            .update(updateData);
            
        // Create notification
        // normalize status string for notification function (Capitalized)
        String notifStatus = _capitalise(newStatus);
        if (newStatus == 'cancelled') notifStatus = 'Canceled';
        
        await _createNotification(
          bookingId: booking.id,
          booking: booking,
          newStatus: notifStatus,
          updatedServices: updatedServices,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking marked as ${_capitalise(newStatus)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createNotification({
    required String bookingId,
    required _Booking booking,
    required String newStatus,
    List<Map<String, dynamic>>? updatedServices,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final raw = booking.rawData;
      
      // Determine final values (updated or existing)
      final finalServices = updatedServices ?? booking.items;
      final finalStaffName = (updatedServices != null && updatedServices.isNotEmpty)
          ? (updatedServices.first['staffName'] ?? booking.staff)
          : booking.staff;
      
      // Generate content
      final content = _getNotificationContent(
        status: newStatus,
        bookingCode: raw['bookingCode']?.toString(),
        staffName: finalStaffName, // This is just for the message text
        serviceName: booking.service,
        bookingDate: booking.date,
        bookingTime: (raw['time'] ?? '').toString(),
        services: finalServices,
      );

      final notifData = {
        'bookingId': bookingId,
        'type': content['type'],
        'title': content['title'],
        'message': content['message'],
        'status': newStatus,
        'ownerUid': raw['ownerUid'],
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Remove top-level staffName from notification data if it exists in raw
      // But we might want to keep it if the notification UI expects it for display
      // For now, we'll keep it as a fallback display value
      notifData['staffName'] = finalStaffName;

      // Add optional fields
      if (raw['customerUid'] != null) notifData['customerUid'] = raw['customerUid'];
      if (raw['clientEmail'] != null) notifData['customerEmail'] = raw['clientEmail'];
      if (raw['clientPhone'] != null) notifData['customerPhone'] = raw['clientPhone'];
      if (raw['bookingCode'] != null) notifData['bookingCode'] = raw['bookingCode'];
      
      // Richer details
      notifData['staffName'] = finalStaffName;
      notifData['serviceName'] = booking.service;
      if (raw['branchName'] != null) notifData['branchName'] = raw['branchName'];
      if (booking.date.isNotEmpty) notifData['bookingDate'] = booking.date;
      final time = (raw['time'] ?? '').toString();
      if (time.isNotEmpty) notifData['bookingTime'] = time;
      
      if (finalServices.isNotEmpty) {
        notifData['services'] = finalServices.map((s) => {
          'name': s['name'] ?? 'Service',
          'staffName': s['staffName'] ?? 'Any Available',
        }).toList();
      }

      await db.collection('notifications').add(notifData);
    } catch (e) {
      debugPrint("Error creating notification: $e");
    }
  }

  Map<String, String> _getNotificationContent({
    required String status,
    String? bookingCode,
    String? staffName,
    String? serviceName,
    String? bookingDate,
    String? bookingTime,
    List<Map<String, dynamic>>? services,
  }) {
    String code = bookingCode != null ? " ($bookingCode)" : "";
    String serviceAndStaff = "";
    String datetime = "";

    if (bookingDate != null && bookingTime != null) {
      datetime = " on $bookingDate at $bookingTime";
    }

    if (services != null && services.length > 1) {
      serviceAndStaff = " for ${services.length} services";
    } else {
      String s = serviceName ?? "Service";
      String st = staffName != null && staffName.isNotEmpty && staffName != 'Any staff' 
          ? " with $staffName" 
          : "";
      serviceAndStaff = " for $s$st";
    }

    switch (status) {
      case "Pending":
        return {
          "title": "Booking Request Received",
          "message": "Your booking request$code$serviceAndStaff has been received successfully! We'll confirm your appointment soon.",
          "type": "booking_status_changed"
        };
      case "Confirmed":
        return {
          "title": "Booking Confirmed",
          "message": "Your booking$code$serviceAndStaff$datetime has been confirmed. We look forward to seeing you!",
          "type": "booking_confirmed"
        };
      case "Completed":
        return {
          "title": "Booking Completed",
          "message": "Your booking$code$serviceAndStaff has been completed. Thank you for visiting us!",
          "type": "booking_completed"
        };
      case "Canceled":
      case "Cancelled":
        return {
          "title": "Booking Canceled",
          "message": "Your booking$code$serviceAndStaff$datetime has been canceled. Please contact us if you have any questions.",
          "type": "booking_canceled"
        };
      default:
        return {
          "title": "Booking Status Updated",
          "message": "Your booking$code status has been updated to $status.",
          "type": "booking_status_changed"
        };
    }
  }

  // New dialog for confirming booking with detailed service-wise staff assignment
  void _showConfirmationWithDetailsDialog(
      BuildContext context, _Booking booking) {
    // Prepare initial state for services
    final List<Map<String, dynamic>> servicesToEdit = [];
    final List<bool> isLocked = [];

    if (booking.items.isNotEmpty) {
      for (var item in booking.items) {
        final m = Map<String, dynamic>.from(item);
        servicesToEdit.add(m);
        final sName = (m['staffName'] ?? '').toString().toLowerCase();
        isLocked.add(sName.isNotEmpty &&
            !sName.contains('any staff') &&
            !sName.contains('any available'));
      }
    } else {
      servicesToEdit.add({
        'name': booking.service,
        'staffName': booking.staff,
        'staffId': booking.rawData['staffId'],
        'price': booking.priceValue,
        'duration': booking.duration,
      });
      final sName = booking.staff.toLowerCase();
      isLocked.add(sName.isNotEmpty &&
          !sName.contains('any staff') &&
          !sName.contains('any available'));
    }

    // Pre-calculate available staff for each service
    String dayName = '';
    try {
      final parts = booking.date.split('-');
      if (parts.length == 3) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        // 1=Mon, 7=Sun. Map to keys used in DB (Monday, Tuesday...)
        const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        dayName = days[dt.weekday - 1];
      }
    } catch (_) {}

    List<List<Map<String, dynamic>>> availableStaffPerService = [];
    for (var service in servicesToEdit) {
      final sName = (service['name'] ?? '').toString();
      availableStaffPerService.add(_getAvailableStaffForService(sName, booking.branchId, dayName));
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          bool canConfirm = true;
          for (var service in servicesToEdit) {
            final staffName =
                (service['staffName'] ?? '').toString().toLowerCase();
            if (staffName.isEmpty ||
                staffName.contains('any staff') ||
                staffName.contains('any available')) {
              canConfirm = false;
              break;
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          FontAwesomeIcons.calendarCheck,
                          color: Color(0xFFFF2D8F),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Booking',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Assign staff to proceed",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: servicesToEdit.asMap().entries.map((entry) {
                          final index = entry.key;
                          final service = entry.value;
                          final locked = isLocked[index];
                          final currentStaffId = service['staffId'];
                          final availableStaff = availableStaffPerService[index];

                          // Ensure current staff is in the list even if filtered out (e.g. strict rules changed)
                          // This avoids UI bugs if data is slightly inconsistent
                          List<Map<String, dynamic>> dropdownStaff = [...availableStaff];
                          if (currentStaffId != null && 
                              !dropdownStaff.any((s) => s['id'] == currentStaffId)) {
                             final found = _staffList.firstWhere((s) => s['id'] == currentStaffId, orElse: () => {});
                             if (found.isNotEmpty) dropdownStaff.add(found);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF3F4F6)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        service['name'] ?? 'Service',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (locked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.check_circle,
                                                size: 12,
                                                color: Color(0xFF059669)),
                                            SizedBox(width: 4),
                                            Text(
                                              "Assigned",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (locked)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(FontAwesomeIcons.userTie,
                                            size: 14, color: Color(0xFF6B7280)),
                                        const SizedBox(width: 12),
                                        Text(
                                          service['staffName'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.lock_outline,
                                            size: 16, color: Color(0xFF9CA3AF)),
                                      ],
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: canConfirm
                                                ? const Color(0xFFE5E7EB)
                                                : const Color(0xFFFEE2E2),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            icon: const Icon(
                                                Icons.keyboard_arrow_down_rounded),
                                            hint: const Row(
                                              children: [
                                                Icon(FontAwesomeIcons.user,
                                                    size: 14,
                                                    color: Color(0xFF9CA3AF)),
                                                SizedBox(width: 12),
                                                Text("Select Staff Member"),
                                              ],
                                            ),
                                            value: dropdownStaff.any((s) =>
                                                    s['id'] == currentStaffId)
                                                ? currentStaffId
                                                : null,
                                            items: dropdownStaff.map((staff) {
                                              final String avatar = (staff['avatarUrl'] ?? '').toString();
                                              final String name = staff['name'];
                                              final String url = (avatar.isNotEmpty && avatar != 'null')
                                                  ? avatar
                                                  : 'https://ui-avatars.com/api/?background=random&color=fff&name=${Uri.encodeComponent(name)}';

                                              return DropdownMenuItem<String>(
                                                value: staff['id'],
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 12,
                                                      backgroundImage: NetworkImage(url),
                                                      backgroundColor: Colors.grey.shade200,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                final selectedStaff =
                                                    _staffList.firstWhere(
                                                        (s) => s['id'] == val);
                                                setState(() {
                                                  service['staffId'] =
                                                      selectedStaff['id'];
                                                  service['staffName'] =
                                                      selectedStaff['name'];
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      if ((service['staffName'] ?? '')
                                              .toString()
                                              .toLowerCase()
                                              .contains('any staff') ||
                                          (service['staffName'] ?? '')
                                              .toString()
                                              .toLowerCase()
                                              .contains('any available'))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 6, left: 4),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.info_outline,
                                                  size: 12,
                                                  color: Color(0xFFEF4444)),
                                              SizedBox(width: 4),
                                              Text(
                                                "Staff assignment required",
                                                style: TextStyle(
                                                  color: Color(0xFFEF4444),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: canConfirm
                              ? () {
                                  Navigator.pop(ctx);
                                  _updateBookingStatus(
                                    booking,
                                    'confirmed',
                                    updatedServices: servicesToEdit,
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2D8F),
                            disabledBackgroundColor:
                                const Color(0xFFFF2D8F).withOpacity(0.5),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Confirm Booking',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  List<Map<String, dynamic>> _getAvailableStaffForService(
      String serviceName, String branchId, String dayName) {
    // 1. Find service definition
    final service = _servicesList.firstWhere(
      (s) => s['name'] == serviceName,
      orElse: () => {},
    );
    final List<String> allowedStaffIds =
        service.isNotEmpty ? List<String>.from(service['staffIds'] ?? []) : [];

    return _staffList.where((staff) {
      // 2. Check Service Capability (if defined)
      if (service.isNotEmpty && allowedStaffIds.isNotEmpty) {
        if (!allowedStaffIds.contains(staff['id'])) return false;
      }

      // 3. Check Schedule and Branch
      // If dayName is valid, check if staff works on this day
      if (dayName.isNotEmpty) {
        final schedule = staff['weeklySchedule'] as Map<String, dynamic>?;
        if (schedule != null) {
          final daySchedule = schedule[dayName];
          if (daySchedule == null) return false; // Not working today

          // Check if scheduled at the booking branch
          final scheduledBranch = daySchedule['branchId'];
          if (scheduledBranch != null && scheduledBranch.toString() != branchId) {
             return false; // Scheduled at a different branch
          }
        } else {
          // No schedule defined - fallback to home branch check
           if (staff['branchId'] != branchId) return false;
        }
      } else {
        // No date info - fallback to home branch check
        if (staff['branchId'] != branchId) return false;
      }

      return true;
    }).toList();
  }

  void _showConfirmDialog(BuildContext context, String action,
      VoidCallback onConfirm, {String? subtitle}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${_capitalise(action)} Booking?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to $action this booking?'),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Yes',
                style: TextStyle(
                    color: Color(0xFFFF2D8F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _capitalise(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFFFF2D8F);
    const Color background = Color(0xFFFFF5FA);

    // Aggregate stats from all bookings (not filtered by search)
    final totalCount = _bookings.length;
    final confirmedCount =
        _bookings.where((b) => b.status == 'confirmed').length;
    final pendingCount = _bookings.where((b) => b.status == 'pending').length;
    final completedCount =
        _bookings.where((b) => b.status == 'completed').length;

    double revenue = 0.0;
    for (final b in _bookings) {
      if (b.status == 'confirmed' || b.status == 'completed') {
        revenue += b.priceValue;
      }
    }

    final revenueLabel =
        revenue > 0 ? '\$${revenue.toStringAsFixed(0)}' : '\$0';

    final filtered = _bookings.where((b) {
      final matchesStatus =
          _statusFilter == 'all' ? true : b.status == _statusFilter;
      final term = _searchController.text.trim().toLowerCase();
      if (term.isEmpty) return matchesStatus;
      final inText =
          '${b.customerName} ${b.email} ${b.service} ${b.staff}'.toLowerCase();
      return matchesStatus && inText.contains(term);
    }).toList();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header + Create Booking button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: background,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bookings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        backgroundColor: const Color(0xFFFF2D8F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WalkInBookingPage(),
                          ),
                        );
                      },
                      icon: const Icon(
                        FontAwesomeIcons.calendarPlus,
                        size: 14,
                      ),
                      label: const Text(
                        'New Booking',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total Bookings',
                            value: '$totalCount',
                            color: Colors.black87,
                            background: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Confirmed Bookings',
                            value: '$confirmedCount',
                            color: const Color(0xFF166534),
                            background: const Color(0xFFD1FAE5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Booking Requests',
                            value: '$pendingCount',
                            color: const Color(0xFF92400E),
                            background: const Color(0xFFFEEFC3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Completed Bookings',
                            value: '$completedCount',
                            color: const Color(0xFF1D4ED8),
                            background: const Color(0xFFDBEAFE),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            label: 'Revenue',
                            value: revenueLabel,
                            color: const Color(0xFF5B21B6),
                            background: const Color(0xFFEDE9FE),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search bookings...',
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Color(0xFF9CA3AF)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.filter_alt,
                              size: 18, color: Color(0xFF9CA3AF)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primary),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.list,
                                    size: 14, color: Colors.black54),
                                SizedBox(width: 12),
                                Text('All Statuses'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.hourglassHalf,
                                    size: 14, color: Color(0xFFD97706)),
                                SizedBox(width: 12),
                                Text('Booking Requests'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'confirmed',
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.check,
                                    size: 14, color: Color(0xFF166534)),
                                SizedBox(width: 12),
                                Text('Confirmed Bookings'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.checkDouble,
                                    size: 14, color: Color(0xFF1D4ED8)),
                                SizedBox(width: 12),
                                Text('Completed Bookings'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.ban,
                                    size: 14, color: Color(0xFFB91C1C)),
                                SizedBox(width: 12),
                                Text('Cancelled Bookings'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _statusFilter = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bookings list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: filtered
                      .map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BookingCard(
                              booking: b,
                              onStatusUpdate: (status) {
                                if (status == 'confirmed') {
                                  // Show detailed service-wise staff assignment dialog
                                  _showConfirmationWithDetailsDialog(context, b);
                                } else {
                                  _showConfirmDialog(
                                    context,
                                    status,
                                    () => _updateBookingStatus(b, status),
                                  );
                                }
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            background.withOpacity(0.9),
            background.withOpacity(0.8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: background.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: background.withOpacity(0.65),
            blurRadius: 18,
            offset: const Offset(0, 10),
            spreadRadius: -12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.4,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Booking {
  final String id;
  final String collection;
  final Map<String, dynamic> rawData;
  final String mergeKey;
  final DateTime sortKey;
  final String customerName;
  final String email;
  final String avatarUrl;
  final String status; // confirmed, pending, completed, cancelled
  final String service;
  final String staff;
  final String branchId;
  final String date; // Keep raw date for schedule checking
  final String dateTime;
  final String duration;
  final String price;
  final double priceValue;
  final IconData icon;
  final List<Map<String, dynamic>> items;

  const _Booking({
    required this.id,
    required this.collection,
    required this.rawData,
    required this.mergeKey,
    required this.sortKey,
    required this.customerName,
    required this.email,
    required this.avatarUrl,
    required this.status,
    required this.service,
    required this.staff,
    required this.branchId,
    required this.date,
    required this.dateTime,
    required this.duration,
    required this.price,
    required this.priceValue,
    required this.icon,
    required this.items,
  });

  // Build a booking model from a Firestore document
  static _Booking fromDoc(DocumentSnapshot<Map<String, dynamic>> doc,
      {String collection = 'bookings'}) {
    final data = doc.data() ?? {};
    final client = (data['client'] ?? 'Walk-in').toString();
    final email = (data['clientEmail'] ?? '').toString();
    final staffName = (data['staffName'] ?? 'Any staff').toString();
    final branchId = (data['branchId'] ?? '').toString();
    
    // Parse items list
    List<Map<String, dynamic>> items = [];
    if (data['services'] is List) {
      final list = data['services'] as List;
      for (var item in list) {
        if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    }

    String serviceName = (data['serviceName'] ?? '').toString();
    if (serviceName.isEmpty && items.isNotEmpty) {
       serviceName = (items.first['name'] ?? 'Service').toString();
    }
    if (serviceName.isEmpty) serviceName = 'Service';

    final date = (data['date'] ?? '').toString(); // YYYY-MM-DD
    final time = (data['time'] ?? '').toString(); // HH:mm
    String dateTimeLabel;
    DateTime sortKey;
    try {
      if (date.isNotEmpty && time.isNotEmpty) {
        final parts = date.split('-');
        final tParts = time.split(':');
        sortKey = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          int.parse(tParts[0]),
          tParts.length > 1 ? int.parse(tParts[1]) : 0,
        );
        dateTimeLabel = '$date at $time';
      } else {
        sortKey = DateTime.fromMillisecondsSinceEpoch(0);
        dateTimeLabel = (date + (time.isNotEmpty ? ' $time' : '')).trim();
      }
    } catch (_) {
      sortKey = DateTime.fromMillisecondsSinceEpoch(0);
      dateTimeLabel = (date + (time.isNotEmpty ? ' $time' : '')).trim();
    }

    final durationMinutes = (data['duration'] ?? 0);
    String durationLabel = '';
    if (durationMinutes is num && durationMinutes > 0) {
      if (durationMinutes >= 60 && durationMinutes % 60 == 0) {
        final hours = durationMinutes ~/ 60;
        durationLabel = '$hours hour${hours > 1 ? 's' : ''}';
      } else {
        durationLabel = '${durationMinutes.toString()} minutes';
      }
    }

    final rawPrice = (data['price'] ?? 0);
    double priceValue = 0;
    if (rawPrice is num) {
      priceValue = rawPrice.toDouble();
    } else {
      priceValue = double.tryParse(rawPrice.toString()) ?? 0.0;
    }
    final priceLabel =
        priceValue > 0 ? '\$${priceValue.toStringAsFixed(0)}' : '\$0';

    String status =
        (data['status'] ?? 'pending').toString().toLowerCase();
    if (status == 'canceled') status = 'cancelled';

    final avatarUrl = (data['avatarUrl'] ??
            'https://ui-avatars.com/api/?background=FF2D8F&color=fff&name=${Uri.encodeComponent(client)}')
        .toString();

    IconData icon = FontAwesomeIcons.scissors;
    final serviceLower = serviceName.toLowerCase();
    if (serviceLower.contains('nail')) {
      icon = FontAwesomeIcons.handSparkles;
    } else if (serviceLower.contains('facial') ||
        serviceLower.contains('spa')) {
      icon = FontAwesomeIcons.spa;
    } else if (serviceLower.contains('massage')) {
      icon = FontAwesomeIcons.spa;
    } else if (serviceLower.contains('extension')) {
      icon = FontAwesomeIcons.wandMagicSparkles;
    }

    final mergeKey =
        doc.id.isNotEmpty ? doc.id : '$client|$date|$time|$serviceName';

    return _Booking(
      id: doc.id,
      collection: collection,
      rawData: data,
      mergeKey: mergeKey,
      sortKey: sortKey,
      customerName: client,
      email: email,
      avatarUrl: avatarUrl,
      status: status,
      service: serviceName,
      staff: staffName,
      branchId: branchId,
      date: date,
      dateTime: dateTimeLabel,
      duration: durationLabel,
      price: priceLabel,
      priceValue: priceValue,
      icon: icon,
      items: items,
    );
  }
}

class _BookingCard extends StatelessWidget {
  final _Booking booking;
  final Function(String) onStatusUpdate;

  const _BookingCard({required this.booking, required this.onStatusUpdate});

  Color _statusBg(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFFD1FAE5);
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'completed':
        return const Color(0xFFDBEAFE);
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF166534);
      case 'pending':
        return const Color(0xFF92400E);
      case 'completed':
        return const Color(0xFF1D4ED8);
      case 'cancelled':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF4B5563);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBg = _statusBg(booking.status);
    final statusColor = _statusColor(booking.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(booking.avatarUrl),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        booking.email,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _capitalise(booking.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(
            icon: booking.icon,
            text: booking.service,
          ),
          _infoRow(
            icon: FontAwesomeIcons.user,
            text: 'with ${booking.staff}',
          ),
          _infoRow(
            icon: FontAwesomeIcons.calendar,
            text: booking.dateTime,
          ),
          _infoRow(
            icon: FontAwesomeIcons.clock,
            text: booking.duration,
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: booking.status == 'cancelled'
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFFFF2D8F),
                  decoration: booking.status == 'cancelled'
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ActionIcon(
                      icon: FontAwesomeIcons.eye,
                      background: const Color(0xFFE0EDFF),
                      color: const Color(0xFF2563EB),
                      onTap: () => _showBookingDetails(context, booking),
                    ),
                    if (booking.status == 'pending') ...[
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: "Confirm",
                        background: const Color(0xFFDCFCE7),
                        color: const Color(0xFF166534),
                        onTap: () => onStatusUpdate('confirmed'),
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: "Decline",
                        background: const Color(0xFFFEE2E2),
                        color: const Color(0xFFB91C1C),
                        onTap: () => onStatusUpdate('cancelled'),
                      ),
                    ] else if (booking.status == 'confirmed') ...[
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: "Complete",
                        background: const Color(0xFFDBEAFE),
                        color: const Color(0xFF1D4ED8),
                        onTap: () => onStatusUpdate('completed'),
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: "Cancel",
                        background: const Color(0xFFFEE2E2),
                        color: const Color(0xFFB91C1C),
                        onTap: () => onStatusUpdate('cancelled'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(BuildContext context, _Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF5FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Header with Avatar and Status
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(booking.avatarUrl),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            booking.customerName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBg(booking.status),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _capitalise(booking.status),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(booking.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Details Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Services",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (booking.items.isEmpty)
                            // Fallback if no items list (legacy bookings)
                            _buildServiceItem(
                              name: booking.service,
                              staff: booking.staff,
                              time: booking.dateTime,
                              duration: booking.duration,
                              price: booking.price,
                            )
                          else
                            ...booking.items.map((item) {
                              final name = (item['name'] ?? 'Service').toString();
                              final staff =
                                  (item['staffName'] ?? booking.staff).toString();
                              final dur = (item['duration'] ?? 0);
                              final durStr = '$dur min';
                              final pr = (item['price'] ?? 0);
                              final prStr = '\$${pr}';
                              
                              // Use booking time if per-service time is missing
                              final time = booking.dateTime; 

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _buildServiceItem(
                                  name: name,
                                  staff: staff,
                                  time: time, // or specific time if available
                                  duration: durStr,
                                  price: prStr,
                                ),
                              );
                            }).toList(),
                          
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Total Price",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                booking.price,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF2D8F),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Close Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D8F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem({
    required String name,
    required String staff,
    required String time,
    required String duration,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF2D8F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _itemDetailRow(FontAwesomeIcons.userTie, staff, const Color(0xFF8B5CF6)),
          const SizedBox(height: 8),
          _itemDetailRow(FontAwesomeIcons.clock, "$time • $duration", const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _itemDetailRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalise(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color color;
  final VoidCallback? onTap;

  const _ActionIcon({
    required this.icon,
    required this.background,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.background,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
