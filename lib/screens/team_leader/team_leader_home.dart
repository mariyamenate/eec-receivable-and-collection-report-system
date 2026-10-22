import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../shared/report_history_screen.dart';
import 'incoming_reports_screen.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/home_dashboard.dart';
import '../../widgets/account_settings_sheet.dart';
import '../shared/messages_screen.dart';
import '../shared/notifications_screen.dart';

class TeamLeaderHome extends StatelessWidget {
  const TeamLeaderHome({super.key});
  static const Color _primary = Color(0xFF0D7377);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final name = auth.currentUser?.name ?? 'Team Leader';

    return AppShell(
      role: 'team_leader',
      activeRoute: 'home',
      title: '${'team_leader'.tr} — $name',
      userName: name,
      onLogout: () => auth.logout(),
      onSelect: (route) {
        switch (route) {
          case 'home':
            break;
          case 'reports_review':
          case 'generate_summary':
            Get.to(() => const IncomingReportsScreen());
            break;
          case 'assign_collectors':
            Get.snackbar('Coming soon', 'Assign Collectors');
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
          _card(
            Icons.rate_review,
            'Reports for Review'.tr,
            'Approve/reject Receivables Template from Senior Accountant'.tr,
                () => Get.to(() => const IncomingReportsScreen()),
          ),
          _card(
            Icons.summarize,
            'Generate Summary & Send'.tr,
            'Upload 4_Sectors_..._Collection_summary_Report.xlsx → Mgmt + Finance'.tr,
                () => Get.to(() => const IncomingReportsScreen()),
          ),
          _card(
            Icons.people_outline,
            'Assign Collectors'.tr,
            'Assign collectors to your team'.tr,
                () => Get.snackbar('Coming soon', 'Assign Collectors'),
          ),
          _section('REPORTS'),
          _card(
            Icons.folder_open,
            'Report History'.tr,
            'By Business Unit & Sector'.tr,
                () => Get.to(() => const ReportHistoryScreen()),
          ),
          _section('COMMUNICATION'),
          _card(
            Icons.chat,
            'Messages'.tr,
            'Team chat'.tr,
                () => Get.to(() => const MessagesScreen()), // ✅ Fixed
          ),
          _card(
            Icons.notifications,
            'Notifications'.tr,
            'Alerts & updates'.tr,
                () => Get.to(() => const NotificationsScreen()), // ✅ Added
          ),
          _section('ACCOUNT'),
          _card(
            Icons.settings,
            'Account Settings'.tr,
            'Change your username & password'.tr,
                () => showAccountSettingsSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4, top: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _card(IconData i, String t, String s, VoidCallback o) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: _primary.withValues(alpha: 0.12),
        child: Icon(i, color: _primary),
      ),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(s),
      trailing: const Icon(Icons.chevron_right),
      onTap: o,
    ),
  );
}