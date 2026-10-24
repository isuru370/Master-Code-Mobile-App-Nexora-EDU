import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../../core/theme/app_colors.dart';

/// Scans one student QR (or takes a typed ID) and returns it as a
/// [CourseScanResult] when the page is popped.
class CourseScanPage extends StatefulWidget {
  final String title;

  const CourseScanPage({super.key, this.title = 'Scan student QR'});

  @override
  State<CourseScanPage> createState() => _CourseScanPageState();
}

/// [scanned] = from the camera (qr_mobile), false = typed (manual_mobile)
class CourseScanResult {
  final String code;
  final bool scanned;

  const CourseScanResult(this.code, {required this.scanned});
}

class _CourseScanPageState extends State<CourseScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manual = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _finish(String code, {required bool scanned}) {
    final value = code.trim();
    if (_done || value.isEmpty) return;
    _done = true;
    Navigator.pop(context, CourseScanResult(value, scanned: scanned));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Torch',
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (capture.barcodes.isEmpty) return;
                    final value = capture.barcodes.first.rawValue;
                    if (value == null || value.trim().isEmpty) return;
                    _finish(value, scanned: true);
                  },
                ),
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) => _finish(value, scanned: false),
                    decoration: InputDecoration(
                      hintText: 'Or type student ID',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => _finish(_manual.text, scanned: false),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
