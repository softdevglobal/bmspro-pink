import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

class ACSULoyaltyPage extends StatefulWidget {
  const ACSULoyaltyPage({super.key});

  @override
  State<ACSULoyaltyPage> createState() => _ACSULoyaltyPageState();
}

class _ACSULoyaltyPageState extends State<ACSULoyaltyPage> {
  bool _loading = true;
  String? _ownerUid;
  
  // ACSU Settings
  int _balance = 0;
  int _conversionRate = 10;
  String _currency = 'AUD';
  bool _isEnabled = true;
  
  // Transactions
  List<Map<String, dynamic>> _transactions = [];
  
  // Controllers
  final _topupController = TextEditingController();
  final _conversionRateController = TextEditingController();
  
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _topupController.dispose();
    _conversionRateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // Get user document to find ownerUid
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => _loading = false);
        return;
      }

      final userData = userDoc.data()!;
      final role = (userData['role'] ?? '').toString();
      
      // Only salon_owner can access this page
      if (role != 'salon_owner') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access denied. Salon owner only.')),
          );
        }
        return;
      }

      _ownerUid = user.uid;
      
      await _loadACSUSettings();
      await _loadTransactions();
      
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading ACSU data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadACSUSettings() async {
    if (_ownerUid == null) return;
    
    try {
      final acsuDoc = await FirebaseFirestore.instance
          .collection('owners')
          .doc(_ownerUid)
          .collection('acsu')
          .doc('settings')
          .get();
      
      if (acsuDoc.exists) {
        final data = acsuDoc.data()!;
        setState(() {
          _balance = (data['balance'] ?? 0) is int 
              ? data['balance'] 
              : (data['balance'] as num?)?.toInt() ?? 0;
          _conversionRate = (data['conversionRate'] ?? 10) is int 
              ? data['conversionRate'] 
              : (data['conversionRate'] as num?)?.toInt() ?? 10;
          _currency = data['currency'] ?? 'AUD';
          _isEnabled = data['isEnabled'] != false;
        });
        _conversionRateController.text = _conversionRate.toString();
      } else {
        // Create default settings
        await FirebaseFirestore.instance
            .collection('owners')
            .doc(_ownerUid)
            .collection('acsu')
            .doc('settings')
            .set({
          'balance': 0,
          'conversionRate': 10,
          'currency': 'AUD',
          'isEnabled': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _conversionRateController.text = '10';
      }
    } catch (e) {
      debugPrint('Error loading ACSU settings: $e');
    }
  }

  Future<void> _loadTransactions() async {
    if (_ownerUid == null) return;
    
    try {
      final transactionsQuery = await FirebaseFirestore.instance
          .collection('owners')
          .doc(_ownerUid)
          .collection('acsu_transactions')
          .orderBy('date', descending: true)
          .limit(50)
          .get();
      
      setState(() {
        _transactions = transactionsQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  Future<void> _toggleACSU(bool enabled) async {
    if (_ownerUid == null) return;
    
    setState(() => _saving = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('owners')
          .doc(_ownerUid)
          .collection('acsu')
          .doc('settings')
          .set({
        'isEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      setState(() {
        _isEnabled = enabled;
        _saving = false;
      });
      
      _showSnackBar(enabled ? 'ACSU Loyalty Enabled' : 'ACSU Loyalty Disabled');
    } catch (e) {
      debugPrint('Error toggling ACSU: $e');
      setState(() => _saving = false);
      _showSnackBar('Failed to update settings');
    }
  }

  Future<void> _updateConversionRate() async {
    if (_ownerUid == null) return;
    
    final rate = int.tryParse(_conversionRateController.text);
    if (rate == null || rate <= 0) {
      _showSnackBar('Please enter a valid conversion rate');
      return;
    }
    
    setState(() => _saving = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('owners')
          .doc(_ownerUid)
          .collection('acsu')
          .doc('settings')
          .set({
        'conversionRate': rate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      setState(() {
        _conversionRate = rate;
        _saving = false;
      });
      
      _showSnackBar('Conversion rate updated');
    } catch (e) {
      debugPrint('Error updating conversion rate: $e');
      setState(() => _saving = false);
      _showSnackBar('Failed to update conversion rate');
    }
  }

  Future<void> _topUpPoints() async {
    if (_ownerUid == null) return;
    
    final amount = int.tryParse(_topupController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount');
      return;
    }
    
    setState(() => _saving = true);
    
    try {
      final newBalance = _balance + amount;
      
      // Update balance
      await FirebaseFirestore.instance
          .collection('owners')
          .doc(_ownerUid)
          .collection('acsu')
          .doc('settings')
          .set({
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Create transaction record
      await FirebaseFirestore.instance
          .collection('owners')
          .doc(_ownerUid)
          .collection('acsu_transactions')
          .doc('topup_${DateTime.now().millisecondsSinceEpoch}')
          .set({
        'email': 'admin',
        'name': 'Admin Top Up',
        'staff': 'System',
        'branch': 'N/A',
        'service': 'Top Up',
        'value': 0,
        'points': amount,
        'date': DateTime.now().toIso8601String(),
        'ownerUid': _ownerUid,
        'type': 'topup',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _balance = newBalance;
        _saving = false;
      });
      
      _topupController.clear();
      Navigator.pop(context); // Close bottom sheet
      _showSnackBar('Added $amount points successfully!');
      
      // Reload transactions
      _loadTransactions();
    } catch (e) {
      debugPrint('Error topping up points: $e');
      setState(() => _saving = false);
      _showSnackBar('Failed to top up points');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showTopUpSheet() {
    _topupController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Top Up Points',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Current Balance
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Balance',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_balance.toString()} pts',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Amount Input
              TextField(
                controller: _topupController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '1000',
                  hintStyle: TextStyle(
                    color: AppColors.muted.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
              const SizedBox(height: 24),
              // Top Up Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _topUpPoints,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm Top Up',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
          'ACSU Loyalty',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(FontAwesomeIcons.gem, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '$_balance Points',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await _loadACSUSettings();
                await _loadTransactions();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ACSU Integration Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACSU Integration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Enable loyalty points for customers',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isEnabled,
                            onChanged: _saving ? null : _toggleACSU,
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Points Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E293B).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACSU Points Balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.7),
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _balance.toString(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _showTopUpSheet,
                                  icon: const Icon(FontAwesomeIcons.circlePlus, size: 16),
                                  label: const Text('Top Up Points'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Icon(
                              FontAwesomeIcons.gem,
                              size: 100,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Conversion Rate Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dollar to ACSU Point Value',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Points per \$1.00',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _conversionRateController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      enabled: _isEnabled && !_saving,
                                      decoration: InputDecoration(
                                        hintText: '10',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: AppColors.border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isEnabled && !_saving ? _updateConversionRate : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Update',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  FontAwesomeIcons.circleInfo,
                                  size: 14,
                                  color: Color(0xFF3B82F6),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'If set to $_conversionRate, a \$50 booking awards ${50 * _conversionRate} points.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Transactions Section
                    const Text(
                      'Transaction Records',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_transactions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              FontAwesomeIcons.receipt,
                              size: 48,
                              color: AppColors.muted.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No transactions yet',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final t = _transactions[index];
                          final points = (t['points'] ?? 0) is int 
                              ? t['points'] 
                              : (t['points'] as num?)?.toInt() ?? 0;
                          final name = t['name'] ?? 'Unknown';
                          final service = t['service'] ?? 'N/A';
                          final branch = t['branch'] ?? 'N/A';
                          final dateStr = t['date'] ?? '';
                          
                          DateTime? date;
                          try {
                            date = DateTime.parse(dateStr);
                          } catch (e) {
                            date = null;
                          }
                          
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      FontAwesomeIcons.gem,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$service • $branch',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      if (date != null)
                                        Text(
                                          DateFormat('MMM d, yyyy h:mm a').format(date),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '+$points',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
