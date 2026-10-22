import 'package:get/get.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../routes/app_router.dart';

class AuthController extends GetxController {
  final Rxn<User> user = Rxn<User>();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  bool get isLoggedIn => user.value != null;
  User? get currentUser => user.value;
  String? get role => user.value?.role;

  @override
  void onInit() {
    super.onInit();
  }

  Future<void> tryRestoreSession() async {
    isLoading.value = true;
    try {
      final saved = await AuthService.getSavedUser();
      if (saved != null && saved.token != null) {
        final fresh = await AuthService.me();
        user.value = fresh ?? saved;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> login(String emailOrUsername, String password) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await AuthService.login(emailOrUsername, password);
      if (result['success'] == true && result['user'] is User) {
        user.value = result['user'] as User;
        _redirectByRole();
        return true;
      } else {
        errorMessage.value = result['message']?.toString() ?? 'Login failed';
        return false;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register({
    required String accessCode,
    required String fullName,
    String? email,
    required String username,
    String? phone,
    String? sector,
    required String password,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await AuthService.register(
        accessCode: accessCode,
        fullName: fullName,
        email: email,
        username: username,
        phone: phone,
        sector: sector,
        password: password,
      );
      if (result['success'] == true) {
        return true;
      } else {
        errorMessage.value = result['message']?.toString() ?? 'Registration failed';
        return false;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    user.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  void _redirectByRole() {
    final r = user.value?.role;
    if (r == null) {
      Get.offAllNamed(AppRoutes.login);
      return;
    }
    switch (r) {
      case 'collector':
        Get.offAllNamed(AppRoutes.collectorHome);
        break;
      case 'senior_accountant':
        Get.offAllNamed(AppRoutes.seniorAccountantHome);
        break;
      case 'team_leader':
        Get.offAllNamed(AppRoutes.teamLeaderHome);
        break;
      case 'finance_director':
        Get.offAllNamed(AppRoutes.financeDirectorHome);
        break;
      case 'management':
        Get.offAllNamed(AppRoutes.managementHome);
        break;
      case 'top_management':
        Get.offAllNamed(AppRoutes.topManagementHome);
        break;
      case 'superadmin':
        Get.offAllNamed(AppRoutes.superadminHome);
        break;
      default:
        Get.offAllNamed(AppRoutes.login);
    }
  }

  void redirectByRole() => _redirectByRole();
}
