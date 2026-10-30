import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/navigation/role_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/privacy_policy_link.dart';
import '../../../../auth/data/datasources/auth_remote_data_source.dart';
import '../../data/model/teacher_profile_model.dart';
import '../bloc/teacher_profile/teacher_profile_bloc.dart';

/// Teacher > Profile: the logged-in teacher's details from
/// GET /v1/teacher/profile, edit contact details, change password, log out.
class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({super.key});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    context.read<TeacherProfileBloc>().add(const FetchTeacherProfile());
  }

  void _reload() =>
      context.read<TeacherProfileBloc>().add(const FetchTeacherProfile());

  TeacherProfileModel? _profileOf(TeacherProfileState state) => switch (state) {
        TeacherProfileLoaded(:final profile) => profile,
        TeacherProfileUpdating(:final profile) => profile,
        TeacherProfileUpdated(:final profile) => profile,
        TeacherPasswordChanging(:final profile) => profile,
        TeacherPasswordChanged(:final profile) => profile,
        TeacherProfileError(:final profile) => profile,
        _ => null,
      };

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<TeacherProfileBloc, TeacherProfileState>(
          listener: (context, state) {
            if (state is TeacherProfileUpdated) {
              _snack('Profile updated.');
            } else if (state is TeacherPasswordChanged) {
              _snack('Password changed.');
            } else if (state is TeacherProfileError && state.profile != null) {
              _snack(state.message, error: true);
            }
          },
          builder: (context, state) {
            final profile = _profileOf(state);

            if (profile == null) {
              if (state is TeacherProfileError) {
                return _ErrorView(message: state.message, onRetry: _reload, onLogout: _logout);
              }
              return const Center(child: CircularProgressIndicator());
            }

            final busy = state is TeacherProfileUpdating || state is TeacherPasswordChanging;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    _buildHeader(profile, busy),
                    _buildProfileCard(profile),
                    _buildSection(
                      title: 'Personal Information',
                      icon: Icons.person_outline_rounded,
                      children: [
                        _infoRow(icon: Icons.badge_outlined, label: 'Teacher ID', value: _text(profile.customId)),
                        _infoRow(icon: Icons.email_outlined, label: 'Email', value: _text(profile.email)),
                        _infoRow(icon: Icons.phone_outlined, label: 'Mobile', value: _text(profile.mobile)),
                        _infoRow(icon: Icons.credit_card_outlined, label: 'NIC', value: _text(profile.nic)),
                        _infoRow(icon: Icons.cake_outlined, label: 'Birthday', value: _text(profile.birthday)),
                        _infoRow(icon: Icons.wc_outlined, label: 'Gender', value: _capitalize(profile.gender), showDivider: false),
                      ],
                    ),
                    _buildSection(
                      title: 'Contact Address',
                      icon: Icons.location_on_outlined,
                      children: [
                        _infoRow(icon: Icons.home_outlined, label: 'Address', value: _address(profile), showDivider: false),
                      ],
                    ),
                    _buildSection(
                      title: 'Professional Information',
                      icon: Icons.school_outlined,
                      children: [
                        _infoRow(icon: Icons.workspace_premium_outlined, label: 'Education', value: _text(profile.graduationDetails)),
                        _infoRow(icon: Icons.work_history_outlined, label: 'Experience', value: _text(profile.experience), showDivider: false),
                      ],
                    ),
                    _buildSection(
                      title: 'Bank Information',
                      icon: Icons.account_balance_outlined,
                      children: [
                        _infoRow(icon: Icons.account_box_outlined, label: 'Account Number', value: _maskAccount(profile.bank?.accountNumber)),
                        _infoRow(icon: Icons.location_city_outlined, label: 'Branch', value: _text(profile.bank?.branch?.name), showDivider: false),
                      ],
                    ),
                    _buildActionButtons(busy),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loggingOut = true);

    // Deletes the token on the server, then clears the saved session
    await AuthRemoteDataSource().logout();

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(RoleRouter.signIn, (route) => false);
  }

  Future<void> _changePassword() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (result == null || !mounted) return;

    context.read<TeacherProfileBloc>().add(TeacherPasswordChangeRequested(
          currentPassword: result[0],
          newPassword: result[1],
          newPasswordConfirmation: result[2],
        ));
  }

  Future<void> _editProfile(TeacherProfileModel profile) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditProfileDialog(profile: profile),
    );

    if (data == null || data.isEmpty || !mounted) return;

    context.read<TeacherProfileBloc>().add(TeacherProfileUpdateRequested(data));
  }

  // ============================================================
  // FORMAT
  // ============================================================

  String _text(String? value) => (value == null || value.trim().isEmpty) ? '-' : value.trim();

  String _capitalize(String? value) {
    final text = _text(value);
    return text == '-' ? text : text[0].toUpperCase() + text.substring(1);
  }

  String _address(TeacherProfileModel profile) {
    final parts = [profile.address?.address1, profile.address?.address2, profile.address?.address3]
        .where((p) => p != null && p.trim().isNotEmpty)
        .map((p) => p!.trim())
        .toList();
    return parts.isEmpty ? '-' : parts.join(',\n');
  }

  String _maskAccount(String? number) {
    final text = (number ?? '').replaceAll(' ', '');
    if (text.isEmpty) return '-';
    if (text.length <= 4) return text;
    return '**** ${text.substring(text.length - 4)}';
  }

  String _initials(TeacherProfileModel profile) {
    final source = _text(profile.fullName) == '-' ? _text(profile.initials) : profile.fullName!;
    final words = source.split(RegExp(r'[\s.]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'T';
    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return (first + last).toUpperCase();
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(TeacherProfileModel profile, bool busy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppColors.paddingLarge, 20, AppColors.paddingLarge, 18),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                SizedBox(height: 4),
                Text('My Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppColors.radiusMedium,
              border: Border.all(color: AppColors.border),
            ),
            child: busy
                ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => _editProfile(profile),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 21),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE CARD
  // ============================================================

  Widget _buildProfileCard(TeacherProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppColors.paddingLarge),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: AppColors.radiusLarge,
          boxShadow: AppColors.mediumShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Center(
                child: Text(
                  _initials(profile),
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(profile.fullName) == '-' ? _text(profile.initials) : profile.fullName!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _text(profile.customId),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 7, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          profile.isActive ? 'Active Teacher' : 'Inactive',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ],
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

  // ============================================================
  // SECTION / INFO ROW
  // ============================================================

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppColors.paddingLarge, 18, AppColors.paddingLarge, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppColors.radiusMedium,
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(11)),
                    child: Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value, bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 19, color: AppColors.iconSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(padding: EdgeInsets.only(left: 47), child: Divider(height: 1, color: AppColors.divider)),
      ],
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget _buildActionButtons(bool busy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppColors.paddingLarge, 20, AppColors.paddingLarge, 0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: busy ? null : _changePassword,
              icon: const Icon(Icons.lock_outline_rounded, size: 19),
              label: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: AppColors.radiusMedium),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _loggingOut ? null : _logout,
              icon: _loggingOut
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.logout_rounded, size: 19),
              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.dangerLight),
                backgroundColor: AppColors.dangerLight,
                shape: RoundedRectangleBorder(borderRadius: AppColors.radiusMedium),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(child: PrivacyPolicyLink(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ============================================================
// LOAD ERROR
// ============================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const _ErrorView({required this.message, required this.onRetry, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: 8),
            // A teacher must always be able to log out, even if the profile cannot load.
            TextButton(onPressed: onLogout, child: const Text('Logout', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CHANGE PASSWORD
// ============================================================

/// Returns [current, new, confirmation] or null when cancelled.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _show = !_show),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _current,
                obscureText: !_show,
                decoration: _decoration('Current password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _new,
                obscureText: !_show,
                decoration: _decoration('New password'),
                validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirm,
                obscureText: !_show,
                decoration: _decoration('New password again'),
                validator: (v) => v != _new.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_form.currentState?.validate() ?? false) {
              Navigator.pop(context, [_current.text, _new.text, _confirm.text]);
            }
          },
          child: const Text('Change'),
        ),
      ],
    );
  }
}

// ============================================================
// EDIT PROFILE (contact details only - name, NIC and bank are
// managed by the institute admin)
// ============================================================

/// Returns only the changed fields, or null when cancelled.
class _EditProfileDialog extends StatefulWidget {
  final TeacherProfileModel profile;

  const _EditProfileDialog({required this.profile});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late final Map<String, String> _original;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _original = {
      'email': p.email ?? '',
      'mobile': p.mobile ?? '',
      'address1': p.address?.address1 ?? '',
      'address2': p.address?.address2 ?? '',
      'address3': p.address?.address3 ?? '',
      'graduation_details': p.graduationDetails ?? '',
      'experience': p.experience ?? '',
    };
    _fields = _original.map((k, v) => MapEntry(k, TextEditingController(text: v)));
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, {TextInputType? type, String? Function(String?)? validator, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _fields[key],
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('email', 'Email', type: TextInputType.emailAddress, validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Enter a valid email';
              }),
              _field('mobile', 'Mobile', type: TextInputType.phone, validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.isEmpty || digits.length >= 9 ? null : 'Enter a valid mobile number';
              }),
              _field('address1', 'Address line 1'),
              _field('address2', 'Address line 2'),
              _field('address3', 'Address line 3'),
              _field('graduation_details', 'Education', maxLines: 2),
              _field('experience', 'Experience', maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;

            final changed = <String, dynamic>{};
            _fields.forEach((key, controller) {
              final value = controller.text.trim();
              if (value != _original[key]!.trim()) {
                changed[key] = value.isEmpty ? null : value;
              }
            });

            Navigator.pop(context, changed);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
