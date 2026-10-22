import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'access_codes_screen.dart';
import 'business_units_screen.dart';
import '../shared/report_history_screen.dart';
import '../../widgets/app_shell.dart';
import '../shared/messages_screen.dart';

class SuperadminHome extends StatelessWidget {
  const SuperadminHome({super.key});

  static const Color _primary = Color(0xFF0D7377);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final name = auth.currentUser?.name ?? 'super_admin'.tr;

    return AppShell(
      role: 'superadmin',
      activeRoute: 'home',
      title: '${'super_admin'.tr} — $name',
      userName: name,
      onLogout: () => auth.logout(),
      onSelect: (route) {
        switch (route) {
          case 'business_units':
            Get.to(() => const BusinessUnitsScreen());
            break;
          case 'access_codes':
            Get.to(() => const AccessCodesScreen());
            break;
          case 'user_management':
            Get.snackbar('coming_soon'.tr, 'user_management'.tr);
            break;
          case 'all_reports':
          case 'report_history':
            Get.to(() => const ReportHistoryScreen());
            break;
          case 'system_settings':
            Get.snackbar('coming_soon'.tr, 'system_settings'.tr);
            break;
          case 'messages':
            Get.to(() => const MessagesScreen());
            break;
        }
      },
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('org_section'.tr),
          _card(
            icon: Icons.business,
            title: 'business_units_projects'.tr,
            subtitle: 'business_units_projects_sub'.tr,
            onTap: () => Get.to(() => const BusinessUnitsScreen()),
          ),
          _card(
            icon: Icons.vpn_key,
            title: 'access_codes'.tr,
            subtitle: 'access_codes_sub'.tr,
            onTap: () => Get.to(() => const AccessCodesScreen()),
          ),
          _card(
            icon: Icons.people,
            title: 'user_management'.tr,
            subtitle: 'user_management_sub'.tr,
            onTap: () =>
                Get.snackbar('coming_soon'.tr, 'user_management'.tr),
          ),

          const SizedBox(height: 16),
          _section('reports_history_section'.tr),
          _card(
            icon: Icons.assessment,
            title: 'all_reports'.tr,
            subtitle: 'all_reports_sub'.tr,
            onTap: () => Get.to(() => const ReportHistoryScreen()),
          ),
          _card(
            icon: Icons.history,
            title: 'report_history'.tr,
            subtitle: 'report_history_sub'.tr,
            onTap: () => Get.to(() => const ReportHistoryScreen()),
          ),

          const SizedBox(height: 16),
          _section('system_section'.tr),
          _card(
            icon: Icons.settings,
            title: 'system_settings'.tr,
            subtitle: 'system_settings_sub'.tr,
            onTap: () =>
                Get.snackbar('coming_soon'.tr, 'system_settings'.tr),
          ),
          _card(
            icon: Icons.chat,
            title: 'messages'.tr,
            subtitle: 'messages_admin_sub'.tr,
            onTap: () => Get.to(() => const MessagesScreen()),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primary.withValues(alpha: 0.12),
          child: Icon(icon, color: _primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}