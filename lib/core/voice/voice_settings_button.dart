import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'attendance_voice.dart';

/// Speaker button for the scanner app bar: voice on / off and speed for this
/// phone. Shown only when the institute has the "tts" feature.
class VoiceSettingsButton extends StatefulWidget {
  const VoiceSettingsButton({super.key});

  @override
  State<VoiceSettingsButton> createState() => _VoiceSettingsButtonState();
}

class _VoiceSettingsButtonState extends State<VoiceSettingsButton> {
  final AttendanceVoice _voice = AttendanceVoice.instance;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _voice.isEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (!_voice.isAvailable) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Voice',
      icon: Icon(
        _enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        color: _enabled ? AppColors.primary : AppColors.textMuted,
      ),
      onPressed: _openSettings,
    );
  }

  Future<void> _openSettings() async {
    await _voice.prepare();
    var enabled = await _voice.isEnabled();
    var rate = await _voice.rate();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voice on attendance', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Name, subject and grade in English, then "ගෙවා ඇත / ගෙවා නැත". Free card: a beep.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Speak after each scan'),
                  value: enabled,
                  onChanged: (value) async {
                    await _voice.setEnabled(value);
                    setSheet(() => enabled = value);
                    if (mounted) setState(() => _enabled = value);
                  },
                ),
                Text('Speed', style: Theme.of(context).textTheme.bodyMedium),
                Slider(
                  value: rate,
                  min: 0.3,
                  max: 0.7,
                  divisions: 4,
                  label: rate < 0.45 ? 'Slow' : (rate > 0.55 ? 'Fast' : 'Normal'),
                  onChanged: enabled ? (value) => setSheet(() => rate = value) : null,
                  onChangeEnd: (value) => _voice.setRate(value),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.record_voice_over_rounded),
                    label: const Text('Test'),
                    onPressed: enabled
                        ? () async {
                            await _voice.test();
                            setSheet(() {});
                          }
                        : null,
                  ),
                ),
                if (!_voice.hasSinhala) ...[
                  const SizedBox(height: 8),
                  Text(
                    'No Sinhala voice on this phone yet: "Paid / Not paid" is said in English. '
                    'Install it: Settings > Text-to-speech > Google > Install voice data > Sinhala.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.dangerText),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
