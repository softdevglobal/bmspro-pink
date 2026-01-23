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

class Package {
  final String id;
  final String name;
  final double price;
  final String priceLabel;
  final int branches;
  final int staff;
  final List<String> features;
  final bool? popular;
  final String color;
  final String? image;
  final String? icon;
  final bool? active;
  final double? additionalBranchPrice;

  Package({
    required this.id,
    required this.name,
    required this.price,
    required this.priceLabel,
    required this.branches,
    required this.staff,
    required this.features,
    this.popular,
    required this.color,
    this.image,
    this.icon,
    this.active,
    this.additionalBranchPrice,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] is num) ? json['price'].toDouble() : 0.0,
      priceLabel: json['priceLabel']?.toString() ?? '',
      branches: json['branches'] is int ? json['branches'] : (json['branches'] is String ? int.tryParse(json['branches']) ?? 1 : 1),
      staff: json['staff'] is int ? json['staff'] : (json['staff'] is String ? int.tryParse(json['staff']) ?? 1 : 1),
      features: json['features'] is List ? (json['features'] as List).map((e) => e.toString()).toList() : [],
      popular: json['popular'] == true || json['popular'] == 'true',
      color: json['color']?.toString() ?? 'pink',
      image: json['image']?.toString(),
      icon: json['icon']?.toString(),
      active: json['active'] != false && json['active'] != 'false',
      additionalBranchPrice: json['additionalBranchPrice'] != null 
          ? ((json['additionalBranchPrice'] is num) 
              ? json['additionalBranchPrice'].toDouble() 
              : double.tryParse(json['additionalBranchPrice'].toString()))
          : null,
    );
  }
}

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _loading = true;
  bool _packagesLoading = true;
  String? _userName;
  String? _userEmail;
  String? _currentPlan;
  String? _currentPrice;
  List<Package> _packages = [];
  
  // Confirmation modal state
  bool _showConfirmModal = false;
  Package? _selectedPackage;
  bool _updating = false;

  // Calculator state
  int _branches = 1;
  int _staff = 0;
  static const double PRICE_BRANCH = 29.0;
  static const double PRICE_STAFF = 9.99;

  static const String _apiBaseUrl = 'https://bmspro-pink-adminpanel.vercel.app';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchPackages();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && doc.exists) {
        final data = doc.data()!;
        setState(() {
          _userName = data['name'] ?? data['displayName'] ?? '';
          _userEmail = user.email ?? data['email'] ?? '';
          _currentPlan = data['plan']?.toString() ?? '';
          _currentPrice = data['price']?.toString() ?? '';
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPackages() async {
    try {
      setState(() => _packagesLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No authenticated user');
        if (mounted) setState(() => _packagesLoading = false);
        return;
      }

      debugPrint('📤 Fetching packages from Firestore: subscription_plans');
      
      // Fetch directly from Firestore instead of API
      final snapshot = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .orderBy('price', descending: false)
          .get();

      debugPrint('📦 Found ${snapshot.docs.length} packages in Firestore');

      if (mounted) {
        try {
          final allPackages = snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  // Add the document ID to the data
                  data['id'] = doc.id;
                  return Package.fromJson(data);
                } catch (e) {
                  debugPrint('❌ Error parsing package ${doc.id}: $e');
                  debugPrint('❌ Package data: ${doc.data()}');
                  return null;
                }
              })
              .whereType<Package>()
              .toList();
          
          // Filter active packages
          final activePackages = allPackages
              .where((pkg) {
                final isActive = pkg.active != false;
                debugPrint('📦 Package ${pkg.name}: active=$isActive');
                return isActive;
              })
              .toList();
          
          debugPrint('✅ Loaded ${activePackages.length} active packages');
          
          setState(() {
            _packages = activePackages;
            _packagesLoading = false;
          });
        } catch (e, stackTrace) {
          debugPrint('❌ Error processing packages: $e');
          debugPrint('❌ Stack trace: $stackTrace');
          if (mounted) setState(() => _packagesLoading = false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching packages from Firestore: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) setState(() => _packagesLoading = false);
    }
  }

  void _updateCalc(String type, int change) {
    setState(() {
      if (type == 'branch') {
        _branches = (_branches + change).clamp(1, 999);
      } else {
        _staff = (_staff + change).clamp(0, 999);
      }
    });
  }

  void _selectPlan(Package pkg) {
    setState(() {
      _selectedPackage = pkg;
      _showConfirmModal = true;
    });
  }

  Future<void> _confirmPlanChange() async {
    if (_selectedPackage == null) return;
    
    try {
      setState(() => _updating = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update the user's subscription in Firestore
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.update({
        'plan': _selectedPackage!.name,
        'price': _selectedPackage!.priceLabel,
        'planId': _selectedPackage!.id,
        'planUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Also update the owner document if exists
      final ownerRef = FirebaseFirestore.instance.collection('owners').doc(user.uid);
      final ownerSnap = await ownerRef.get();
      if (ownerSnap.exists) {
        await ownerRef.update({
          'plan': _selectedPackage!.name,
          'price': _selectedPackage!.priceLabel,
          'planId': _selectedPackage!.id,
          'planUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Update local state
      setState(() {
        _currentPlan = _selectedPackage!.name;
        _currentPrice = _selectedPackage!.priceLabel;
        _showConfirmModal = false;
        _selectedPackage = null;
        _updating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating subscription: $e');
      setState(() => _updating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update subscription. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getGradientColor(String color) {
    switch (color) {
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'pink':
        return const Color(0xFFFF2D8F);
      case 'purple':
        return const Color(0xFF8B5CF6);
      case 'green':
        return const Color(0xFF10B981);
      case 'orange':
        return const Color(0xFFF59E0B);
      case 'teal':
        return const Color(0xFF14B8A6);
      default:
        return const Color(0xFFFF2D8F);
    }
  }

  List<Color> _getGradientColors(String color) {
    switch (color) {
      case 'blue':
        return [const Color(0xFF3B82F6), const Color(0xFF6366F1)];
      case 'pink':
        return [const Color(0xFFFF2D8F), const Color(0xFFFF6FB5)];
      case 'purple':
        return [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)];
      case 'green':
        return [const Color(0xFF10B981), const Color(0xFF34D399)];
      case 'orange':
        return [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];
      case 'teal':
        return [const Color(0xFF14B8A6), const Color(0xFF2DD4BF)];
      default:
        return [const Color(0xFFFF2D8F), const Color(0xFFFF6FB5)];
    }
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
          'Subscription',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF2D8F), Color(0xFFFF6FB5), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Icon Row
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        FontAwesomeIcons.crown,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Upgrade Membership',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Subtitle
                              Padding(
                                padding: const EdgeInsets.only(left: 60),
                                child: Text(
                                  'Scale your business with flexible pricing plans',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.95),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              // Current Plan Badge
                              if (_currentPlan != null && _currentPlan!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            FontAwesomeIcons.check,
                                            color: Color(0xFFFF2D8F),
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Current: $_currentPlan${_currentPrice != null && _currentPrice!.isNotEmpty ? " • $_currentPrice" : ""}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Pricing Cards
                        if (_packagesLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          )
                        else if (_packages.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    FontAwesomeIcons.boxOpen,
                                    size: 48,
                                    color: AppColors.muted,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No subscription plans available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _packages.length,
                            itemBuilder: (context, index) {
                              final pkg = _packages[index];
                              final isCurrentPlan = _currentPlan == pkg.name;
                              final gradientColors = _getGradientColors(pkg.color);
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildPackageCard(pkg, isCurrentPlan, gradientColors),
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        // Custom Enterprise Calculator
                        _buildCustomCalculator(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
          // Confirmation Modal
          if (_showConfirmModal && _selectedPackage != null)
            _buildConfirmationModal(),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Package pkg, bool isCurrentPlan, List<Color> gradientColors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isCurrentPlan
            ? Border.all(color: const Color(0xFF10B981), width: 2)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row with Icon, Name, Price, and Badges
            Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      pkg.icon != null
                          ? _getIconFromString(pkg.icon!)
                          : FontAwesomeIcons.box,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name and Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pkg.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          // Badges
                          if (pkg.popular == true)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.yellow.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.crown,
                                    color: Colors.orange,
                                    size: 8,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Popular',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isCurrentPlan)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.check,
                                    color: Colors.white,
                                    size: 8,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Current',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pkg.priceLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: gradientColors[0],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Branches and Staff
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FontAwesomeIcons.building,
                      size: 11,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pkg.branches == -1 ? 'Unlimited' : pkg.branches} Branch${pkg.branches != 1 ? 'es' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FontAwesomeIcons.users,
                      size: 11,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pkg.staff == -1 ? 'Unlimited' : pkg.staff} Staff',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Additional Branch Price
            if (pkg.additionalBranchPrice != null && pkg.additionalBranchPrice! > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    FontAwesomeIcons.plusCircle,
                    size: 10,
                    color: gradientColors[0],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Additional branches: \$${pkg.additionalBranchPrice!.toStringAsFixed(2)}/branch',
                    style: TextStyle(
                      fontSize: 10,
                      color: gradientColors[0],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            // Features List - Show all features
            if (pkg.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...pkg.features.map((feature) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            FontAwesomeIcons.check,
                            color: Colors.white,
                            size: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.text,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrentPlan ? null : () => _selectPlan(pkg),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlan
                      ? const Color(0xFF10B981).withOpacity(0.2)
                      : gradientColors[0],
                  foregroundColor: isCurrentPlan
                      ? const Color(0xFF10B981)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: isCurrentPlan ? 0 : 2,
                ),
                child: Text(
                  isCurrentPlan ? 'Current Plan' : 'Select Plan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomCalculator() {
    final branchTotal = _branches * PRICE_BRANCH;
    final staffTotal = _staff * PRICE_STAFF;
    final grandTotal = branchTotal + staffTotal;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          top: BorderSide(color: AppColors.primary, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom Enterprise Plan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Build a plan that fits your exact business structure',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 24),
            // Branches Control
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Branches',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${PRICE_BRANCH.toStringAsFixed(2)} per branch (Includes 1 Admin)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _updateCalc('branch', -1),
                        icon: const Icon(FontAwesomeIcons.minus),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$_branches',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => _updateCalc('branch', 1),
                        icon: const Icon(FontAwesomeIcons.plus),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Staff Control
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Staff Members',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${PRICE_STAFF.toStringAsFixed(2)} per additional staff member',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _updateCalc('staff', -1),
                        icon: const Icon(FontAwesomeIcons.minus),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$_staff',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => _updateCalc('staff', 1),
                        icon: const Icon(FontAwesomeIcons.plus),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Est. Monthly Cost',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Branches ($_branches × \$${PRICE_BRANCH.toStringAsFixed(2)})',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        '\$${branchTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Staff ($_staff × \$${PRICE_STAFF.toStringAsFixed(2)})',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        '\$${staffTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '\$${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6FB5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Custom plan upgrade coming soon!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Upgrade to Custom',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationModal() {
    if (_selectedPackage == null) return const SizedBox.shrink();
    
    final gradientColors = _getGradientColors(_selectedPackage!.color);

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          FontAwesomeIcons.exchangeAlt,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Subscription',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Confirm your plan change',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'You are about to change your subscription to:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gradientColors),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                _selectedPackage!.icon != null
                                    ? _getIconFromString(_selectedPackage!.icon!)
                                    : FontAwesomeIcons.box,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedPackage!.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  _selectedPackage!.priceLabel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: gradientColors[0],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildPlanDetailRow('Branches', _selectedPackage!.branches == -1 ? 'Unlimited' : '${_selectedPackage!.branches}'),
                          const SizedBox(height: 8),
                          _buildPlanDetailRow('Staff', _selectedPackage!.staff == -1 ? 'Unlimited' : '${_selectedPackage!.staff}'),
                          const SizedBox(height: 8),
                          _buildPlanDetailRow('Features', '${_selectedPackage!.features.length} included'),
                        ],
                      ),
                    ),
                    if (_currentPlan != null && _currentPlan!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              FontAwesomeIcons.infoCircle,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Current plan: $_currentPlan${_currentPrice != null && _currentPrice!.isNotEmpty ? " ($_currentPrice)" : ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _updating
                                ? null
                                : () {
                                    setState(() {
                                      _showConfirmModal = false;
                                      _selectedPackage = null;
                                    });
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _updating ? null : _confirmPlanChange,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gradientColors[0],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _updating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Confirm Change',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  IconData _getIconFromString(String iconString) {
    // Map common FontAwesome icon strings to IconData
    final iconMap = {
      'fa-box': FontAwesomeIcons.box,
      'fas fa-box': FontAwesomeIcons.box,
      'fa-crown': FontAwesomeIcons.crown,
      'fas fa-crown': FontAwesomeIcons.crown,
      'fa-star': FontAwesomeIcons.star,
      'fas fa-star': FontAwesomeIcons.star,
      'fa-rocket': FontAwesomeIcons.rocket,
      'fas fa-rocket': FontAwesomeIcons.rocket,
      'fa-gem': FontAwesomeIcons.gem,
      'fas fa-gem': FontAwesomeIcons.gem,
      'fa-building': FontAwesomeIcons.building,
      'fas fa-building': FontAwesomeIcons.building,
      'fa-briefcase': FontAwesomeIcons.briefcase,
      'fas fa-briefcase': FontAwesomeIcons.briefcase,
      'fa-chart-line': FontAwesomeIcons.chartLine,
      'fas fa-chart-line': FontAwesomeIcons.chartLine,
      'fa-users': FontAwesomeIcons.users,
      'fas fa-users': FontAwesomeIcons.users,
    };
    
    // Try exact match first
    if (iconMap.containsKey(iconString)) {
      return iconMap[iconString]!;
    }
    
    // Remove 'fa-' or 'fas fa-' prefix and try again
    final cleanIcon = iconString
        .replaceAll('fas fa-', '')
        .replaceAll('fa-', '')
        .trim();
    
    if (cleanIcon.isNotEmpty) {
      final key = 'fa-$cleanIcon';
      if (iconMap.containsKey(key)) {
        return iconMap[key]!;
      }
    }
    
    // Default fallback
    return FontAwesomeIcons.box;
  }
}
