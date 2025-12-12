import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_profile_page.dart';

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
  static const green = Color(0xFF10B981);
  static const yellow = Color(0xFFFFD700);
  static const red = Color(0xFFEF4444);
  static const chipBg = Color(0xFFF3F4F6);
}

// --- 2. Client Model ---
class Client {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String type; // 'vip', 'new', 'risk', 'active'
  final String avatarUrl;
  final int visits;
  final DateTime? lastVisit;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.type,
    required this.avatarUrl,
    required this.visits,
    required this.lastVisit,
  });
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> with TickerProviderStateMixin {
  // Live data from Firestore
  List<Client> _allClients = [];

  // State
  String _currentFilter = 'all';
  String _searchQuery = '';
  List<Client> _filteredClients = [];

  // Animation Controllers
  final List<AnimationController> _staggerControllers = [];

  @override
  void initState() {
    super.initState();
    _filteredClients = [];
    _listenToClients();
  }

  void _listenToClients() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ownerUid = user.uid;

    FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .listen((snap) {
      final Map<String, Map<String, dynamic>> map = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['client'] ?? '').toString().trim();
        final email = (data['clientEmail'] ?? '').toString().trim();
        final phone = (data['clientPhone'] ?? '').toString().trim();

        if (name.isEmpty && email.isEmpty && phone.isEmpty) continue;

        final keySource = data['customerUid'] ??
            (email.isNotEmpty
                ? email
                : (phone.isNotEmpty ? phone : name));
        final key = keySource.toString().toLowerCase();

        final dateStr = (data['date'] ?? '').toString();
        DateTime? bookingDate;
        try {
          if (dateStr.isNotEmpty) {
            bookingDate = DateTime.parse(dateStr);
          }
        } catch (_) {}

        final existing = map[key];
        if (existing == null) {
          map[key] = {
            'name': name.isNotEmpty ? name : (email.isNotEmpty ? email : phone),
            'email': email,
            'phone': phone,
            'visits': 1,
            'lastVisit': bookingDate,
          };
        } else {
          existing['visits'] = (existing['visits'] as int) + 1;
          final currentLast = existing['lastVisit'] as DateTime?;
          if (bookingDate != null &&
              (currentLast == null || bookingDate.isAfter(currentLast))) {
            existing['lastVisit'] = bookingDate;
          }
        }
      }

      final now = DateTime.now();
      final clients = map.entries.map((entry) {
        final data = entry.value;
        final visits = (data['visits'] as int?) ?? 0;
        final DateTime? lastVisit = data['lastVisit'] as DateTime?;

        String type = 'active';
        if (visits >= 8) {
          type = 'vip';
        } else if (visits <= 1) {
          type = 'new';
        }
        if (lastVisit != null &&
            now.difference(lastVisit).inDays > 120 &&
            visits > 0) {
          type = 'risk';
        }

        final name = (data['name'] as String?) ?? 'Customer';
        final email = (data['email'] as String?) ?? '';
        final phone = (data['phone'] as String?) ?? '';

        final avatarUrl =
            'https://ui-avatars.com/api/?background=FF2D8F&color=fff&name=${Uri.encodeComponent(name)}';

        return Client(
          id: entry.key,
          name: name,
          phone: phone,
          email: email,
          type: type,
          avatarUrl: avatarUrl,
          visits: visits,
          lastVisit: lastVisit,
        );
      }).toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

      if (!mounted) return;

      setState(() {
        _allClients = clients;

        // Recreate stagger controllers for current list
        for (final c in _staggerControllers) {
          c.dispose();
        }
        _staggerControllers.clear();
        for (int i = 0; i < clients.length; i++) {
          _staggerControllers.add(
            AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 600),
            ),
          );
        }
      });

      _filterClients();
    }, onError: (e) {
      debugPrint('Error loading clients: $e');
    });
  }

  void _startAnimations() {
    for (int i = 0; i < _filteredClients.length; i++) {
      if (i < _staggerControllers.length) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted) _staggerControllers[i].forward();
        });
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _staggerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- Logic ---
  void _filterClients() {
    final filtered = _allClients.where((client) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          client.name.toLowerCase().contains(query) ||
          client.phone.contains(_searchQuery) ||
          client.email.toLowerCase().contains(query);
      final matchesFilter =
          _currentFilter == 'all' || client.type == _currentFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    // Rebuild animations for filtered list
    for (final c in _staggerControllers) {
      c.dispose();
    }
    _staggerControllers.clear();
    for (int i = 0; i < filtered.length; i++) {
      _staggerControllers.add(
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
        ),
      );
    }

    setState(() {
      _filteredClients = filtered;
    });
    _startAnimations();
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _filterClients();
  }

  void _onFilterChanged(String filter) {
    _currentFilter = filter;
    _filterClients();
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: _buildHeader(),
          ),
          _buildSearchAndFilter(),
          Expanded(
            child: Stack(
              children: [
                _buildClientList(),
                _buildAlphabetIndex(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
              Text('156 Active Clients', style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(
          width: 24,
          child: Icon(FontAwesomeIcons.userPlus, color: AppColors.primary, size: 18),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name, phone, or email...',
                hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                prefixIcon: Icon(FontAwesomeIcons.magnifyingGlass, size: 16, color: AppColors.muted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All Clients', 'all'),
                const SizedBox(width: 8),
                _filterChip('VIP', 'vip'),
                const SizedBox(width: 8),
                _filterChip('New', 'new'),
                const SizedBox(width: 8),
                _filterChip('At Risk', 'risk'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String filterKey) {
    final isActive = _currentFilter == filterKey;
    return GestureDetector(
      onTap: () => _onFilterChanged(filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
          color: isActive ? null : AppColors.chipBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildClientList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _filteredClients.length,
      itemBuilder: (context, index) {
        if (index >= _staggerControllers.length) return const SizedBox();
        return FadeTransition(
          opacity: _staggerControllers[index],
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
              CurvedAnimation(parent: _staggerControllers[index], curve: Curves.easeOut),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ClientCard(client: _filteredClients[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlphabetIndex() {
    final letters = ['A', 'B', 'C', 'D', 'E', 'G', 'H', 'S'];
    return Positioned(
      right: 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: letters
                .map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(l, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold)),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

// --- 3. Client Card Component ---
class _ClientCard extends StatelessWidget {
  final Client client;
  const _ClientCard({required this.client});

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(client.name);
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClientProfilePage(client: client),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 16)),
                  Text(client.phone, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            _buildStatusBadge(client.type),
            const SizedBox(width: 8),
            const Icon(FontAwesomeIcons.chevronRight, size: 14, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String type) {
    Color text = Colors.white;
    String label = type.toUpperCase();
    Gradient gradient;
    switch (type) {
      case 'vip':
        gradient = const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]);
        text = AppColors.text;
        break;
      case 'new':
        gradient = const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]);
        break;
      case 'risk':
        gradient = const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]);
        label = "AT RISK";
        break;
      case 'active':
      default:
        gradient = const LinearGradient(colors: [AppColors.primary, AppColors.accent]);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

