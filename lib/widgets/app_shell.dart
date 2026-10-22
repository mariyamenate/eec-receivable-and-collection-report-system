import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/lang_controller.dart';
import 'account_settings_sheet.dart';
import 'role_sidebar.dart';

class AppShell extends StatelessWidget {
  final String role;
  final String activeRoute;
  final String title;
  final Widget body;
  final ValueChanged<String> onSelect;
  final String? userName;
  final VoidCallback? onLogout;
  final VoidCallback? onToggleLanguage;
  final String? languageLabel;

  static const Color _primary = Color(0xFF0D7377);
  static const double wideBreakpoint = 900;

  const AppShell({
    super.key,
    required this.role,
    required this.activeRoute,
    required this.title,
    required this.body,
    required this.onSelect,
    this.userName,
    this.onLogout,
    this.onToggleLanguage,
    this.languageLabel,
  });

  /// Language button shown at the top for every role.
  Widget _languageButton({required bool onDark}) {
    final fg = onDark ? Colors.white : _primary;

    if (!Get.isRegistered<LangController>()) {
      if (onToggleLanguage == null) return const SizedBox.shrink();
      return TextButton.icon(
        onPressed: onToggleLanguage,
        icon: Icon(Icons.language, size: 18, color: fg),
        label: Text(languageLabel ?? 'Language', style: TextStyle(color: fg)),
      );
    }

    final lang = Get.find<LangController>();
    return Obx(() => TextButton.icon(
      onPressed: onToggleLanguage ?? () => lang.toggle(),
      icon: Icon(Icons.language, size: 18, color: fg),
      label: Text(
        languageLabel ?? (lang.isAmharic ? 'English' : 'አማርኛ'),
        style: TextStyle(color: fg),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= wideBreakpoint;

    // Language lives in the top bar, so the sidebar footer does not get
    // onToggleLanguage (this avoids two language buttons).
    final sidebar = RoleSidebar(
      role: role,
      activeRoute: activeRoute,
      onSelect: (route) {
        if (!isWide && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (route == 'account_settings') {
          showAccountSettingsSheet(context);
          return;
        }
        onSelect(route);
      },
      userName: userName,
      onLogout: onLogout,
    );

    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
        title: Text(title),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [_languageButton(onDark: true)],
      ),
      drawer: isWide ? null : Drawer(child: sidebar),
      body: isWide
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sidebar,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20, right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      _languageButton(onDark: false),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      )
          : body,
    );
  }
}