import 'package:get/get.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/collector/collector_home.dart';
import '../screens/senior_accountant/senior_accountant_home.dart';
import '../screens/team_leader/team_leader_home.dart';
import '../screens/finance_director/finance_director_home.dart';
import '../screens/management/management_home.dart';
import '../screens/top_management/top_management_home.dart';
import '../screens/superadmin/superadmin_home.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';

  static const collectorHome = '/collector';
  static const seniorAccountantHome = '/senior-accountant';
  static const teamLeaderHome = '/team-leader';
  static const financeDirectorHome = '/finance-director';
  static const managementHome = '/management';
  static const topManagementHome = '/top-management';
  static const superadminHome = '/superadmin';
}

class AppRouter {
  static final routes = <GetPage>[
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.signup, page: () => const SignupScreen()),

    GetPage(name: AppRoutes.collectorHome, page: () => const CollectorHome()),
    GetPage(name: AppRoutes.seniorAccountantHome, page: () => const SeniorAccountantHome()),
    GetPage(name: AppRoutes.teamLeaderHome, page: () => const TeamLeaderHome()),
    GetPage(name: AppRoutes.financeDirectorHome, page: () => const FinanceDirectorHome()),
    GetPage(name: AppRoutes.managementHome, page: () => const ManagementHome()),
    GetPage(name: AppRoutes.topManagementHome, page: () => const TopManagementHome()),
    GetPage(name: AppRoutes.superadminHome, page: () => const SuperadminHome()),
  ];
}
