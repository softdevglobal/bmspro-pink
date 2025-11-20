import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  static const green = Color(0xFF22C55E); // Matching Tailwind green-500
  static const yellow = Color(0xFFEAB308); // Matching Tailwind yellow-500
}

class AppointmentDetailsPage extends StatefulWidget {
  const AppointmentDetailsPage({super.key});

  @override
  State<AppointmentDetailsPage> createState() => _AppointmentDetailsPageState();
}

class _AppointmentDetailsPageState extends State<AppointmentDetailsPage> with TickerProviderStateMixin {
  // Checklist State
  final List<Map<String, dynamic>> _checklistItems = [
    {'title': 'Prepare room', 'checked': true, 'locked': true},
    {'title': 'Clean towels', 'checked': true, 'locked': true},
    {'title': 'Ask allergies', 'checked': false, 'locked': false},
    {'title': 'Confirm pressure preference', 'checked': false, 'locked': false},
  ];

  // Animation Controller for Fade-in effects
  late AnimationController _fadeController;
  final List<Animation<double>> _fadeAnimations = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Staggered animations for sections
    for (int i = 0; i < 6; i++) {
      final start = i * 0.1;
      final end = start + 0.4;
      _fadeAnimations.add(
        CurvedAnimation(
          parent: _fadeController,
          curve: Interval(start, end > 1.0 ? 1.0 : end, curve: Curves.easeOut),
        ),
      );
    }
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleChecklist(int index) {
    if (!_checklistItems[index]['locked']) {
      setState(() {
        _checklistItems[index]['checked'] = !_checklistItems[index]['checked'];
      });
    }
  }

  void _showPointsModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) => const PointsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildFadeWrapper(0, _buildCustomerCard()),
                    const SizedBox(height: 24),
                    _buildFadeWrapper(1, _buildAppointmentInfo()),
                    const SizedBox(height: 24),
                    _buildFadeWrapper(2, _buildPointsRewards()),
                    const SizedBox(height: 24),
                    _buildFadeWrapper(3, _buildChecklist()),
                    const SizedBox(height: 24),
                    _buildFadeWrapper(4, _buildNotes()),
                    const SizedBox(height: 24),
                    _buildFadeWrapper(5, _buildActionButtons()),
                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFadeWrapper(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_fadeAnimations[index]),
        child: child,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Row(
        children: const [
          _BackChevron(),
          Expanded(
            child: Center(
              child: Text(
                'Appointment Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ),
          ),
          SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
                  image: const DecorationImage(
                    image: NetworkImage('https://storage.googleapis.com/uxpilot-auth.appspot.com/avatars/avatar-1.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sarah K', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Text('Age: 32', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        SizedBox(width: 16),
                        Text('0403 555 111', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Text('Loyalty: Gold', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                        SizedBox(width: 8),
                        Icon(FontAwesomeIcons.solidStar, size: 14, color: AppColors.yellow),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ACSU:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                      child: const Text('✔ Member', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Sarah Kendall', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                const Text('sarahk@email.com', style: TextStyle(fontSize: 14, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Appointment Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 16),
          _infoRow(FontAwesomeIcons.spa, [Colors.purple.shade400, Colors.purple.shade600], 'Massage – 60 min', 'SERVICE'),
          const SizedBox(height: 16),
          _infoRow(FontAwesomeIcons.clock, [Colors.blue.shade400, Colors.blue.shade600], '10:00 AM → 11:00 AM', 'TIME'),
          const SizedBox(height: 16),
          _infoRow(FontAwesomeIcons.doorOpen, [Colors.green.shade400, Colors.green.shade600], 'Room R1', 'LOCATION'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, List<Color> colors, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 14)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }

  Widget _buildPointsRewards() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration().copyWith(border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Points & Rewards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text))),
          const SizedBox(height: 16),
          const Text('1,540 pts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const Text('Staff Point Balance', style: TextStyle(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 24),
          _GradientButton(
            text: 'Send ACSU Points to Customer',
            icon: FontAwesomeIcons.gift,
            onPressed: _showPointsModal,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Checklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 16),
          ...List.generate(_checklistItems.length, (index) {
            final item = _checklistItems[index];
            final isChecked = item['checked'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => _toggleChecklist(index),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isChecked ? AppColors.background : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24, height: 24,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isChecked ? AppColors.green : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isChecked ? const Center(child: Icon(FontAwesomeIcons.check, size: 12, color: Colors.white)) : null,
                      ),
                      Text(
                        item['title'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isChecked ? AppColors.text : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Customer Notes:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                SizedBox(height: 8),
                Text(
                  '"Prefers medium pressure. Allergic to coconut oil."',
                  style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _GradientButton(text: 'Start Appointment', icon: FontAwesomeIcons.play, onPressed: () {}),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(FontAwesomeIcons.phone, size: 16, color: AppColors.primary),
            label: const Text('Contact Customer', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 8))],
    );
  }
}

// Back chevron used in headers to match other pages
class _BackChevron extends StatelessWidget {
  const _BackChevron();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: const Icon(FontAwesomeIcons.chevronLeft, size: 18, color: AppColors.text),
    );
  }
}

// --- Helper: Gradient Button ---
class _GradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  const _GradientButton({required this.text, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper: Points Modal ---
class PointsModal extends StatefulWidget {
  const PointsModal({super.key});

  @override
  State<PointsModal> createState() => _PointsModalState();
}

class _PointsModalState extends State<PointsModal> {
  String _selectedOption = ''; // '20', '50', '100', 'custom'
  bool _isLoading = false;

  void _sendPoints() {
    if (_selectedOption.isEmpty) return;
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.green,
            content: Row(children: const [Icon(FontAwesomeIcons.check, color: Colors.white, size: 16), SizedBox(width: 8), Text("Points sent successfully!")]),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send Points to Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _optionBtn('20', 'Points'),
                _optionBtn('50', 'Points'),
                _optionBtn('100', 'Points'),
                _optionBtn('custom', 'Custom'),
              ],
            ),
            if (_selectedOption == 'custom')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional note...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Cancel', style: TextStyle(color: AppColors.muted)))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendPoints,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        alignment: Alignment.center,
                        height: 50,
                        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send Points', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _optionBtn(String value, String label) {
    final isSelected = _selectedOption == value;
    return InkWell(
      onTap: () => setState(() => _selectedOption = value),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value == 'custom' ? 'Custom' : value, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.text)),
            Text(value == 'custom' ? 'Amount' : label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}


