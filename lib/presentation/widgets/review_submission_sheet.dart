import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/repositories/commerce_repository.dart';
import '../../services/injection_container.dart';

class ReviewSubmissionSheet extends StatefulWidget {
  final String commerceId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final VoidCallback? onReviewSubmitted;

  const ReviewSubmissionSheet({
    super.key,
    required this.commerceId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.onReviewSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required String commerceId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    VoidCallback? onReviewSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewSubmissionSheet(
        commerceId: commerceId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        onReviewSubmitted: onReviewSubmitted,
      ),
    );
  }

  @override
  State<ReviewSubmissionSheet> createState() => _ReviewSubmissionSheetState();
}

class _ReviewSubmissionSheetState extends State<ReviewSubmissionSheet> {
  double _rating = 0;
  final _commentController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Seleccioná una calificación');
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      setState(() => _error = 'Escribí un comentario');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = sl<CommerceRepository>();
    final result = await repo.addReview(
      commerceId: widget.commerceId,
      userId: widget.userId,
      userName: widget.userName,
      userPhotoUrl: widget.userPhotoUrl,
      rating: _rating,
      comment: _commentController.text.trim(),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message.isNotEmpty ? failure.message : 'Error al enviar la reseña';
        _loading = false;
      }),
      (_) {
        Navigator.of(context).pop();
        widget.onReviewSubmitted?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Escribir reseña',
                  style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 40,
                itemBuilder: (_, __) =>
                    const Icon(Icons.star, color: AppColors.gold),
                onRatingUpdate: (r) => setState(() => _rating = r),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLines: 4,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Contá tu experiencia...',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: AppColors.backgroundSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Publicar reseña',
                        style: AppTextStyles.titleSmall
                            .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
