import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/Account_service.dart';
import '../controllers/lang_controller.dart';


Future<void> showAccountSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _AccountSettingsSheet(),
  );
}

class _AccountSettingsSheet extends StatefulWidget {
  const _AccountSettingsSheet();

  @override
  State<_AccountSettingsSheet> createState() => _AccountSettingsSheetState();
}

class _AccountSettingsSheetState extends State<_AccountSettingsSheet> {
  static const Color _primary = Color(0xFF0D7377);

  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newUsernameCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newUsernameCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {required bool obscured, required VoidCallback toggle}) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: IconButton(
        icon: Icon(obscured ? Icons.visibility_off : Icons.visibility, size: 20),
        onPressed: toggle,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _newUsernameCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;

    if (newUsername.isEmpty && newPassword.isEmpty) {
      Get.snackbar(
        'Nothing to update',
        'Enter a new username and/or a new password',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await AccountService.updateCredentials(
        currentPassword: _currentPasswordCtrl.text,
        newUsername: newUsername.isEmpty ? null : newUsername,
        newPassword: newPassword.isEmpty ? null : newPassword,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Get.snackbar(
          'success'.tr,
          'Your account details were updated',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );
        Navigator.of(context).pop();
      } else {
        Get.snackbar(
          'error'.tr,
          result['message']?.toString() ?? 'Could not update your account',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black,
        );
      }
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'error'.tr,
        'Could not update your account: $error',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: _primary),
                const SizedBox(width: 8),
                Text('account_settings'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),


            Obx(() {
              final lang = Get.find<LangController>();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: _primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('language'.tr, style: const TextStyle(fontSize: 14)),
                    ),
                    DropdownButton<String>(
                      value: lang.locale.value.languageCode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                      ],
                      onChanged: (code) {
                        if (code != null) lang.switchTo(code);
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),


            TextFormField(
              controller: _currentPasswordCtrl,
              obscureText: _obscureCurrent,
              decoration: _dec(
                'Current password *',
                obscured: _obscureCurrent,
                toggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newUsernameCtrl,
              decoration: const InputDecoration(
                labelText: 'New username (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordCtrl,
              obscureText: _obscureNew,
              decoration: _dec(
                'New password (optional)',
                obscured: _obscureNew,
                toggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null; // optional
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirm,
              decoration: _dec(
                'Confirm new password',
                obscured: _obscureConfirm,
                toggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) {
                if (_newPasswordCtrl.text.isEmpty) return null; // no new password entered
                if (v != _newPasswordCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('save'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}