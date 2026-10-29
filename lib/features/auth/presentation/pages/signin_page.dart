import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/storage/session_storage.dart';
import '../../../../core/navigation/role_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nx_ui.dart';
import '../bloc/auth/auth_bloc.dart';
import '../../../../core/institute/institute_info.dart';
import '../../../../core/institute/server_config.dart';
import 'institute_setup_page.dart';

/// Sign in, styled like the web login page (navy background, glass card).
class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  static const Color _label = Color(0xFFCBD5E1);
  static const Color _muted = Color(0xB8FFFFFF);
  static const Color _glassBorder = Color(0x1FFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();

    InstituteInfo.changes.addListener(_onInstituteInfo);
    InstituteInfo.loadSaved().then((_) => InstituteInfo.refresh());
  }

  void _onInstituteInfo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    InstituteInfo.changes.removeListener(_onInstituteInfo);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final email = await SessionStorage.getSavedEmail();

    if (email != null) {
      _emailController.text = email;
    }
  }

  /// web .form-control on the login card: see-through, light border
  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppColors.radiusLarge,
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: .45)),
      prefixIcon: Icon(prefixIcon, color: _label),
      suffixIcon: suffixIcon,
      suffixIconColor: _label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: .07),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(_glassBorder),
      enabledBorder: border(_glassBorder),
      focusedBorder: border(const Color(0xB33B82F6), 1.5),
      errorBorder: border(const Color(0xFFF87171)),
      focusedErrorBorder: border(const Color(0xFFF87171), 1.5),
      errorStyle: const TextStyle(color: Color(0xFFFECACA)),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _label,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
      LoginRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ),
    );
  }

  /// Forget this institute and scan another institute's QR.
  Future<void> _changeInstitute() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change institute?'),
        content: Text(
          'This phone will stop using ${InstituteInfo.name}. '
          'You will scan another institute\'s Staff App QR and sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await SessionStorage.clear();
    await SessionStorage.clearSavedEmail();
    await InstituteInfo.clearSaved();
    await ServerConfig.clear();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(InstituteSetupPage.routeName, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    const fieldText = TextStyle(color: Colors.white, fontSize: 15);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.dark,
        body: NxNavyBackground(
          child: SafeArea(
            child: BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthSuccess) {
                  final user = state.userModel;

                  final role = user.userType?.code.toUpperCase() ?? '';
                  final route = RoleRouter.homeRouteFor(role);

                  debugPrint('LOGIN ROLE: $role');

                  if (route != null) {
                    // SUPER_ADMIN / ADMIN / BRANCH_ADMIN / USER -> /dashboard
                    // TEACHER -> /teacher-dashboard
                    Navigator.of(context).pushReplacementNamed(
                      route,
                      arguments: {'token': state.token, 'user_model': user},
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unknown user role')),
                    );
                  }
                } else if (state is AuthFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              builder: (context, state) {
                final isLoading = state is AuthLoading;

                return LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Form(
                            key: _formKey,
                            child: _card(isLoading, fieldText),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// web .login-card
  Widget _card(bool isLoading, TextStyle fieldText) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: AppColors.radiusLarge,
        border: Border.all(color: _glassBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 50,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppColors.radiusLarge,
        child: Stack(
          children: [
            // blue circle in the top right corner (web .login-card::before)
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x243B82F6),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // logo box
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppColors.radiusLarge,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x731D4ED8),
                            blurRadius: 25,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image(
                        image: InstituteInfo.logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Image.asset(
                          InstituteInfo.defaultLogoAsset,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue to ${InstituteInfo.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 28),

                  _fieldLabel('Email address'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: fieldText,
                    cursorColor: Colors.white,
                    decoration: _inputDecoration(
                      hint: 'you@example.com',
                      prefixIcon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Email is required';
                      }
                      if (!text.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  _fieldLabel('Password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    style: fieldText,
                    cursorColor: Colors.white,
                    decoration: _inputDecoration(
                      hint: 'Your password',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 26),

                  // web .btn-login: blue gradient
                  SizedBox(
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: isLoading
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                              ),
                        color: isLoading
                            ? Colors.white.withValues(alpha: .12)
                            : null,
                        borderRadius: AppColors.radiusLarge,
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppColors.radiusLarge,
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.login_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  // One app for every institute: connect to another one
                  if (!ServerConfig.isBuiltForInstitute) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: isLoading ? null : _changeInstitute,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Change institute'),
                      style: TextButton.styleFrom(foregroundColor: _label),
                    ),
                  ],

                  const SizedBox(height: 22),
                  Text(
                    '© ${DateTime.now().year} ${InstituteInfo.name} · NexoraEDU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
