import 'package:equatable/equatable.dart';

class ReviewEntity extends Equatable {
  final String id;
  final String commerceId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final int helpfulCount;
  final String? ownerReply;

  const ReviewEntity({
    required this.id,
    required this.commerceId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.helpfulCount = 0,
    this.ownerReply,
  });

  @override
  List<Object?> get props => [id, commerceId, userId, rating, comment, createdAt];
}
