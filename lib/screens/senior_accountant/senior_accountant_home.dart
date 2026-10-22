import 'package:eec_receivable_and_collection_report_system/screens/shared/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/lang_controller.dart';
import '../shared/report_history_screen.dart';
import 'incoming_collections_screen.dart';
import 'my_templates_screen.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/account_settings_sheet.dart';
import '../shared/messages_screen.dart';
import '../shared/notifications_screen.dart';


class SeniorAccountantHome extends StatelessWidget {
  const SeniorAccountantHome({super.key});
  static const Color _primary = Color(0xFF0D7377);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final lang = Get.find<LangController>();
    final name = auth.currentUser?.name ?? 'senior_accountant'.tr;

    return AppShell(
      role: 'senior_accountant',
      activeRoute: 'home',
      title: '${'senior_accountant'.tr} — $name',
      userName: name,
      onLogout: () => auth.logout(),
      onSelect: (route) {
        switch (route) {
          case 'home':
            break;
          case 'incoming_collections':
            Get.to(() => const IncomingCollectionsScreen());
            break;
          case 'my_templates':
            Get.to(() => const MyTemplatesScreen());
            break;
          case 'report_history':
            Get.to(() => const ReportHistoryScreen());
            break;
          case 'messages':
            Get.to(() => const MessagesScreen());
            break;
        }
      },
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('section_workflow'.tr),
          _card(Icons.inbox, 'incoming_collections'.tr,
              'incoming_collections_desc'.tr,
                  () => Get.to(() => const IncomingCollectionsScreen())),
          _card(Icons.history, 'my_templates'.tr,
              'my_templates_desc'.tr,
                  () => Get.to(() => const MyTemplatesScreen())),
          _section('section_reports'.tr),
          _card(Icons.folder_open, 'report_history'.tr,
              'report_history_template_desc'.tr,
                  () => Get.to(() => const ReportHistoryScreen())),
          _section('section_communication'.tr),
          _card(
            Icons.chat,
            'messages'.tr,
            'messages_meetings_desc'.tr,
                () => Get.to(() => const MessagesScreen()),
          ),
          _section('section_settings'.tr),
          Obx(() => _card(
              Icons.language,
              'language'.tr,
              lang.isAmharic ? 'amharic'.tr : 'english'.tr,
                  () => lang.toggle())),
          _section('section_account'.tr),
          _card(Icons.settings, 'account_settings'.tr,
              'account_settings_desc'.tr,
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