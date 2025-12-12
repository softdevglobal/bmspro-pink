import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const primaryDark = Color(0xFFD81F75);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
}

// ============================================================================
// MODELS
// ============================================================================

class StaffMember {
  final String id;
  final String name;
  final String email;
  final String role;
  final String staffRole;
  final String status;
  final String? avatar;
  final Map<String, dynamic>? weeklySchedule;
  final Map<String, bool>? training;

  StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.staffRole,
    required this.status,
    this.avatar,
    this.weeklySchedule,
    this.training,
  });

  factory StaffMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffMember(
      id: doc.id,
      name: data['displayName'] ?? data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      staffRole: data['staffRole'] ?? '',
      status: data['status'] ?? 'Active',
      avatar: data['avatar'],
      weeklySchedule: data['weeklySchedule'] as Map<String, dynamic>?,
      training: data['training'] != null 
          ? Map<String, bool>.from(data['training']) 
          : null,
    );
  }
}

class BranchModel {
  final String id;
  final String name;

  BranchModel({required this.id, required this.name});
}

// ============================================================================
// STAFF MANAGEMENT PAGE
// ============================================================================

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  String? _ownerUid;
  List<StaffMember> _staff = [];
  List<BranchModel> _branches = [];
  bool _loading = true;
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final role = userDoc.data()?['role'] ?? '';
      String ownerUid = user.uid;
      
      if (role == 'salon_branch_admin') {
        ownerUid = userDoc.data()?['ownerUid'] ?? user.uid;
      }

      _ownerUid = ownerUid;

      // Subscribe to staff
      FirebaseFirestore.instance
          .collection('users')
          .where('ownerUid', isEqualTo: ownerUid)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _staff = snapshot.docs
                .where((doc) {
                  final role = doc.data()['role'] ?? '';
                  return role == 'salon_staff' || role == 'salon_branch_admin';
                })
                .map((doc) => StaffMember.fromFirestore(doc))
                .toList();
          });
        }
      });

      // Subscribe to branches
      FirebaseFirestore.instance
          .collection('branches')
          .where('ownerUid', isEqualTo: ownerUid)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _branches = snapshot.docs.map((doc) {
              final data = doc.data();
              return BranchModel(
                id: doc.id,
                name: data['name'] ?? '',
              );
            }).toList();
          });
        }
      });

      setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _loading = false);
    }
  }

  List<StaffMember> get _filteredStaff {
    if (_filterStatus == 'All') return _staff;
    return _staff.where((s) => s.status == _filterStatus).toList();
  }

  void _showStaffPreview(StaffMember staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StaffPreviewSheet(
        staff: staff,
        branches: _branches,
      ),
    );
  }

  void _showOnboardStaffSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OnboardStaffSheet(
        ownerUid: _ownerUid!,
        branches: _branches,
        onSuccess: () {
          Navigator.pop(context);
          _showToast('Staff onboarded successfully!');
        },
        onError: (message) {
          _showToast(message);
        },
      ),
    );
  }

  void _showEditStaffSheet(StaffMember staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditStaffSheet(
        staff: staff,
        branches: _branches,
        onSuccess: () {
          Navigator.pop(context);
          _showToast('Staff updated successfully!');
        },
        onError: (message) {
          _showToast(message);
        },
      ),
    );
  }

  void _showSuspendConfirmation(StaffMember staff) {
    final isSuspended = staff.status == 'Suspended';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSuspended ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSuspended ? FontAwesomeIcons.userCheck : FontAwesomeIcons.userSlash,
                size: 18,
                color: isSuspended ? Colors.green.shade600 : Colors.red.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSuspended ? 'Reactivate Account?' : 'Suspend Account?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSuspended
                  ? 'Are you sure you want to reactivate ${staff.name}\'s account? They will be able to log in again.'
                  : 'Are you sure you want to suspend ${staff.name}\'s account? They will not be able to log in until reactivated.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSuspended ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSuspended ? Colors.green.shade200 : Colors.amber.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.circleInfo,
                    size: 14,
                    color: isSuspended ? Colors.green.shade600 : Colors.amber.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isSuspended
                          ? 'This will enable their login access immediately.'
                          : 'This action will disable their login access.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSuspended ? Colors.green.shade700 : Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _suspendStaff(staff);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuspended ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              isSuspended ? 'Reactivate' : 'Suspend',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _suspendStaff(StaffMember staff) async {
    final isSuspended = staff.status == 'Suspended';
    final newStatus = isSuspended ? 'Active' : 'Suspended';

    try {
      // Update status in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(staff.id)
          .update({
        'status': newStatus,
        'suspended': !isSuspended,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Call the API to disable/enable Firebase Auth account
      try {
        final response = await http.post(
          Uri.parse('https://bmspro-pink-adminpanel.vercel.app/api/staff/auth/suspend'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'uid': staff.id,
            'disabled': !isSuspended,
          }),
        );
        
        if (response.statusCode != 200) {
          debugPrint('Auth suspend API returned: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Failed to update auth status: $e');
      }

      _showToast(isSuspended 
          ? '${staff.name} has been reactivated' 
          : '${staff.name} has been suspended');
    } catch (e) {
      debugPrint('Error suspending staff: $e');
      _showToast('Failed to update staff status');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(FontAwesomeIcons.circleCheck, color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, size: 18, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Staff Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_ownerUid != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _showOnboardStaffSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FontAwesomeIcons.userPlus, color: Colors.white, size: 12),
                      SizedBox(width: 6),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Filter Tabs
                _buildFilterTabs(),
                // Staff List
                Expanded(
                  child: _filteredStaff.isEmpty
                      ? _buildEmptyState()
                      : _buildStaffList(),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: ['All', 'Active', 'Suspended'].map((status) {
          final isSelected = _filterStatus == status;
          final count = status == 'All' 
              ? _staff.length 
              : _staff.where((s) => s.status == status).length;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filterStatus = status),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(FontAwesomeIcons.users, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Staff Found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus == 'All' 
                ? 'Add staff from the admin panel'
                : 'No ${_filterStatus.toLowerCase()} staff members',
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _filteredStaff.length,
        itemBuilder: (context, index) {
          final staff = _filteredStaff[index];
          return _buildStaffCard(staff);
        },
      ),
    );
  }

  Widget _buildStaffCard(StaffMember staff) {
    final workingDays = _getWorkingDays(staff.weeklySchedule);
    final trainingCompleted = _getTrainingStatus(staff.training);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Avatar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(0.8),
                        const Color(0xFFEC4899).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: staff.avatar != null && staff.avatar!.startsWith('http')
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            staff.avatar!, 
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                _getInitials(staff.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _getInitials(staff.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              staff.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: staff.status == 'Active' 
                                  ? Colors.green.shade50 
                                  : staff.status == 'Suspended'
                                      ? Colors.red.shade50
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: staff.status == 'Active' 
                                        ? Colors.green 
                                        : staff.status == 'Suspended'
                                            ? Colors.red
                                            : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  staff.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: staff.status == 'Active' 
                                        ? Colors.green.shade700 
                                        : staff.status == 'Suspended'
                                            ? Colors.red.shade700
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        staff.staffRole.isNotEmpty ? staff.staffRole : staff.role,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        staff.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Info Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon: FontAwesomeIcons.calendarDays,
                  label: workingDays.isNotEmpty ? workingDays : 'No schedule',
                  color: const Color(0xFF8B5CF6),
                ),
                _buildInfoChip(
                  icon: FontAwesomeIcons.graduationCap,
                  label: trainingCompleted,
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
          // Action Buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showStaffPreview(staff),
                    icon: const Icon(FontAwesomeIcons.eye, size: 12),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditStaffSheet(staff),
                    icon: const Icon(FontAwesomeIcons.penToSquare, size: 12),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      side: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSuspendConfirmation(staff),
                    icon: Icon(
                      staff.status == 'Suspended' 
                          ? FontAwesomeIcons.userCheck 
                          : FontAwesomeIcons.userSlash,
                      size: 12,
                    ),
                    label: Text(staff.status == 'Suspended' ? 'Activate' : 'Suspend'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: staff.status == 'Suspended' 
                          ? const Color(0xFF10B981) 
                          : const Color(0xFFEF4444),
                      side: BorderSide(
                        color: staff.status == 'Suspended' 
                            ? const Color(0xFF10B981).withOpacity(0.3) 
                            : const Color(0xFFEF4444).withOpacity(0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getWorkingDays(Map<String, dynamic>? schedule) {
    if (schedule == null) return '';
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    List<String> working = [];
    
    for (int i = 0; i < fullDays.length; i++) {
      final daySchedule = schedule[fullDays[i]];
      if (daySchedule != null && daySchedule['branchId'] != null && daySchedule['branchId'].toString().isNotEmpty) {
        working.add(days[i]);
      }
    }
    
    return working.join(', ');
  }

  String _getTrainingStatus(Map<String, bool>? training) {
    if (training == null) return 'No training';
    final completed = training.values.where((v) => v == true).length;
    final total = training.length;
    return '$completed/$total Training';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

// ============================================================================
// STAFF PREVIEW SHEET
// ============================================================================

class _StaffPreviewSheet extends StatelessWidget {
  final StaffMember staff;
  final List<BranchModel> branches;

  const _StaffPreviewSheet({
    required this.staff,
    required this.branches,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(FontAwesomeIcons.user, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Staff Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Profile Section
                _buildSectionCard(
                  title: 'Profile',
                  icon: FontAwesomeIcons.userCircle,
                  iconColor: const Color(0xFF8B5CF6),
                  child: Column(
                    children: [
                      // Avatar
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: staff.avatar != null && staff.avatar!.startsWith('http')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    staff.avatar!, 
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        _getInitials(staff.name),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _getInitials(staff.name),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('Name', staff.name),
                      const Divider(height: 24),
                      _buildDetailRow('Email', staff.email),
                      const Divider(height: 24),
                      _buildDetailRow('Role', staff.staffRole.isNotEmpty ? staff.staffRole : staff.role),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Text('Status', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: staff.status == 'Active' 
                                  ? Colors.green.shade50 
                                  : staff.status == 'Suspended'
                                      ? Colors.red.shade50
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              staff.status,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: staff.status == 'Active' 
                                    ? Colors.green.shade700 
                                    : staff.status == 'Suspended'
                                        ? Colors.red.shade700
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Weekly Schedule Section
                _buildSectionCard(
                  title: 'Weekly Schedule',
                  icon: FontAwesomeIcons.calendarWeek,
                  iconColor: const Color(0xFF3B82F6),
                  child: _buildWeeklySchedule(),
                ),
                const SizedBox(height: 16),

                // Training Section
                _buildSectionCard(
                  title: 'Training Status',
                  icon: FontAwesomeIcons.graduationCap,
                  iconColor: const Color(0xFF10B981),
                  child: _buildTrainingStatus(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Bottom Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
      ],
    );
  }

  Widget _buildWeeklySchedule() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (staff.weeklySchedule == null) {
      return const Text('No schedule configured', style: TextStyle(color: AppColors.muted));
    }

    return Column(
      children: List.generate(days.length, (index) {
        final daySchedule = staff.weeklySchedule![days[index]];
        final isWorking = daySchedule != null && 
            daySchedule['branchId'] != null && 
            daySchedule['branchId'].toString().isNotEmpty;
        final branchName = isWorking ? (daySchedule['branchName'] ?? 'Unknown') : null;

        return Container(
          margin: EdgeInsets.only(bottom: index < 6 ? 8 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isWorking ? const Color(0xFF3B82F6).withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isWorking ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                child: Text(
                  shortDays[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isWorking ? const Color(0xFF3B82F6) : Colors.grey.shade400,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  isWorking ? branchName! : 'Day Off',
                  style: TextStyle(
                    fontSize: 13,
                    color: isWorking ? AppColors.text : Colors.grey.shade400,
                  ),
                ),
              ),
              Icon(
                isWorking ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleMinus,
                size: 14,
                color: isWorking ? Colors.green : Colors.grey.shade300,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTrainingStatus() {
    if (staff.training == null || staff.training!.isEmpty) {
      return const Text('No training records', style: TextStyle(color: AppColors.muted));
    }

    final trainingItems = {
      'ohs': 'Occupational Health & Safety',
      'prod': 'Product Knowledge',
      'tool': 'Tools & Equipment',
    };

    return Column(
      children: staff.training!.entries.map((entry) {
        final name = trainingItems[entry.key] ?? entry.key;
        final completed = entry.value;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: completed ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: completed ? Colors.green.shade200 : Colors.orange.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                completed ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.clock,
                size: 14,
                color: completed ? Colors.green.shade600 : Colors.orange.shade600,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: completed ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  completed ? 'Completed' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: completed ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

// ============================================================================
// ONBOARD STAFF SHEET
// ============================================================================

class _OnboardStaffSheet extends StatefulWidget {
  final String ownerUid;
  final List<BranchModel> branches;
  final VoidCallback onSuccess;
  final Function(String) onError;

  const _OnboardStaffSheet({
    required this.ownerUid,
    required this.branches,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_OnboardStaffSheet> createState() => _OnboardStaffSheetState();
}

class _OnboardStaffSheetState extends State<_OnboardStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _roleController = TextEditingController();
  
  bool _saving = false;
  bool _showPassword = false;
  String _selectedRole = 'salon_staff';
  String? _selectedBranchId;
  Map<String, String?> _weeklySchedule = {
    'Monday': null,
    'Tuesday': null,
    'Wednesday': null,
    'Thursday': null,
    'Friday': null,
    'Saturday': null,
    'Sunday': null,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _onboardStaff() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final staffRole = _roleController.text.trim();

    if (_selectedRole == 'salon_branch_admin' && _selectedBranchId == null) {
      widget.onError('Branch Admins must be assigned to a branch');
      return;
    }

    setState(() => _saving = true);

    try {
      // Create Firebase Auth user
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user!.uid;

      // Build weekly schedule
      Map<String, dynamic> finalSchedule = {};
      if (_selectedRole == 'salon_branch_admin' && _selectedBranchId != null) {
        final branch = widget.branches.firstWhere((b) => b.id == _selectedBranchId);
        final branchAssignment = {'branchId': branch.id, 'branchName': branch.name};
        finalSchedule = {
          'Monday': branchAssignment,
          'Tuesday': branchAssignment,
          'Wednesday': branchAssignment,
          'Thursday': branchAssignment,
          'Friday': branchAssignment,
          'Saturday': branchAssignment,
          'Sunday': branchAssignment,
        };
      } else {
        // For regular staff, use selected schedule
        _weeklySchedule.forEach((day, branchId) {
          if (branchId != null) {
            final branch = widget.branches.firstWhere((b) => b.id == branchId);
            finalSchedule[day] = {'branchId': branch.id, 'branchName': branch.name};
          } else {
            finalSchedule[day] = null;
          }
        });
      }

      // Create user document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'authUid': uid,
        'email': email,
        'displayName': name,
        'name': name,
        'avatar': name,
        'role': _selectedRole,
        'systemRole': _selectedRole,
        'staffRole': staffRole,
        'ownerUid': widget.ownerUid,
        'status': 'Active',
        'provider': 'password',
        'branchId': _selectedBranchId ?? '',
        'branchName': _selectedBranchId != null 
            ? widget.branches.firstWhere((b) => b.id == _selectedBranchId).name 
            : '',
        'weeklySchedule': finalSchedule,
        'training': {'ohs': false, 'prod': false, 'tool': false},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update branch if branch admin
      if (_selectedRole == 'salon_branch_admin' && _selectedBranchId != null) {
        await FirebaseFirestore.instance
            .collection('branches')
            .doc(_selectedBranchId)
            .update({'adminStaffId': uid});
      }

      // Sign out the newly created user (so owner stays logged in)
      // The new user will need to sign in separately
      // Note: This is a workaround - ideally use Admin SDK via Cloud Function
      
      widget.onSuccess();
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to create staff account';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already in use';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      widget.onError(message);
    } catch (e) {
      debugPrint('Error onboarding staff: $e');
      widget.onError('Failed to onboard staff');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(FontAwesomeIcons.userPlus, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Onboard Staff',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Basic Info Section
                  _buildSectionCard(
                    title: 'Basic Information',
                    icon: FontAwesomeIcons.user,
                    iconColor: const Color(0xFF8B5CF6),
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('Full Name', 'e.g. John Doe'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _roleController,
                        decoration: _inputDecoration('Staff Role', 'e.g. Hair Stylist, Colorist'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Account Section
                  _buildSectionCard(
                    title: 'Account Details',
                    icon: FontAwesomeIcons.envelope,
                    iconColor: const Color(0xFF3B82F6),
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: _inputDecoration('Email Address', 'staff@example.com'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v!.isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: _inputDecoration('Password', 'Min 6 characters').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
                              size: 16,
                              color: AppColors.muted,
                            ),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        obscureText: !_showPassword,
                        validator: (v) {
                          if (v!.isEmpty) return 'Required';
                          if (v.length < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // System Role Section
                  _buildSectionCard(
                    title: 'System Role',
                    icon: FontAwesomeIcons.userShield,
                    iconColor: const Color(0xFFEC4899),
                    children: [
                      _buildRoleOption(
                        'salon_staff',
                        'Staff Member',
                        'Regular staff with basic access',
                        FontAwesomeIcons.user,
                      ),
                      const SizedBox(height: 10),
                      _buildRoleOption(
                        'salon_branch_admin',
                        'Branch Admin',
                        'Can manage a specific branch',
                        FontAwesomeIcons.userTie,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Branch Assignment Section
                  if (_selectedRole == 'salon_branch_admin')
                    _buildSectionCard(
                      title: 'Branch Assignment',
                      icon: FontAwesomeIcons.building,
                      iconColor: const Color(0xFF10B981),
                      children: [
                        ...widget.branches.map((branch) => RadioListTile<String>(
                          value: branch.id,
                          groupValue: _selectedBranchId,
                          onChanged: (v) => setState(() => _selectedBranchId = v),
                          title: Text(branch.name, style: const TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AppColors.primary,
                        )),
                        if (widget.branches.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No branches available', style: TextStyle(color: AppColors.muted)),
                          ),
                      ],
                    ),

                  // Weekly Schedule Section (for regular staff)
                  if (_selectedRole == 'salon_staff') ...[
                    _buildSectionCard(
                      title: 'Weekly Schedule (Optional)',
                      icon: FontAwesomeIcons.calendarWeek,
                      iconColor: const Color(0xFF10B981),
                      children: [
                        const Text(
                          'Assign working days and branches',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        ..._weeklySchedule.keys.map((day) => _buildDayScheduleRow(day)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Save Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _onboardStaff,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Creating...', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      )
                    : const Text(
                        'Onboard Staff',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRoleOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedRole = value;
        if (value == 'salon_staff') _selectedBranchId = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEC4899).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFEC4899) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEC4899).withOpacity(0.2) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: isSelected ? const Color(0xFFEC4899) : Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFFEC4899) : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(FontAwesomeIcons.circleCheck, size: 18, color: Color(0xFFEC4899)),
          ],
        ),
      ),
    );
  }

  Widget _buildDayScheduleRow(String day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              day.substring(0, 3),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _weeklySchedule[day],
                hint: Text('Day Off', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                isExpanded: true,
                icon: const Icon(FontAwesomeIcons.chevronDown, size: 12),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Day Off', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ),
                  ...widget.branches.map((branch) => DropdownMenuItem(
                    value: branch.id,
                    child: Text(branch.name, style: const TextStyle(fontSize: 13)),
                  )),
                ],
                onChanged: (v) => setState(() => _weeklySchedule[day] = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ============================================================================
// EDIT STAFF SHEET
// ============================================================================

class _EditStaffSheet extends StatefulWidget {
  final StaffMember staff;
  final List<BranchModel> branches;
  final VoidCallback onSuccess;
  final Function(String) onError;

  const _EditStaffSheet({
    required this.staff,
    required this.branches,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<_EditStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  
  bool _saving = false;
  late String _status;
  late Map<String, String?> _weeklySchedule;
  late Map<String, bool> _training;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff.name);
    _roleController = TextEditingController(text: widget.staff.staffRole);
    _status = widget.staff.status;
    
    // Initialize weekly schedule
    _weeklySchedule = {
      'Monday': null,
      'Tuesday': null,
      'Wednesday': null,
      'Thursday': null,
      'Friday': null,
      'Saturday': null,
      'Sunday': null,
    };
    
    if (widget.staff.weeklySchedule != null) {
      widget.staff.weeklySchedule!.forEach((day, value) {
        if (value != null && value['branchId'] != null && value['branchId'].toString().isNotEmpty) {
          _weeklySchedule[day] = value['branchId'].toString();
        }
      });
    }
    
    // Initialize training
    _training = {
      'ohs': widget.staff.training?['ohs'] ?? false,
      'prod': widget.staff.training?['prod'] ?? false,
      'tool': widget.staff.training?['tool'] ?? false,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _updateStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // Build weekly schedule
      Map<String, dynamic> finalSchedule = {};
      _weeklySchedule.forEach((day, branchId) {
        if (branchId != null) {
          final branch = widget.branches.firstWhere((b) => b.id == branchId);
          finalSchedule[day] = {'branchId': branch.id, 'branchName': branch.name};
        } else {
          finalSchedule[day] = null;
        }
      });

      // Check if status changed to/from Suspended
      final statusChanged = widget.staff.status != _status;
      final isSuspending = _status == 'Suspended';

      // Update user document
      await FirebaseFirestore.instance.collection('users').doc(widget.staff.id).update({
        'displayName': _nameController.text.trim(),
        'name': _nameController.text.trim(),
        'staffRole': _roleController.text.trim(),
        'status': _status,
        'suspended': isSuspending,
        'weeklySchedule': finalSchedule,
        'training': _training,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If status changed, update Firebase Auth disabled status
      if (statusChanged && (widget.staff.status == 'Suspended' || _status == 'Suspended')) {
        try {
          await http.post(
            Uri.parse('https://bmspro-pink-adminpanel.vercel.app/api/staff/auth/suspend'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'uid': widget.staff.id,
              'disabled': isSuspending,
            }),
          );
        } catch (e) {
          debugPrint('Failed to update auth status: $e');
        }
      }

      widget.onSuccess();
    } catch (e) {
      debugPrint('Error updating staff: $e');
      widget.onError('Failed to update staff');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(FontAwesomeIcons.userPen, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Edit Staff',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Basic Info Section
                  _buildSectionCard(
                    title: 'Basic Information',
                    icon: FontAwesomeIcons.user,
                    iconColor: const Color(0xFF3B82F6),
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('Full Name', 'e.g. John Doe'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _roleController,
                        decoration: _inputDecoration('Staff Role', 'e.g. Hair Stylist'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      // Email (read-only)
                      TextFormField(
                        initialValue: widget.staff.email,
                        decoration: _inputDecoration('Email', '').copyWith(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        enabled: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status Section
                  _buildSectionCard(
                    title: 'Status',
                    icon: FontAwesomeIcons.toggleOn,
                    iconColor: _status == 'Active' 
                        ? Colors.green 
                        : _status == 'Suspended' 
                            ? Colors.red 
                            : Colors.grey,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusOption('Active', Colors.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusOption('Suspended', Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Weekly Schedule Section
                  _buildSectionCard(
                    title: 'Weekly Schedule',
                    icon: FontAwesomeIcons.calendarWeek,
                    iconColor: const Color(0xFF8B5CF6),
                    children: [
                      ..._weeklySchedule.keys.map((day) => _buildDayScheduleRow(day)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Training Section
                  _buildSectionCard(
                    title: 'Training Status',
                    icon: FontAwesomeIcons.graduationCap,
                    iconColor: const Color(0xFF10B981),
                    children: [
                      _buildTrainingCheckbox('ohs', 'Occupational Health & Safety'),
                      _buildTrainingCheckbox('prod', 'Product Knowledge'),
                      _buildTrainingCheckbox('tool', 'Tools & Equipment'),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Save Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _updateStaff,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusOption(String status, Color color) {
    final isSelected = _status == status;
    return GestureDetector(
      onTap: () => setState(() => _status = status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayScheduleRow(String day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              day.substring(0, 3),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _weeklySchedule[day],
                hint: Text('Day Off', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                isExpanded: true,
                icon: const Icon(FontAwesomeIcons.chevronDown, size: 12),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Day Off', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ),
                  ...widget.branches.map((branch) => DropdownMenuItem(
                    value: branch.id,
                    child: Text(branch.name, style: const TextStyle(fontSize: 13)),
                  )),
                ],
                onChanged: (v) => setState(() => _weeklySchedule[day] = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingCheckbox(String key, String label) {
    return CheckboxListTile(
      value: _training[key] ?? false,
      onChanged: (v) => setState(() => _training[key] = v ?? false),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      activeColor: const Color(0xFF10B981),
      contentPadding: EdgeInsets.zero,
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
