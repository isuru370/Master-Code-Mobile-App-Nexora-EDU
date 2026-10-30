import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/institute/institute_info.dart';
import '../../../../core/institute/server_config.dart';
import '../../../../core/navigation/role_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nx_ui.dart';
import '../../../../core/widgets/privacy_policy_link.dart';

/// First start: connect the app to an institute by scanning the
/// "Staff App QR" from the institute website (Admin > Staff App QR).
///
/// Scan -> check the address (https *.nexorait.lk) -> the server checks the
/// key -> the user confirms the institute name -> login page.
class InstituteSetupPage extends StatefulWidget {
  const InstituteSetupPage({super.key});

  static const String routeName = '/institute-setup';

  @override
  State<InstituteSetupPage> createState() => _InstituteSetupPageState();
}

class _InstituteSetupPageState extends State<InstituteSetupPage> {
  bool _checking = false;
  bool _saving = false;
  String? _error;

  InstituteQr? _qr;
  Map<String, dynamic>? _institute;

  static const Color _muted = Color(0xB8FFFFFF);
  static const Color _glassBorder = Color(0x1FFFFFFF);

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _InstituteQrScanPage()),
    );

    if (!mounted || raw == null) return;

    setState(() {
      _error = null;
      _qr = null;
      _institute = null;
    });

    final InstituteQr qr;
    try {
      qr = ServerConfig.parseQr(raw);
    } on InstituteSetupException catch (e) {
      setState(() => _error = e.message);
      return;
    }

    setState(() => _checking = true);

    try {
      final institute = await ServerConfig.verify(qr);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _institute = institute;
      });
    } on InstituteSetupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check this QR code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _confirm() async {
    final qr = _qr;
    final institute = _institute;
    if (qr == null || institute == null) return;

    setState(() => _saving = true);

    try {
      await ServerConfig.save(qr.baseUrl);
      await InstituteInfo.applyFromSetup(institute);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the institute on this phone. Please try again.';
        });
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(RoleRouter.signIn, (_) => false);
  }

  void _scanAgain() {
    setState(() {
      _qr = null;
      _institute = null;
      _error = null;
    });
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.dark,
        body: NxNavyBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _card(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: AppColors.radiusLarge,
        border: Border.all(color: _glassBorder),
      ),
      child: _institute == null ? _scanView() : _confirmView(),
    );
  }

  /// Step 1: scan.
  Widget _scanView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: AppColors.radiusLarge,
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Connect to your institute',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ask your institute admin for the Staff App QR '
          '(on the institute website: Staff App QR) and scan it once. '
          'After that, sign in with your own email and password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          _errorBox(_error!),
          const SizedBox(height: 18),
        ],
        _primaryButton(
          label: _checking ? 'Checking QR code...' : 'Scan institute QR',
          icon: Icons.qr_code_scanner_rounded,
          busy: _checking,
          onPressed: _checking ? null : _scan,
        ),
        const SizedBox(height: 18),
        const Center(child: PrivacyPolicyLink()),
      ],
    );
  }

  /// Step 2: the server said the key is valid; is this the right institute?
  Widget _confirmView() {
    final institute = _institute!;
    final name = institute['name']?.toString() ?? '';
    final tagline = institute['tagline']?.toString() ?? '';
    final logoUrl = institute['logo_url']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_rounded, color: AppColors.success, size: 40),
        const SizedBox(height: 10),
        const Text(
          'Is this your institute?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppColors.radiusLarge,
            ),
            child: logoUrl.isEmpty
                ? Image.asset(InstituteInfo.defaultLogoAsset, fit: BoxFit.contain)
                : Image.network(
                    logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Image.asset(InstituteInfo.defaultLogoAsset, fit: BoxFit.contain),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (tagline.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(tagline, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
        ],
        const SizedBox(height: 6),
        Text(
          _qr?.baseUrl.replaceFirst(RegExp(r'^https?://'), '') ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12),
        ),
        const SizedBox(height: 26),
        _primaryButton(
          label: _saving ? 'Saving...' : 'Yes, continue',
          icon: Icons.check_rounded,
          busy: _saving,
          onPressed: _saving ? null : _confirm,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _saving ? null : _scanAgain,
          child: const Text('No, scan another QR', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: .5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required bool busy,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
          color: onPressed == null ? Colors.white.withValues(alpha: .12) : null,
          borderRadius: AppColors.radiusLarge,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(borderRadius: AppColors.radiusLarge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              else
                Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen camera; returns the first QR text it reads.
class _InstituteQrScanPage extends StatefulWidget {
  const _InstituteQrScanPage();

  @override
  State<_InstituteQrScanPage> createState() => _InstituteQrScanPageState();
}

class _InstituteQrScanPageState extends State<_InstituteQrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _hasPermission = false;
  bool _permissionDenied = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _hasPermission = status.isGranted;
      _permissionDenied = !status.isGranted;
    });

    if (_hasPermission) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _controller.start();
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done || capture.barcodes.isEmpty) return;

    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;

    _done = true;
    Navigator.of(context).pop(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan institute QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _permissionDenied
          ? _permissionView()
          : !_hasPermission
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    MobileScanner(controller: _controller, onDetect: _onDetect),
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 40),
                        child: Text(
                          'Point the camera at the Staff App QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _permissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Camera permission is needed to scan the institute QR.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open settings'),
            ),
          ],
        ),
      ),
    );
  }
}
