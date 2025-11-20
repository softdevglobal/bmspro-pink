import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- 1. Theme & Colors (Matching HTML/Tailwind) ---
class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
  static const green = Color(0xFF10B981);
  static const purple = Color(0xFF9333EA); // Purple-600
  static const blue = Color(0xFF2563EB); // Blue-600
}

class WalkInBookingPage extends StatefulWidget {
  const WalkInBookingPage({super.key});

  @override
  State<WalkInBookingPage> createState() => _WalkInBookingPageState();
}

class _WalkInBookingPageState extends State<WalkInBookingPage> with TickerProviderStateMixin {
  // State Variables
  int _bookingType = 0; // 0: Anonymous, 1: Profile
  String _selectedServiceId = ''; // ID of the selected service
  String _selectedStaffId = 'any'; // ID of selected staff
  bool _isProcessing = false;

  // Custom Service Data
  Map<String, dynamic>? _customServiceData; // Holds custom service details if created

  // Controllers
  final TextEditingController _guestIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Mock Data
  final List<Map<String, dynamic>> _services = [
    {'id': '1', 'name': 'Haircut', 'time': '45m', 'price': 65, 'icon': FontAwesomeIcons.scissors, 'color': Colors.purple},
    {'id': '2', 'name': 'Color & Style', 'time': '2 hrs', 'price': 180, 'icon': FontAwesomeIcons.palette, 'color': AppColors.primary},
    {'id': '3', 'name': 'Massage', 'time': '60m', 'price': 95, 'icon': FontAwesomeIcons.spa, 'color': AppColors.blue},
    {'id': '4', 'name': 'Facial', 'time': '45m', 'price': 85, 'icon': FontAwesomeIcons.leaf, 'color': AppColors.green},
    {'id': '5', 'name': 'Manicure', 'time': '30m', 'price': 45, 'icon': FontAwesomeIcons.handSparkles, 'color': Colors.orange},
  ];

  final List<Map<String, dynamic>> _staff = [
    {'id': 'any', 'name': 'Any Staff', 'avatar': null},
    {'id': '1', 'name': 'Emma', 'avatar': 'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-5.jpg'},
    {'id': '2', 'name': 'Michael', 'avatar': 'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-2.jpg'},
    {'id': '3', 'name': 'Sarah', 'avatar': 'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-6.jpg'},
    {'id': '4', 'name': 'James', 'avatar': 'https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-3.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    // Generate Guest ID
    final now = DateTime.now();
    _guestIdController.text = "Guest #${now.hour}${now.minute}${now.second}";
    // Fade Animation
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _guestIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---
  double get _totalPrice {
    if (_selectedServiceId == 'custom') {
      return (_customServiceData?['price'] ?? 0).toDouble();
    }
    if (_selectedServiceId.isNotEmpty) {
      final service = _services.firstWhere((s) => s['id'] == _selectedServiceId, orElse: () => {});
      if (service.isNotEmpty) {
        return (service['price'] as num).toDouble();
      }
    }
    return 0.0;
  }

  void _toggleBookingType(int type) {
    setState(() {
      _bookingType = type;
    });
  }

  void _selectService(String id) {
    setState(() {
      if (_selectedServiceId == id) {
        _selectedServiceId = ''; // Deselect
      } else {
        _selectedServiceId = id;
      }
    });
  }

  // --- Custom Service Dialog Logic ---
  void _openCustomServiceDialog() {
    final nameCtrl = TextEditingController(text: _customServiceData?['name'] ?? '');
    final priceCtrl = TextEditingController(text: _customServiceData?['price']?.toString() ?? '');
    final durationCtrl = TextEditingController(text: _customServiceData?['duration']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(FontAwesomeIcons.wandMagicSparkles, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            const Text("Custom Service", style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("Create your own service", style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: _inputDecoration("Service Name *", "e.g. Deep Conditioning"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration("Price (\$)*", "0"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration("Duration (min) *", "30"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty && durationCtrl.text.isNotEmpty) {
                setState(() {
                  _customServiceData = {
                    'name': nameCtrl.text,
                    'price': int.tryParse(priceCtrl.text) ?? 0,
                    'duration': int.tryParse(durationCtrl.text) ?? 0,
                  };
                  _selectedServiceId = 'custom';
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  void _confirmBooking() {
    if (_totalPrice == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a service")));
      return;
    }
    setState(() => _isProcessing = true);
    // Simulate processing
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppColors.green, content: Text("Booking Confirmed!")),
        );
        Navigator.pop(context);
      }
    });
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildToggle(),
                      const SizedBox(height: 24),
                      _buildCustomerForm(),
                      const SizedBox(height: 24),
                      const Text("Select Services", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 16),
                      _buildServiceGrid(),
                      const SizedBox(height: 24),
                      const Text("Assign Staff", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 16),
                      _buildStaffSelector(),
                      const SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.xmark, color: AppColors.text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Text('New Walk-in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedServiceId = '';
                _selectedStaffId = 'any';
                _customServiceData = null;
              });
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _toggleBtn('Anonymous', FontAwesomeIcons.userSecret, 0),
          _toggleBtn('Client Profile', FontAwesomeIcons.user, 1),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, IconData icon, int index) {
    final isSelected = _bookingType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleBookingType(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
            color: isSelected ? null : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerForm() {
    if (_bookingType == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guest ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
            const SizedBox(height: 8),
            TextField(
              controller: _guestIdController,
              readOnly: true,
              style: const TextStyle(color: AppColors.text),
              decoration: _inputDecoration(null, null),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: _inputDecoration("Full Name *", "Enter name")),
            const SizedBox(height: 12),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _inputDecoration("Phone *", "04XX XXX XXX")),
            const SizedBox(height: 12),
            TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration("Email", "email@example.com")),
          ],
        ),
      );
    }
  }

  Widget _buildServiceGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: _services.length + 1, // +1 for Custom Service
      itemBuilder: (context, index) {
        if (index == _services.length) {
          return _buildCustomServiceCard();
        }
        return _buildServiceCard(_services[index]);
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final isSelected = _selectedServiceId == service['id'];
    final color = service['color'] as Color;
    return GestureDetector(
      onTap: () => _selectService(service['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
          border: isSelected ? null : Border.all(color: Colors.transparent),
          gradient: isSelected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(service['icon'], color: isSelected ? Colors.white : color, size: 18)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.text,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      service['time'],
                      style: TextStyle(color: isSelected ? Colors.white70 : AppColors.muted, fontSize: 12),
                    ),
                    Text(
                      '\$${service['price']}',
                      style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCustomServiceCard() {
    final isSelected = _selectedServiceId == 'custom';
    final hasData = _customServiceData != null;
    return GestureDetector(
      onTap: _openCustomServiceDialog,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: AppColors.primary, style: BorderStyle.solid, width: 1),
          gradient: isSelected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(hasData ? FontAwesomeIcons.star : FontAwesomeIcons.plus, color: isSelected ? Colors.white : AppColors.primary, size: 18)),
            ),
            const SizedBox(height: 8),
            Text(
              hasData ? _customServiceData!['name'] : 'Custom Service',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.text,
                fontSize: 14,
              ),
            ),
            if (hasData)
              Text(
                '\$${_customServiceData!['price']}',
                style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
              )
            else
              Text(
                'Add your own',
                style: TextStyle(color: isSelected ? Colors.white70 : AppColors.muted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffSelector() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _staff.length,
        itemBuilder: (context, index) {
          final staff = _staff[index];
          final isSelected = _selectedStaffId == staff['id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedStaffId = staff['id']),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
                    ),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        image: staff['avatar'] != null
                            ? DecorationImage(image: NetworkImage(staff['avatar']), fit: BoxFit.cover)
                            : null,
                      ),
                      child: staff['avatar'] == null
                          ? const Center(child: Icon(FontAwesomeIcons.users, color: AppColors.primary, size: 20))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    staff['name'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text('\$${_totalPrice.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
            ],
          ),
          SizedBox(
            width: 200,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(FontAwesomeIcons.check, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Confirm Booking', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String? label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
    );
  }
}


