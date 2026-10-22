import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/lang_controller.dart';
import 'sidebar_labels.dart';

class SidebarItem {
  final String route;
  final String label;
  final IconData icon;

  const SidebarItem({
    required this.route,
    required this.label,
    required this.icon,
  });
}

class RoleMenus {
  static const Map<String, List<SidebarItem>> menus = {
    'collector': [
      SidebarItem(route: 'home', label: 'Home', icon: Icons.dashboard_outlined),
      SidebarItem(route: 'collect_data', label: 'Collect Data', icon: Icons.edit_note),
      SidebarItem(route: 'my_collections', label: 'My Collections', icon: Icons.fact_check_outlined),
      SidebarItem(route: 'report_history', label: 'Report History', icon: Icons.folder_open),
      SidebarItem(route: 'messages', label: 'Messages', icon: Icons.chat_outlined),
      SidebarItem(route: 'notifications', label: 'Notifications', icon: Icons.notifications_outlined),
    ],
    'senior_accountant': [
      SidebarItem(route: 'home', label: 'Home', icon: Icons.dashboard_outlined),
      SidebarItem(route: 'incoming_collections', label: 'Incoming Collections', icon: Icons.inbox_outlined),
      SidebarItem(route: 'build_template', label: 'Build Template', icon: Icons.table_chart_outlined),
      SidebarItem(route: 'my_templates', label: 'My Templates', icon: Icons.fact_check_outlined),
      SidebarItem(route: 'report_history', label: 'Report History', icon: Icons.folder_open),
      SidebarItem(route: 'messages', label: 'Messages', icon: Icons.chat_outlined),
    ],
    'team_leader': [
      SidebarItem(route: 'home', label: 'Home', icon: Icons.dashboard_outlined),
      SidebarItem(route: 'reports_review', label: 'Reports for Review', icon: Icons.rate_review_outlined),
      SidebarItem(route: 'generate_summary', label: 'Generate Summary & Send', icon: Icons.summarize_outlined),
      SidebarItem(route: 'assign_collectors', label: 'Assign Collectors', icon: Icons.people_outline),
      SidebarItem(route: 'report_history', label: 'Report History', icon: Icons.folder_open),
      SidebarItem(route: 'messages', label: 'Messages', icon: Icons.chat_outlined),
    ],
    'finance_director': [
      SidebarItem(route: 'home', label: 'Home', icon: Icons.dashboard_outlined),
      SidebarItem(route: 'view_reports', label: 'View Reports', icon: Icons.visibility_outlined),
      SidebarItem(route: 'report_history', label: 'Report History', icon: Icons.folder_open),
      SidebarItem(route: 'messages', label: 'Messages', icon: Icons.chat_outlined),
    ],
    'management': [
      SidebarItem(route: 'home', label: 'Home', icon: Icons.dashboard_outlined),
      SidebarItem(route: 'reports_review', label: 'Reports for Review', icon: Icons.rate_review_outlined),
      SidebarItem(route: 'report_history', label: 'Report History', icon: Icons.folder_open),
      SidebarItem(route: 'messages', label: 'Messages', icon: Icons.chat_outlined),
    ],
    'topmanagement': [
      SidebarItem(route: 'home', label: 'Home', icon: Icons.dashboard_outlined),
      SidebarItem(route: 'final_reports', label: 'Final Reports', icon: Icons.insights_outlined),
      SidebarItem(route: 'report_history', label: 'Report History', icon: Icons.folder_open),
      SidebarItem(route: 'messages', label: 'Messages', icon: Icons.chat_outlined),
    ],
    'superadmin': [
      SidebarItem(route: 'home', label: 'Home', icon: Icons.dashboard_outlined),
      SidebarItem(route: 'business_units', label: 'Business Units & Projects', icon: Icons.business),
      SidebarItem(route: 'access_codes', label: 'Access Codes', icon: Icons.vpn_key),
      SidebarItem(route: 'user_management', label: 'User Management', icon: Icons.people),
      SidebarItem(route: 'all_reports', label: 'All Reports', icon: Icons.assessment),
      SidebarItem(route: 'report_history', label: 'Report History', icon: Icons.folder_open),
      SidebarItem(route: 'system_settings', label: 'System Settings', icon: Icons.settings_outlined),
      SidebarItem(route: 'messages', label: 'Messages', icon: Icons.chat_outlined),
    ],
  };

  static const SidebarItem accountSettings = SidebarItem(
    route: 'account_settings',
    label: 'Account Settings',
    icon: Icons.manage_accounts_outlined,
  );

  /// Every role's menu, plus Account Settings as the last item.
  static List<SidebarItem> forRole(String role) {
    final items = menus[role] ?? const <SidebarItem>[];
    return [...items, accountSettings];
  }

  static String roleLabel(String role) {
    switch (role) {
      case 'collector':
        return 'Collector';
      case 'senior_accountant':
        return 'Senior Accountant';
      case 'team_leader':
        return 'Team Leader';
      case 'finance_director':
        return 'Finance Director';
      case 'management':
        return 'Management';
      case 'topmanagement':
        return 'Top Management';
      case 'superadmin':
        return 'Super Admin';
      default:
        return role;
    }
  }
}

class RoleSidebar extends StatefulWidget {
  final String role;
  final String activeRoute;
  final ValueChanged<String> onSelect;
  final String? userName;
  final VoidCallback? onLogout;
  final VoidCallback? onToggleLanguage;
  final String? languageLabel; // e.g. 'EN' / 'AM'
  final bool collapsible;

  const RoleSidebar({
    super.key,
    required this.role,
    required this.activeRoute,
    required this.onSelect,
    this.userName,
    this.onLogout,
    this.onToggleLanguage,
    this.languageLabel,
    this.collapsible = true,
  });

  @override
  State<RoleSidebar> createState() => _RoleSidebarState();
}

class _RoleSidebarState extends State<RoleSidebar> {
  static const Color _primary = Color(0xFF0D7377);
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    // Rebuild when the language changes. Obx needs at least one observable
    // read inside it, so only use it when LangController is registered.
    if (Get.isRegistered<LangController>()) {
      final lang = Get.find<LangController>();
      return Obx(() {
        lang.locale.value; // subscribe to language changes
        return _buildContent();
      });
    }
    return _buildContent();
  }

  Widget _buildContent() {
    final items = RoleMenus.forRole(widget.role);
    final width = _collapsed ? 72.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) => _navTile(item)).toList(),
            ),
          ),
          const Divider(height: 1),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: _primary,
            child: Icon(Icons.person, size: 18, color: Colors.white),
          ),
          if (!_collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.userName ??
                        SidebarLabels.t(RoleMenus.roleLabel(widget.role)),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    SidebarLabels.t(RoleMenus.roleLabel(widget.role)),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          if (widget.collapsible)
            IconButton(
              icon: Icon(_collapsed ? Icons.chevron_right : Icons.chevron_left, size: 18),
              splashRadius: 16,
              onPressed: () => setState(() => _collapsed = !_collapsed),
            ),
        ],
      ),
    );
  }

  Widget _navTile(SidebarItem item) {
    final selected = item.route == widget.activeRoute;
    final label = SidebarLabels.t(item.label);
    final tile = Material(
      color: selected ? _primary.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelect(item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: selected ? _primary : Colors.grey.shade700,
              ),
              if (!_collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? _primary : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return _collapsed ? Tooltip(message: label, child: tile) : tile;
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onToggleLanguage != null)
            TextButton.icon(
              onPressed: widget.onToggleLanguage,
              icon: const Icon(Icons.language, size: 18),
              label: _collapsed
                  ? const SizedBox.shrink()
                  : Text(widget.languageLabel ?? 'Language'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                alignment: Alignment.centerLeft,
              ),
            ),
          if (widget.onLogout != null)
            TextButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: _collapsed
                  ? const SizedBox.shrink()
                  : Text(SidebarLabels.t('Logout')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                alignment: Alignment.centerLeft,
              ),
            ),
        ],
      ),
    );
  }
}