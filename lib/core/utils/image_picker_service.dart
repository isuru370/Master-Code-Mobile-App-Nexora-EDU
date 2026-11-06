import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../camera/in_app_camera_page.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Camera: taken inside the app (InAppCameraPage), already cut to the
  /// 18:22 ID shape. The phone's camera app is not used any more: low-RAM
  /// phones killed our app while it was open (looked like a logout).
  Future<File?> takePhoto(BuildContext context) {
    return InAppCameraPage.open(context, title: 'Student Photo');
  }

  /// Gallery: pick + crop for ID card (18:22 ratio)
  Future<File?> pickFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 1600,
      );

      if (pickedFile == null) return null;

      return cropImage(pickedFile.path);
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Crop a picked photo to the ID card shape (18:22)
  Future<File?> cropImage(String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 18, ratioY: 22),
      compressQuality: 90,
      maxWidth: 600,
      maxHeight: 750,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop ID Photo',
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop ID Photo',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) return null;

    return File(croppedFile.path);
  }
}
