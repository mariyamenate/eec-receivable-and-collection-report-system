import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/lang_controller.dart';
import '../../routes/app_router.dart';

/// Create Account screen matching the provided UI:
/// Access Code, Full name, Email (optional), Username + Phone, Sector dropdown,
/// Password, Confirm password, Create Account button, Log In link.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accessCodeCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _selectedSector; // null = use access code assignment

  // Example sectors — replace with API list later if needed
  static const List<String> _sectors = [
    'Addis Ababa',
    'Oromia',
    'Amhara',
    'Tigray',
    'SNNPR',
    'Sidama',
    'Somali',
    'Afar',
    'Benishangul-Gumuz',
    'Gambela',
    'Harari',
    'Dire Dawa',
  ];

  // Brand teal/green from the design
  static const Color _primary = Color(0xFF0D7377);
  static const Color _buttonGradientStart = Color(0xFF14A3A8);
  static const Color _buttonGradientEnd = Color(0xFF0D7377);

  @override
  void dispose() {
    _accessCodeCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Get.find<AuthController>();
    final ok = await auth.register(
      accessCode: _accessCodeCtrl.text.trim(),
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      sector: _selectedSector,
      password: _passwordCtrl.text.trim(),
    );

    if (ok) {
      Get.snackbar(
        'Success',
        'Account created. Please log in.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _primary,
        colorText: Colors.white,
      );
      Get.offNamed(AppRoutes.login);
    }
  }

  InputDecoration _inputDecoration({
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      suffixIcon: suffix,
    );
  }

  Widget _label(String text, {bool required = false, String? optionalNote}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            if (optionalNote != null)
              TextSpan(
                text: ' $optionalNote',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final lang = Get.find<LangController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Language toggle
                    Align(
                      alignment: Alignment.centerRight,
                      child: Obx(() => TextButton(
                            onPressed: lang.toggle,
                            child: Text(
                              lang.isAmharic ? 'English' : 'አማርኛ',
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )),
                    ),

                    const SizedBox(height: 8),

                    // Title
                    const Text(
                      'Create account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Requires a valid access code from your administrator.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Access Code
                    _label('Access Code', required: true),
                    TextFormField(
                      controller: _accessCodeCtrl,
                      decoration: _inputDecoration(),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Access code is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Full name
                    _label('Full name', required: true),
                    TextFormField(
                      controller: _fullNameCtrl,
                      decoration: _inputDecoration(),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Email (optional)
                    _label('Email address', optionalNote: '(optional)'),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Username + Phone side by side
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Username', required: true),
                              TextFormField(
                                controller: _usernameCtrl,
                                decoration: _inputDecoration(),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'Min 3 chars';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Phone', optionalNote: '(optional)'),
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: _inputDecoration(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Sector
                    _label('Sector', optionalNote: '(only if access code has no sector)'),
                    DropdownButtonFormField<String>(
                      value: _selectedSector,
                      decoration: _inputDecoration(),
                      isExpanded: true,
                      hint: const Text(
                        '-- assigned by access code preferred --',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- assigned by access code preferred --'),
                        ),
                        ..._sectors.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedSector = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sector is assigned automatically from the access code when the admin linked a sector to it.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Password
                    _label('Password', required: true),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration(
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                            size: 22,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      onChanged: (_) {
                        // Re-check confirm field when password changes
                        if (_formKey.currentState != null) {
                          _formKey.currentState!.validate();
                        }
                      },
                      validator: (v) {
                        final p = (v ?? '').trim();
                        if (p.isEmpty) return 'Password is required';
                        if (p.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Confirm password
                    _label('Confirm password', required: true),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirm,
                      decoration: _inputDecoration(
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                            size: 22,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        final confirm = (v ?? '').trim();
                        final password = _passwordCtrl.text.trim();
                        if (confirm.isEmpty) return 'Please confirm password';
                        if (confirm != password) return 'Passwords do not match';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Error message
                    Obx(() {
                      if (auth.errorMessage.value.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          auth.errorMessage.value,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // Create Account button
                    Obx(() => SizedBox(
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [_buttonGradientStart, _buttonGradientEnd],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: auth.isLoading.value ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: auth.isLoading.value
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        )),

                    const SizedBox(height: 20),

                    // Already have an account?
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => Get.offNamed(AppRoutes.login),
                          child: const Text(
                            'Log In',
                            style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
