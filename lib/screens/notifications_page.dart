import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class _NotifTheme {
  static const Color primary = Color(0xFFFF2D8F);
  static const Color accent = Color(0xFFFF6FB5);
  static const Color background = Color(0xFFFFF5FA);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF1A1A1A);
  static const Color muted = Color(0xFF9E9E9E);
  static const Color unreadBg = Color(0xFFFFF1F7);
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final String type; // 'task', 'system'
  bool isRead;
  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.type,
    this.isRead = false,
  });
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  String _currentFilter = 'all'; // 'all', 'task', 'system'

  late List<NotificationItem> _notifications;
  late AnimationController _bellBadgeController;

  @override
  void initState() {
    super.initState();
    _notifications = [
      NotificationItem(
        id: '1',
        title: 'New Task Assigned',
        description: 'Massage (60min) for Sarah at 10AM',
        time: '12 minutes ago',
        icon: FontAwesomeIcons.listCheck,
        type: 'task',
        isRead: false,
      ),
      NotificationItem(
        id: '2',
        title: 'Room Change',
        description: 'Room updated from R1 → R3 for 12PM Facial',
        time: '1 hour ago',
        icon: FontAwesomeIcons.doorOpen,
        type: 'task',
        isRead: false,
      ),
      NotificationItem(
        id: '3',
        title: 'Timesheet Approved',
        description: 'Your hours for 14 March have been approved.',
        time: 'Yesterday at 7:45 PM',
        icon: FontAwesomeIcons.circleCheck,
        type: 'system',
        isRead: true,
      ),
      NotificationItem(
        id: '4',
        title: 'Customer Feedback',
        description: 'Maria rated you 5 stars for your service 💖',
        time: '2 days ago',
        icon: FontAwesomeIcons.star,
        type: 'system',
        isRead: true,
      ),
      NotificationItem(
        id: '5',
        title: 'Schedule Update',
        description: 'Your shift for tomorrow has been confirmed',
        time: '3 days ago',
        icon: FontAwesomeIcons.calendar,
        type: 'system',
        isRead: true,
      ),
      NotificationItem(
        id: '6',
        title: 'Payment Processed',
        description: 'Weekly salary has been deposited to your account',
        time: '1 week ago',
        icon: FontAwesomeIcons.dollarSign,
        type: 'system',
        isRead: true,
      ),
    ];

    _bellBadgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bellBadgeController.dispose();
    super.dispose();
  }

  List<NotificationItem> get _filteredNotifications {
    if (_currentFilter == 'all') return _notifications;
    return _notifications.where((n) => n.type == _currentFilter).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markAsRead(NotificationItem item) {
    if (!item.isRead) {
      setState(() {
        item.isRead = true;
      });
    }
  }

  void _clearAll() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _NotifTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTabs(),
                  const SizedBox(height: 24),
                  _buildNotificationList(),
                  const SizedBox(height: 32),
                  _buildClearButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(color: _NotifTheme.background),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              FontAwesomeIcons.chevronLeft,
              size: 18,
              color: _NotifTheme.text,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Notifications',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _NotifTheme.text),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _buildTab('All', 'all'),
        const SizedBox(width: 24),
        _buildTab('Tasks', 'task'),
        const SizedBox(width: 24),
        _buildTab('System', 'system'),
      ],
    );
  }

  Widget _buildTab(String label, String filterId) {
    final bool isActive = _currentFilter == filterId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = filterId;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? _NotifTheme.primary : _NotifTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            width: isActive ? 20 : 0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_NotifTheme.primary, _NotifTheme.accent]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    final items = _filteredNotifications;
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _NotificationCard(
                item: item,
                onTap: () => _markAsRead(item),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildClearButton() {
    return Center(
      child: TextButton(
        onPressed: _clearAll,
        style: TextButton.styleFrom(
          foregroundColor: _NotifTheme.primary,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        child: const Text('Clear All'),
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRead = widget.item.isRead;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRead ? _NotifTheme.card : _NotifTheme.unreadBg,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isRead ? Colors.transparent : _NotifTheme.primary,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _NotifTheme.primary.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 16),
              child: isRead
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.grey.shade300, width: 2),
                        shape: BoxShape.circle,
                      ),
                    )
                  : ScaleTransition(
                      scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                        CurvedAnimation(
                            parent: _pulseController, curve: Curves.easeInOut),
                      ),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _NotifTheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _NotifTheme.primary.withOpacity(0.5),
                              blurRadius: 8,
                            )
                          ],
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                      color: isRead ? _NotifTheme.muted : _NotifTheme.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.description,
                    style:
                        const TextStyle(fontSize: 14, color: _NotifTheme.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.time,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isRead ? _NotifTheme.muted : _NotifTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                widget.item.icon,
                size: 18,
                color: isRead ? _NotifTheme.muted : _NotifTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


