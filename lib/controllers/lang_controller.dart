// lib/controllers/lang_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LangController extends GetxController {
  /// Starting language. To remember the user's choice between launches,
  /// load it here from GetStorage / SharedPreferences (see note below).
  final locale = const Locale('en').obs;

  bool get isAmharic => locale.value.languageCode == 'am';

  void setLanguage(String code) {
    final newLocale = Locale(code); // 'en' or 'am' (must match the keys)
    locale.value = newLocale;       // updates anything listening with Obx
    Get.updateLocale(newLocale);    // updates every 'key'.tr in the app
    // Persist here, e.g.: GetStorage().write('lang', code);
  }

  /// Kept so existing code like `lang.switchTo(code)` still compiles.
  void switchTo(String code) => setLanguage(code);

  void toggle() => setLanguage(isAmharic ? 'en' : 'am');

// To restore the saved language at startup:
// @override
// void onInit() {
//   super.onInit();
//   final saved = GetStorage().read<String>('lang');
//   if (saved != null) locale.value = Locale(saved);
// }
}