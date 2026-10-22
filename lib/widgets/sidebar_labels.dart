import 'package:get/get.dart';
import '../controllers/lang_controller.dart';

/// English -> Amharic labels for the sidebar. Unknown labels stay English.
class SidebarLabels {
  static const Map<String, String> _am = {
    // common
    'Home': 'መነሻ',
    'Report History': 'የሪፖርት ታሪክ',
    'Messages': 'መልእክቶች',
    'Notifications': 'ማሳወቂያዎች',
    'Account Settings': 'የመለያ ቅንብሮች',
    'Logout': 'ውጣ',
    // collector
    'Collect Data': 'መረጃ ሰብስብ',
    'My Collections': 'የእኔ ስብስቦች',
    // senior accountant
    'Incoming Collections': 'የገቡ ስብስቦች',
    'Build Template': 'አብነት ገንባ',
    'My Templates': 'የእኔ አብነቶች',
    // team leader / management
    'Reports for Review': 'ለግምገማ የቀረቡ ሪፖርቶች',
    'Generate Summary & Send': 'ማጠቃለያ አዘጋጅ እና ላክ',
    'Assign Collectors': 'ሰብሳቢዎችን መድብ',
    // finance director / top management
    'View Reports': 'ሪፖርቶችን ተመልከት',
    'Final Reports': 'የመጨረሻ ሪፖርቶች',

    'Business Units & Projects': 'የንግድ ክፍሎች እና ፕሮጀክቶች',
    'Access Codes': 'የመግቢያ ኮዶች',
    'User Management': 'የተጠቃሚ አስተዳደር',
    'All Reports': 'ሁሉም ሪፖርቶች',
    'System Settings': 'የሲስተም ቅንብሮች',

    'Collector': 'ሰብሳቢ',
    'Senior Accountant': 'ከፍተኛ ሂሳብ ሹም',
    'Team Leader': 'ቡድን መሪ',
    'Finance Director': 'የፋይናንስ ዳይሬክተር',
    'Management': 'አመራር',
    'Top Management': 'ከፍተኛ አመራር',
    'Super Admin': 'ሱፐር አድሚን',
  };

  static String t(String en) {
    if (!Get.isRegistered<LangController>()) return en;
    final lang = Get.find<LangController>();
    return lang.locale.value.languageCode == 'am' ? (_am[en] ?? en) : en;
  }
}