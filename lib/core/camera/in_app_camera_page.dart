import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Takes the student ID photo inside the app.
///
/// Why not the phone's camera app (image_picker)?
/// While the camera app is open our app is in the background, and phones
/// with little RAM kill it. When the photo is taken Android starts the app
/// again from the splash screen: the photo and the page are lost and staff
/// see it as "logged out". Here the app never leaves the screen.
///
/// The preview shows exactly the 18:22 ID photo frame; the same area is
/// cut from the picture and saved as a 600 x 733 JPEG.
///
/// Returns the photo as a [File], or null when cancelled:
///   final file = await InAppCameraPage.open(context);
class InAppCameraPage extends StatefulWidget {
  const InAppCameraPage({super.key, this.title = 'Take Photo'});

  final String title;

  /// ID photo shape (width : height), same as the old crop screen
  static const double photoAspect = 18 / 22;

  static const int outputWidth = 600;
  static const int outputHeight = 733;

  static Future<File?> open(BuildContext context, {String title = 'Take Photo'}) {
    return Navigator.of(context).push<File?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => InAppCameraPage(title: title),
      ),
    );
  }

  @override
  State<InAppCameraPage> createState() => _InAppCameraPageState();
}

class _InAppCameraPageState extends State<InAppCameraPage>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;
  FlashMode _flash = FlashMode.off;

  bool _starting = true;
  bool _capturing = false;
  String? _error;

  /// Photo taken, waiting for "Use photo" / "Retake"
  File? _taken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// Free the camera when the app goes to the background, open it again
  /// when it comes back (Android does not allow two apps on the camera).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (controller != null) {
        _controller = null;
        controller.dispose();
        if (mounted) setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      // _starting: the permission dialog also pauses the app; that camera
      // is still opening, so do not open a second one
      if (_controller == null && !_starting && _cameras.isNotEmpty && _taken == null) {
        _openCamera(_cameras[_cameraIndex]);
      }
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      _fail(_message(e));
      return;
    }

    if (_cameras.isEmpty) {
      _fail('No camera found on this phone.');
      return;
    }

    // Back camera first
    final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    _cameraIndex = back >= 0 ? back : 0;

    await _openCamera(_cameras[_cameraIndex]);
  }

  Future<void> _openCamera(CameraDescription description) async {
    setState(() {
      _starting = true;
      _error = null;
    });

    final old = _controller;
    _controller = null;
    await old?.dispose();

    // "high" = about 720p: plenty for a 600 px ID photo and light on memory
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      try {
        await controller.setFlashMode(_flash);
      } catch (_) {
        // Front cameras usually have no flash
      }
    } on CameraException catch (e) {
      await controller.dispose();
      _fail(_message(e));
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _starting = false;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _starting = false;
      _error = message;
    });
  }

  String _message(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera permission is needed to take the photo. '
            'Allow it in Settings > Apps > Nexora > Permissions.';
      default:
        return 'Could not open the camera (${e.description ?? e.code}).';
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _capturing) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(_cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;

    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };

    try {
      await controller.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This camera has no flash.')),
      );
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;

    setState(() => _capturing = true);

    try {
      final shot = await controller.takePicture();

      // Cut the ID frame and shrink it in the background (no UI freeze)
      final jpg = await compute(_cropToIdPhoto, shot.path);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/id_photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(jpg, flush: true);

      try {
        await File(shot.path).delete();
      } catch (_) {}

      if (!mounted) return;

      // Camera is not needed while the photo is checked
      _controller = null;
      await controller.dispose();

      setState(() {
        _taken = file;
        _capturing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not take the photo. Please try again. ($e)')),
      );
    }
  }

  Future<void> _retake() async {
    final old = _taken;
    setState(() => _taken = null);

    try {
      await old?.delete();
    } catch (_) {}

    await _openCamera(_cameras[_cameraIndex]);
  }

  void _usePhoto() => Navigator.of(context).pop(_taken);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_taken == null ? widget.title : 'Check Photo'),
        actions: [
          if (_taken == null && _controller != null) ...[
            IconButton(
              tooltip: 'Flash',
              onPressed: _toggleFlash,
              icon: Icon(switch (_flash) {
                FlashMode.auto => Icons.flash_auto_rounded,
                FlashMode.always => Icons.flash_on_rounded,
                _ => Icons.flash_off_rounded,
              }),
            ),
            if (_cameras.length > 1)
              IconButton(
                tooltip: 'Switch camera',
                onPressed: _switchCamera,
                icon: const Icon(Icons.cameraswitch_rounded),
              ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AspectRatio(
                    aspectRatio: InAppCameraPage.photoAspect,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _frameContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _taken == null
                    ? 'Fit the student\'s face and shoulders inside the frame'
                    : 'Is the face clear? Use the photo or take it again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _taken == null ? _captureButton() : _reviewButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _frameContent() {
    if (_taken != null) {
      return Image.file(_taken!, fit: BoxFit.cover);
    }

    if (_error != null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _start,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (_starting || controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Fill the frame like "cover": the picture is cut the same way
    final size = controller.value.previewSize;
    final previewW = size == null ? 720.0 : size.height; // previewSize is landscape
    final previewH = size == null ? 1280.0 : size.width;

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: previewW,
        height: previewH,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _captureButton() {
    final ready = _controller != null && !_starting && _error == null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: ready ? _capture : null,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready ? Colors.white : Colors.white24,
              ),
              child: _capturing
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _retake,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retake'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _usePhoto,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Use Photo'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Runs in a background isolate: the centre 18:22 area of the picture
/// (what the preview frame showed), resized to 600 x 733, as JPEG.
Uint8List _cropToIdPhoto(String path) {
  final bytes = File(path).readAsBytesSync();

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('The photo could not be read.');
  }

  // Some phones save the picture sideways with an EXIF rotation tag
  final image = img.bakeOrientation(decoded);

  const aspect = InAppCameraPage.photoAspect;

  var cropW = image.width;
  var cropH = (image.width / aspect).round();

  if (cropH > image.height) {
    cropH = image.height;
    cropW = (image.height * aspect).round();
  }

  final x = ((image.width - cropW) / 2).round();
  final y = ((image.height - cropH) / 2).round();

  final cropped = img.copyCrop(image, x: x, y: y, width: cropW, height: cropH);

  final resized = img.copyResize(
    cropped,
    width: InAppCameraPage.outputWidth,
    height: InAppCameraPage.outputHeight,
    interpolation: img.Interpolation.average,
  );

  return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
}
