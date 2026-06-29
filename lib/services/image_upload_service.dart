import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  final ImagePicker _picker;
  final Dio _dio;

  static const _cloudName = 'dtkpp4ep6';
  static const _apiKey = '954936455264143';
  static const _apiSecret = 'YLuSNU6B5YHSCfA6Z195oSxrwLE';
  static const _baseUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  ImageUploadService({ImagePicker? picker, Dio? dio})
      : _picker = picker ?? ImagePicker(),
        _dio = dio ?? Dio();

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
        folder: 'shinracity/commerces/$commerceId',
        publicId: 'logo',
        onProgress: onProgress,
      );

  Future<String> uploadCommerceGalleryImage({
    required String commerceId,
    required File file,
    void Function(double progress)? onProgress,
  }) =>
      _upload(
        file: file,
        folder: 'shinracity/commerces/$commerceId/gallery',
        onProgress: onProgress,
      );

  Future<String> uploadPromotionImage({
    required String promotionId,
    required File file,
    void Function(double progress)? onProgress,
  }) =>
      _upload(
        file: file,
        folder: 'shinracity/promotions/$promotionId',
        publicId: 'cover',
        onProgress: onProgress,
      );

  Future<String> uploadUserAvatar({
    required String userId,
    required File file,
    void Function(double progress)? onProgress,
  }) =>
      _upload(
        file: file,
        folder: 'shinracity/users/$userId',
        publicId: 'avatar',
        onProgress: onProgress,
      );

  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      // Extract public_id from Cloudinary URL
      // Format: https://res.cloudinary.com/{cloud}/image/upload/v{ver}/{public_id}.ext
      final uri = Uri.parse(downloadUrl);
      final segments = uri.pathSegments;
      final uploadIdx = segments.indexOf('upload');
      if (uploadIdx == -1) return;
      // Skip version segment (v1234567890)
      final afterUpload = segments.sublist(uploadIdx + 1);
      final withVersion = afterUpload.first.startsWith('v') ? afterUpload.sublist(1) : afterUpload;
      final publicIdWithExt = withVersion.join('/');
      final publicId = publicIdWithExt.contains('.')
          ? publicIdWithExt.substring(0, publicIdWithExt.lastIndexOf('.'))
          : publicIdWithExt;

      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
      final params = {'public_id': publicId, 'timestamp': timestamp};
      final signature = _sign(params);

      await _dio.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy',
        data: FormData.fromMap({
          ...params,
          'api_key': _apiKey,
          'signature': signature,
        }),
      );
    } catch (_) {}
  }

  String _sign(Map<String, String> params) {
    final sorted = params.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final paramStr = sorted.map((e) => '${e.key}=${e.value}').join('&');
    return sha1.convert(utf8.encode('$paramStr$_apiSecret')).toString();
  }

  Future<String> _upload({
    required File file,
    required String folder,
    String? publicId,
    void Function(double progress)? onProgress,
  }) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
    final params = <String, String>{
      'folder': folder,
      'timestamp': timestamp,
      if (publicId != null) 'public_id': publicId,
    };

    final signature = _sign(params);

    final formData = FormData.fromMap({
      ...params,
      'api_key': _apiKey,
      'signature': signature,
      'file': await MultipartFile.fromFile(file.path, filename: 'upload.jpg'),
    });

    final response = await _dio.post(
      _baseUrl,
      data: formData,
      onSendProgress: onProgress != null
          ? (sent, total) {
              if (total > 0) onProgress(sent / total);
            }
          : null,
    );

    return response.data['secure_url'] as String;
  }
}
