import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Links shown in the app (also given on Google Play).
class AppLinks {
  const AppLinks._();

  static const String privacyPolicy = 'https://edu.nexorait.lk/privacy-policy';

  /// Opens the privacy policy in the browser.
  static Future<void> openPrivacyPolicy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(privacyPolicy), mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open $privacyPolicy')),
      );
    }
  }
}

/// Small "Privacy Policy" text link (setup and sign-in screens).
class PrivacyPolicyLink extends StatelessWidget {
  final Color? color;

  const PrivacyPolicyLink({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Colors.white.withValues(alpha: .75);
    return TextButton.icon(
      onPressed: () => AppLinks.openPrivacyPolicy(context),
      icon: Icon(Icons.privacy_tip_outlined, size: 16, color: textColor),
      label: Text(
        'Privacy Policy',
        style: TextStyle(
          color: textColor,
          fontSize: 12.5,
          decoration: TextDecoration.underline,
          decorationColor: textColor,
        ),
      ),
    );
  }
}
