import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/api_constants.dart';
import '../../core/storage/session_storage.dart';
import '../../core/theme/app_colors.dart';

/// "Send Feedback": a problem, an idea or anything else, with an optional
/// screenshot. Saved on the institute's server (Super Admin > App Feedback)
/// and emailed to Nexora IT. App version and phone model go with it.
class SendFeedbackPage extends StatefulWidget {
  const SendFeedbackPage({super.key});

  static const String routeName = '/send_feedback';

  @override
  State<SendFeedbackPage> createState() => _SendFeedbackPageState();
}

class _SendFeedbackPageState extends State<SendFeedbackPage> {
  final _message = TextEditingController();
  String _type = 'bug';
  File? _screenshot;
  bool _sending = false;

  static const Map<String, (String, IconData)> _types = {
    'bug': ('Problem', Icons.bug_report_rounded),
    'idea': ('Idea', Icons.lightbulb_rounded),
    'other': ('Other', Icons.chat_bubble_rounded),
  };

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      setState(() => _screenshot = File(picked.path));
    } catch (_) {
      _snack('Could not open the gallery.');
    }
  }

  Future<Map<String, String>> _appInfo() async {
    final info = <String, String>{};

    try {
      final package = await PackageInfo.fromPlatform();
      info['app_version'] = '${package.version} (${package.buildNumber})';
    } catch (_) {}

    try {
      final device = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await device.androidInfo;
        info['device'] = '${android.manufacturer} ${android.model}';
        info['platform'] = 'Android ${android.version.release}';
      } else if (Platform.isIOS) {
        final ios = await device.iosInfo;
        info['device'] = ios.utsname.machine;
        info['platform'] = 'iOS ${ios.systemVersion}';
      }
    } catch (_) {
      info['platform'] = Platform.operatingSystem;
    }

    return info;
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.length < 5) {
      _snack('Please write a little more (at least 5 letters).');
      return;
    }

    setState(() => _sending = true);

    try {
      final token = await SessionStorage.getToken();
      final request = http.MultipartRequest('POST', Uri.parse('${ApiConstants.apiUrl}/feedback'))
        ..headers.addAll({
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        })
        ..fields['type'] = _type
        ..fields['message'] = text
        ..fields.addAll(await _appInfo());

      if (_screenshot != null) {
        request.files.add(await http.MultipartFile.fromPath('screenshot', _screenshot!.path));
      }

      final response = await http.Response.fromStream(await request.send());
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.favorite_rounded, color: AppColors.success, size: 40),
            title: const Text('Thank you!'),
            content: const Text('Your feedback was sent to the Nexora team.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK')),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }

      _snack(body['message']?.toString() ?? 'Could not send. Please try again.');
    } catch (_) {
      _snack('Could not send. Check the internet and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Feedback')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tell us about a problem, or an idea to make the app better. '
              'It goes to the Nexora team with your app version and phone model.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),

            const Text('Type', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types.entries.map((entry) {
                final selected = _type == entry.key;
                return ChoiceChip(
                  avatar: Icon(entry.value.$2, size: 18, color: selected ? Colors.white : AppColors.primary),
                  label: Text(entry.value.$1),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600),
                  onSelected: _sending ? null : (_) => setState(() => _type = entry.key),
                );
              }).toList(),
            ),

            const SizedBox(height: 18),
            TextField(
              controller: _message,
              enabled: !_sending,
              minLines: 5,
              maxLines: 10,
              maxLength: 3000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _type == 'bug' ? 'What happened? Which screen?' : 'Your message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 8),
            if (_screenshot == null)
              OutlinedButton.icon(
                onPressed: _sending ? null : _pickScreenshot,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: const Text('Add a screenshot (optional)'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_screenshot!, height: 180, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filled(
                      tooltip: 'Remove',
                      onPressed: _sending ? null : () => setState(() => _screenshot = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending...' : 'Send Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
