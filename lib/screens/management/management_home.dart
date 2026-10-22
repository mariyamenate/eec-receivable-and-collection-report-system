import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../shared/report_history_screen.dart';
import 'incoming_reports_screen.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/account_settings_sheet.dart';
import '../shared/messages_screen.dart';
import '../shared/notifications_screen.dart';


class ManagementHome extends StatelessWidget {
  const ManagementHome({super.key});
  static const Color _primary = Color(0xFF0D7377);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final name = auth.currentUser?.name ?? 'Management';

    return AppShell(
      role: 'management',
      activeRoute: 'home',
      title: 'Management — $name',
      userName: name,
      onLogout: () => auth.logout(),
      onSelect: (route) {
        switch (route) {
          case 'home':
          // Already here — no-op.
            break;
          case 'reports_review':
            Get.to(() => const ManagementIncomingScreen());
            break;
          case 'report_history':
            Get.to(() => const ReportHistoryScreen());
            break;
          case 'messages':
            Get.to(() => const MessagesScreen());
            break;
          case 'notifications':
            Get.to(() => const NotificationsScreen());
            break;
        }
      },
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('WORKFLOW'),
          _card(Icons.rate_review, 'Reports for Review',
              'Approve/reject (with remark) → send to Top Management',
                  () => Get.to(() => const ManagementIncomingScreen())),
          _section('REPORTS'),
          _card(Icons.folder_open, 'Report History',
              'By Business Unit & Sector — template + summary files',
                  () => Get.to(() => const ReportHistoryScreen())),
          _section('COMMUNICATION'),
          _card(
            Icons.chat,
            'Messages',
            'Chat with team & video meetings',
                () => Get.to(() => const MessagesScreen()),
          ),
          _card(
            Icons.notifications,
            'Notifications',
            'Alerts & updates',
                () => Get.to(() => const NotificationsScreen()),
          ),
          _section('ACCOUNT'),
          _card(Icons.settings, 'Account Settings',
              'Change your username & password',
                  () => showAccountSettingsSheet(context)),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4, top: 8),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8)),
  );

  Widget _card(IconData i, String t, String s, VoidCallback o) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: _primary.withValues(alpha: 0.12), child: Icon(i, color: _primary)),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(s),
      trailing: const Icon(Icons.chevron_right),
      onTap: o,
    ),
  );
}