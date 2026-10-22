// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'controllers/auth_controller.dart';
import 'controllers/lang_controller.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';
import 'translations/app_translations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // LangController MUST be registered before runApp so the app can read
  // the starting language.
  Get.put(LangController(), permanent: true);
  Get.put(AuthController(), permanent: true);

  runApp(const EecApp());
}

class EecApp extends StatelessWidget {
  const EecApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LangController>();

    // IMPORTANT: no Obx() around GetMaterialApp.
    // `locale` here is only the STARTING language. Changing language later
    // is done with Get.updateLocale() inside LangController.
    return GetMaterialApp(
      title: 'EEC Receivable & Collection Report System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      translations: AppTranslations(),
      locale: lang.locale.value,
      fallbackLocale: const Locale('en'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('am')],
      initialRoute: AppRoutes.splash,
      getPages: AppRouter.routes,
    );
  }
}