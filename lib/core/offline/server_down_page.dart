import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../features/offline_guide/offline_guide_page.dart';
import 'offline_sync.dart';

/// "The server is not working" / "No internet": what still works offline,
/// try again, the offline guide. As a card (dashboard) or a whole page (a
/// screen that needs the server).
class ServerDownCard extends StatelessWidget {
  const ServerDownCard({super.key, this.feature, this.onRetry});

  /// The screen that needs the server, e.g. "Admission".
  final String? feature;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineStatus>(
      valueListenable: OfflineSync.instance.status,
      builder: (context, s, _) {
        final down = s.serverDown;
        final color = down ? AppColors.warningText : AppColors.darkLight;
        final title = down ? 'Server එක දැනට වැඩ කරන්නේ නෑ' : 'Internet නෑ';
        final body = down
            ? 'Phone එකේ internet තියෙනවා, ඒත් server එකෙන් උත්තරයක් එන්නේ නෑ. '
                'අපි ඒක හදනකම් offline වැඩ කරන්න පුළුවන්.'
            : 'Phone එක internet එකට සම්බන්ධ වෙලා නෑ. Wi-Fi / mobile data බලන්න.';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(down ? Icons.dns_rounded : Icons.wifi_off_rounded, color: color, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (feature != null) ...[
                Text('$feature එකට server එක ඕනේ.',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
              ],
              Text(body, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              const Text('Offline වැඩ කරන දේවල්:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              for (final line in const [
                'Attendance scan කිරීම',
                'Class fee payments ගැනීම',
                'අලුත් ළමයි register කිරීම',
                'ළමයෙක් class එකකට add කිරීම',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.successText),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'Save කරපු ඒවා server එක ආපු ගමන් auto යනවා.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: s.syncing
                            ? null
                            : () async {
                                await OfflineSync.instance.run();
                                onRetry?.call();
                              },
                        icon: s.syncing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded),
                        label: Text(s.syncing ? 'Checking...' : 'Try again'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, OfflineGuidePage.routeName),
                      icon: const Icon(Icons.help_outline_rounded),
                      label: const Text('Guide'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A whole screen for a feature that needs the server, opened while
/// offline / the server is down. Closes itself when the server is back.
class ServerDownPage extends StatefulWidget {
  const ServerDownPage({super.key, required this.feature});

  final String feature;

  @override
  State<ServerDownPage> createState() => _ServerDownPageState();
}

class _ServerDownPageState extends State<ServerDownPage> {
  @override
  void initState() {
    super.initState();
    OfflineSync.instance.status.addListener(_onStatus);
  }

  @override
  void dispose() {
    OfflineSync.instance.status.removeListener(_onStatus);
    super.dispose();
  }

  void _onStatus() {
    final s = OfflineSync.instance.status.value;
    if (s.online && !s.syncing && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server එක ආවා. ${widget.feature} ආයෙත් open කරන්න.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.feature)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ServerDownCard(feature: widget.feature),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.dashboard_rounded),
            label: const Text('Dashboard එකට යන්න'),
          ),
        ],
      ),
    );
  }
}

