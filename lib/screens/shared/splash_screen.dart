import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../routes/app_router.dart';
import '../../widgets/paginated_list.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = Get.find<AuthController>();
    await auth.tryRestoreSession();

    await Future.delayed(const Duration(milliseconds: 800));

    if (auth.isLoggedIn) {
      auth.redirectByRole();
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, size: 72, color: Color(0xFF0D7377)),
            SizedBox(height: 16),
            Text(
              'EEC Receivable &\nCollection Report System',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D7377),
                height: 1.3,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF0D7377)),
          ],
        ),
      ),
    );
  }
}
