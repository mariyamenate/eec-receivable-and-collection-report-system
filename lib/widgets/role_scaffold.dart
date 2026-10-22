import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/lang_controller.dart';


class RoleScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final int? currentIndex;
  final ValueChanged<int>? onNavTap;
  final List<BottomNavigationBarItem>? bottomItems;

  const RoleScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.currentIndex,
    this.onNavTap,
    this.bottomItems,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final lang = Get.find<LangController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [

          Obx(() => TextButton(
                onPressed: lang.toggle,
                child: Text(
                  lang.isAmharic ? 'EN' : 'አማ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),
          ...?actions,
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await Get.dialog<bool>(
                AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Get.back(result: true), child: const Text('Logout')),
                  ],
                ),
              );
              if (confirm == true) {
                await auth.logout();
              }
            },
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: (bottomItems != null && currentIndex != null && onNavTap != null)
          ? BottomNavigationBar(
              currentIndex: currentIndex!,
              onTap: onNavTap,
              type: BottomNavigationBarType.fixed,
              items: bottomItems!,
            )
          : null,
    );
  }
}
