import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Fixed paths for lib/screens/shared/ folder
import '../../models/app_notification.dart';
import '../../services/notifications_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  // Toggle: true = local demo data, false = real API
  static const bool useLocalFallback = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = useLocalFallback
          ? await NotificationService.getNotificationsLocal()
          : await NotificationService.getNotifications();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead || n.id == null) return;
    try {
      if (useLocalFallback) {
        await NotificationService.markAsReadLocal(n.id!);
      } else {
        await NotificationService.markAsRead(n.id!);
      }
      setState(() {
        final idx = _items.indexWhere((x) => x.id == n.id);
        if (idx >= 0) _items[idx] = _items[idx].copyWith(isRead: true);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _markAllRead() async {
    try {
      if (useLocalFallback) {
        await NotificationService.markAllAsReadLocal();
      } else {
        await NotificationService.markAllAsRead();
      }
      setState(() {
        _items = _items.map((n) => n.copyWith(isRead: true)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'meeting':
        return Icons.videocam;
      case 'project':
        return Icons.folder;
      case 'collection':
        return Icons.assignment_turned_in;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'meeting':
        return const Color(0xFF1A237E);
      case 'project':
        return Colors.teal;
      case 'collection':
        return Colors.orange.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF0D7377),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      )
          : _items.isEmpty
          ? const Center(
        child: Text('No notifications yet', style: TextStyle(color: Colors.grey)),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final n = _items[i];
            final color = _colorForType(n.type);
            return ListTile(
              onTap: () => _markRead(n),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(_iconForType(n.type), color: color, size: 22),
              ),
              title: Text(
                n.title,
                style: TextStyle(
                  fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy • HH:mm').format(n.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              trailing: n.isRead
                  ? null
                  : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D7377),
                  shape: BoxShape.circle,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            );
          },
        ),
      ),
    );
  }
}
