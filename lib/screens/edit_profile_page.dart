import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'change_password_page.dart';

// --- 1. Theme & Colors ---
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

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _avatarUrl = '';
  String _logoUrl = '';
  String _userRole = '';
  bool _hasChanges = false;
  bool _isSaving = false;
  late Map<String, String> _originalValues;

  bool _loadingProfile = true;

  late AnimationController _avatarPulseController;
  late AnimationController _savePulseController;

  late AnimationController _entranceController;
  final List<Animation<Offset>> _slideAnimations = [];
  final List<Animation<double>> _fadeAnimations = [];

  @override
  void initState() {
    super.initState();
    _originalValues = {
      'name': '',
      'email': '',
      'phone': '',
      'avatar': '',
    };
    _nameController.addListener(_checkForChanges);
    _emailController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);

    _avatarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: false);

    _savePulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    for (int i = 0; i < 3; i++) {
      final double start = 0.1 + (i * 0.1);
      final double end = start + 0.4;
      _slideAnimations.add(
        Tween<Offset>(begin: const Offset(-0.1, 0), end: Offset.zero).animate(
          CurvedAnimation(
              parent: _entranceController,
              curve: Interval(start, end, curve: Curves.easeOut)),
        ),
      );
      _fadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
              parent: _entranceController,
              curve: Interval(start, end, curve: Curves.easeOut)),
        ),
      );
    }
    _entranceController.forward();

    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _avatarPulseController.dispose();
    _savePulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final bool hasChanges =
        _nameController.text != _originalValues['name'] ||
        _emailController.text != _originalValues['email'] ||
        _phoneController.text != _originalValues['phone'] ||
        _avatarUrl != _originalValues['avatar'];
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loadingProfile = false;
        });
        return;
      }

      String name = user.displayName ?? '';
      String email = user.email ?? '';
      String phone = '';
      String avatarUrl = user.photoURL ?? '';

      String logoUrl = '';
      String userRole = '';
      
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>? ?? {};
          name = (data['displayName'] ??
                  data['name'] ??
                  name ??
                  email ??
                  'Staff Member')
              .toString();
          email = (data['email'] ?? email).toString();
          phone = (data['phone'] ?? data['clientPhone'] ?? '').toString();
          avatarUrl =
              (data['photoURL'] ?? data['avatarUrl'] ?? avatarUrl).toString();
          logoUrl = (data['logoUrl'] ?? '').toString();
          userRole = (data['role'] ?? '').toString();
        }
      } catch (e) {
        debugPrint('Error loading profile in edit page: $e');
      }

      if (!mounted) return;
      setState(() {
        _nameController.text = name;
        _emailController.text = email;
        _phoneController.text = phone;
        _avatarUrl = avatarUrl;
        _logoUrl = logoUrl;
        _userRole = userRole;
        _originalValues = {
          'name': name,
          'email': email,
          'phone': phone,
          'avatar': avatarUrl,
        };
        _hasChanges = false;
        _loadingProfile = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      final String name = _nameController.text.trim();
      final String email = _emailController.text.trim();
      final String phone = _phoneController.text.trim();

      // Update auth profile (display name & photo)
      if (name.isNotEmpty && name != user.displayName) {
        await user.updateDisplayName(name);
      }
      if (_avatarUrl.isNotEmpty && _avatarUrl != (user.photoURL ?? '')) {
        await user.updatePhotoURL(_avatarUrl);
      }

      // Update Firestore user document
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final Map<String, dynamic> update = {
        'displayName': name,
        'name': name,
        'email': email,
        'phone': phone,
      };
      if (_avatarUrl.isNotEmpty) {
        update['photoURL'] = _avatarUrl;
        update['avatarUrl'] = _avatarUrl;
      }
      await docRef.set(update, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasChanges = false;
        _originalValues = {
          'name': name,
          'email': email,
          'phone': phone,
          'avatar': _avatarUrl,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: 8),
            Text("Profile updated")
          ]),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showPictureModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PictureModal(
        onCamera: () => _pickAndUploadImage(ImageSource.camera),
        onGallery: () => _pickAndUploadImage(ImageSource.gallery),
        onRemove: _removePhoto,
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    Navigator.pop(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('staff_avatars')
          .child('${user.uid}.jpg');

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _hasChanges = true;
      });
    } catch (e) {
      debugPrint('Error picking/uploading image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update picture: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _removePhoto() {
    Navigator.pop(context);
    setState(() {
      _avatarUrl = '';
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_loadingProfile) _buildProfilePictureSection(),
                    const SizedBox(height: 24),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 24),
                    _buildPasswordSection(),
                    const SizedBox(height: 24),
                    _buildPointsSection(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              FontAwesomeIcons.chevronLeft,
              size: 18,
              color: AppColors.text,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Edit Profile',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    // For salon owner, show logo if available
    final bool isSalonOwner = _userRole.toLowerCase() == 'salon_owner';
    final String displayImageUrl = isSalonOwner && _logoUrl.isNotEmpty 
        ? _logoUrl 
        : _avatarUrl;
    final bool hasImage = displayImageUrl.isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          // Show "Salon Logo" label for salon owner
          if (isSalonOwner) ...[
            const Text(
              'Salon Logo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _avatarPulseController,
                builder: (context, child) {
                  final double value = _avatarPulseController.value;
                  final double scale =
                      1.0 + (math.sin(value * math.pi) * 0.02);
                  final double shadowBlur =
                      30.0 + (math.sin(value * math.pi) * 20.0);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasImage ? null : AppColors.background,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: shadowBlur,
                            spreadRadius: 0,
                          ),
                        ],
                        image: hasImage
                            ? DecorationImage(
                                image: NetworkImage(displayImageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: !hasImage
                          ? Center(
                              child: Icon(
                                isSalonOwner 
                                    ? FontAwesomeIcons.store 
                                    : FontAwesomeIcons.user,
                                color: AppColors.primary.withOpacity(0.5),
                                size: 36,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.2), width: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSalonOwner && _logoUrl.isNotEmpty) ...[
            const Text(
              'Update logo from Admin Panel',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: _showPictureModal,
              child: const Text(
                'Change Picture',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Information',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 16),
          _buildAnimatedField(0, 'Full Name', _nameController,
              TextInputType.name),
          const SizedBox(height: 16),
          _buildAnimatedField(1, 'Email Address', _emailController,
              TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildAnimatedField(
              2, 'Phone Number', _phoneController, TextInputType.phone),
        ],
      ),
    );
  }

  Widget _buildAnimatedField(int index, String label,
      TextEditingController controller, TextInputType type) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: type,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.accent],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                            child: Icon(FontAwesomeIcons.lock,
                                color: Colors.white, size: 20)),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Change Password',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text)),
                          Text('Update your account password',
                              style:
                                  TextStyle(fontSize: 14, color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                  const Icon(FontAwesomeIcons.chevronRight,
                      color: AppColors.muted, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPointsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.accent.withOpacity(0.1)
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Icon(FontAwesomeIcons.star,
                        color: Colors.white, size: 20)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACSU Staff Points',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  Text('Your reward balance',
                      style: TextStyle(fontSize: 14, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ShimmerText('1,540'),
              Text('points',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return AnimatedBuilder(
      animation: _savePulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: _hasChanges
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent])
                : null,
            color: _hasChanges ? null : Colors.grey.shade200,
            boxShadow: _hasChanges
                ? [
                    BoxShadow(
                      color: AppColors.primary
                          .withOpacity(0.3 + (_savePulseController.value * 0.2)),
                      blurRadius: 15 + (_savePulseController.value * 10),
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _hasChanges ? _saveChanges : null,
              borderRadius: BorderRadius.circular(30),
              child: Center(
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Saving...',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Text(
                        'Save Changes',
                        style: TextStyle(
                          color:
                              _hasChanges ? Colors.white : Colors.grey.shade400,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.08),
          blurRadius: 25,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

// --- Helper: Shimmer Text Effect ---
class _ShimmerText extends StatefulWidget {
  final String text;
  const _ShimmerText(this.text);

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [AppColors.primary, AppColors.accent, AppColors.primary],
              stops: const [0.0, 0.5, 1.0],
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ).createShader(bounds);
          },
          child: const Text(
            '1,540',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      },
    );
  }
}

// --- Helper: Picture Modal ---
class _PictureModal extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  const _PictureModal({
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 24)),
          const Text('Change Profile Picture',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 24),
          _buildModalBtn(
              context,
              'Take Photo',
              FontAwesomeIcons.camera,
              const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
              onCamera),
          const SizedBox(height: 12),
          _buildModalBtn(
              context,
              'Choose from Gallery',
              FontAwesomeIcons.images,
              const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
              onGallery),
          const SizedBox(height: 12),
          _buildModalBtn(context, 'Remove Photo', FontAwesomeIcons.trash, null,
              onRemove,
              isDestructive: true),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style:
                    TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildModalBtn(BuildContext context, String text, IconData icon,
      Gradient? gradient, VoidCallback onTap,
      {bool isDestructive = false}) {
    return Material(
      color: isDestructive ? Colors.red.shade50 : AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: gradient,
                  color: isDestructive ? Colors.red : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child:
                        Icon(icon, color: Colors.white, size: 20)),
              ),
              const SizedBox(width: 16),
              Text(
                text,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color:
                        isDestructive ? Colors.red.shade700 : AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


