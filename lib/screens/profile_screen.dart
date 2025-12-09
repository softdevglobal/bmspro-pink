import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';

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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _avatarPulseController;
  final List<Animation<Offset>> _menuSlideAnimations = [];
  final List<Animation<double>> _menuFadeAnimations = [];

  // Live user data
  String _name = '';
  String _role = '';
  String _photoUrl = '';
  String? _ratingLabel;
  String? _experienceLabel;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _avatarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: false);
    for (int i = 0; i < 3; i++) {
      final start = 0.2 + (i * 0.1);
      final end = start + 0.4;
      _menuSlideAnimations.add(
        Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve:
                Interval(start, end > 1.0 ? 1.0 : end, curve: Curves.easeOut),
          ),
        ),
      );
      _menuFadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve:
                Interval(start, end > 1.0 ? 1.0 : end, curve: Curves.easeOut),
          ),
        ),
      );
    }
    _entranceController.forward();
    _loadProfile();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _avatarPulseController.dispose();
    super.dispose();
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
      String role = '';
      String photoUrl = user.photoURL ?? '';
      String? ratingLabel;
      String? experienceLabel;

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
                  user.email ??
                  'Team Member')
              .toString();
          role = (data['staffRole'] ??
                  data['role'] ??
                  'Team Member')
              .toString();
          photoUrl = (data['photoURL'] ?? data['avatarUrl'] ?? photoUrl)
              .toString();

          // Fallback for staff records created from the admin panel where
          // avatar is stored in the 'avatar' field (and may be either a URL
          // or just a name). Only use it if it looks like a real URL.
          final avatarField = data['avatar'];
          if (avatarField is String &&
              (avatarField.startsWith('http://') ||
                  avatarField.startsWith('https://'))) {
            photoUrl = avatarField;
          }

          final rating = data['rating'];
          if (rating is num) {
            ratingLabel = rating.toStringAsFixed(1);
          }

          final expYears = data['experienceYears'];
          if (expYears is num && expYears > 0) {
            experienceLabel = '${expYears.toInt()} Years';
          } else if (data['createdAt'] != null) {
            final ts = data['createdAt'];
            DateTime? created;
            if (ts is Timestamp) {
              created = ts.toDate();
            }
            if (created != null) {
              final years =
                  DateTime.now().difference(created).inDays ~/ 365;
              if (years >= 1) {
                experienceLabel = '$years Year${years == 1 ? '' : 's'}';
              } else {
                experienceLabel = 'New Staff';
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading profile from Firestore: $e');
      }

      if (!mounted) return;
      setState(() {
        _name = name.isNotEmpty ? name : (user.email ?? 'Team Member');
        _role = role.isNotEmpty ? role : 'Team Member';
        _photoUrl = photoUrl;
        _ratingLabel = ratingLabel;
        _experienceLabel = experienceLabel;
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Text(
                        'Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildMenu(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, size: 16, color: AppColors.text)),
    );
  }

  Widget _buildProfileHeader() {
    return SlideTransition(
      position:
          Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
      ),
      child: FadeTransition(
        opacity: _entranceController,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  AnimatedBuilder(
                    animation: _avatarPulseController,
                    builder: (context, child) {
                      final value = _avatarPulseController.value;
                      final scale = 1.0 + (math.sin(value * math.pi) * 0.02);
                      final shadowBlur =
                          30.0 + (math.sin(value * math.pi) * 20.0);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: shadowBlur,
                                spreadRadius: 0,
                              ),
                            ],
                            color: _photoUrl.isEmpty
                                ? Colors.white
                                : null,
                            image: _photoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_photoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _photoUrl.isEmpty
                              ? Center(
                                  child: Text(
                                    (_name.isNotEmpty
                                            ? _name.trim()[0]
                                            : 'S')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _name.isNotEmpty ? _name : 'Team Member',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _role.isNotEmpty ? _role : '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              if (!_loadingProfile &&
                  (_ratingLabel != null || _experienceLabel != null))
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_ratingLabel != null) ...[
                      const Icon(
                        FontAwesomeIcons.star,
                        color: Color(0xFFFDE047),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_ratingLabel Rating',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (_ratingLabel != null && _experienceLabel != null)
                      const SizedBox(width: 16),
                    if (_experienceLabel != null) ...[
                      const Icon(
                        FontAwesomeIcons.calendar,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _experienceLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Column(
      children: [
        _buildMenuItem(0, FontAwesomeIcons.userPen, 'Edit Profile',
            'Update personal information'),
        const SizedBox(height: 16),
        _buildMenuItem(1, FontAwesomeIcons.gear, 'Settings',
            'App preferences and notifications'),
        const SizedBox(height: 16),
        _buildMenuItem(2, FontAwesomeIcons.rightFromBracket, 'Logout',
            'Sign out of your account',
            isLogout: true),
      ],
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title, String subtitle,
      {bool isLogout = false}) {
    return FadeTransition(
      opacity: _menuFadeAnimations[index],
      child: SlideTransition(
        position: _menuSlideAnimations[index],
        child: _LedBorderButton(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isLogout
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.accent],
                            ),
                      color: isLogout ? Colors.red.shade500 : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                        child: Icon(icon, color: Colors.white, size: 20)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isLogout
                                ? Colors.red.shade600
                                : AppColors.text),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 14,
                            color: isLogout
                                ? Colors.red.shade400
                                : AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(FontAwesomeIcons.chevronRight,
                  size: 16,
                  color: isLogout ? Colors.red.shade400 : AppColors.muted),
            ],
          ),
          isLogout: isLogout,
          onTap: () {
            if (title == 'Edit Profile') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
            } else if (title == 'Settings') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            } else if (isLogout) {
              _showLogoutConfirmDialog();
            }
          },
        ),
      ),
    );
  }
}

extension _LogoutDialog on _ProfileScreenState {
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(FontAwesomeIcons.rightFromBracket,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Confirm Logout',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to sign out of your account?',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          foregroundColor: AppColors.text,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Navigate to login and clear the stack
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Ink(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.accent]),
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            child: const Text('Logout',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
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
      },
    );
  }
}

class _LedBorderButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isLogout;
  const _LedBorderButton({
    required this.child,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  State<_LedBorderButton> createState() => _LedBorderButtonState();
}

class _LedBorderButtonState extends State<_LedBorderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLogout) {
      return Material(
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade200, width: 2),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: widget.child,
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: SweepGradient(
              colors: const [
                AppColors.primary,
                AppColors.accent,
                AppColors.primary,
              ],
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
