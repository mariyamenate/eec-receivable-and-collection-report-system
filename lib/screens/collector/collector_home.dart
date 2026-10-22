import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../shared/report_history_screen.dart';
import 'collect_data_screen.dart';
import 'my_collections_screen.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/account_settings_sheet.dart';
import '../../widgets/home_dashboard.dart';
import '../shared/messages_screen.dart';
import '../shared/notifications_screen.dart';

class CollectorHome extends StatelessWidget {
  const CollectorHome({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final dash =
    Get.put(HomeDashboardController(role: 'collector'), tag: 'collector');
    final name = auth.currentUser?.name ?? 'Collector';

    void openMyCollections() =>
        Get.to(() => const MyCollectionsScreen())?.then((_) => dash.load());

    return AppShell(
      role: 'collector',
      activeRoute: 'home',
      title: 'Collector — $name',
      userName: name,
      onLogout: () => auth.logout(),
      onSelect: (route) {
        switch (route) {
          case 'home':
            break;
          case 'collect_data':
            Get.to(() => const CollectDataScreen())?.then((_) => dash.load());
            break;
          case 'my_collections':
            openMyCollections();
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
          case 'account_settings':
            showAccountSettingsSheet(context);
            break;
        }
      },
      body: RefreshIndicator(
        onRefresh: dash.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            HomeDashboard(role: 'collector', onStatusTap: openMyCollections),
          ],
        ),
      ),
    );
  }
}