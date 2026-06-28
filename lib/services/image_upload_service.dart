import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ImageUploadService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  ImageUploadService({
    required FirebaseStorage storage,
    ImagePicker? picker,
  })  : _storage = storage,
        _picker = picker ?? ImagePicker();

  Future<File?> pickFromCamera({int maxDim = 1200, int quality = 85}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxDim.toDouble(),
      maxHeight: maxDim.toDouble(),
      imageQuality: quality,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<File?> pickFromGallery({int maxDim = 1200, int quality = 85}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxDim.toDouble(),
      maxHeight: maxDim.toDouble(),
      imageQuality: quality,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<List<File>> pickMultipleFromGallery({int limit = 5}) async {
    final picked = await _picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
      limit: limit,
    );
    return picked.map((x) => File(x.path)).toList();
  }

  Future<String> uploadCommerceLogo({
    required String commerceId,
    required File file,
    void Function(double progress)? onProgress,
  }) =>
      _upload(
        file: file,
        storagePath: 'commerces/$commerceId/logo.jpg',
        onProgress: onProgress,
      );

  Future<String> uploadCommerceGalleryImage({
    required String commerceId,
    required File file,
    void Function(double progress)? onProgress,
  }) =>
      _upload(
        file: file,
        storagePath:
            'commerces/$commerceId/gallery/${DateTime.now().millisecondsSinceEpoch}.jpg',
        onProgress: onProgress,
      );

  Future<String> uploadPromotionImage({
    required String promotionId,
    required File file,
    void Function(double progress)? onProgress,
  }) =>
      _upload(
        file: file,
        storagePath: 'promotions/$promotionId/cover.jpg',
        onProgress: onProgress,
      );

  Future<String> uploadUserAvatar({
    required String userId,
    required File file,
    void Function(double progress)? onProgress,
  }) =>
      _upload(
        file: file,
        storagePath: 'users/$userId/avatar.jpg',
        onProgress: onProgress,
      );

  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } catch (_) {}
  }

  Future<String> _upload({
    required File file,
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref(storagePath);
    final task = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    if (onProgress != null) {
      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress(s.bytesTransferred / s.totalBytes);
        }
      });
    }

    await task;
    return ref.getDownloadURL();
  }
}
