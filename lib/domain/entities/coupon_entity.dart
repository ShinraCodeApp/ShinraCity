import 'package:equatable/equatable.dart';

enum CouponStatus {
  available,
  reserved,
  used,
  expired,
  cancelled,
}

class CouponEntity extends Equatable {
  final String id;
  final String userId;
  final String commerceId;
  final String commerceName;
  final String promotionId;
  final String promotionTitle;
  final String token;
  final String qrData;
  final String checksum;
  final CouponStatus status;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final String? usedByEmployeeId;
  final String? usedAtBranchId;
  final double? savedAmount;
  final int? pointsEarned;
  final String deviceFingerprint;
  final Map<String, dynamic> metadata;

  const CouponEntity({
    required this.id,
    required this.userId,
    required this.commerceId,
    required this.commerceName,
    required this.promotionId,
    required this.promotionTitle,
    required this.token,
    required this.qrData,
    required this.checksum,
    this.status = CouponStatus.available,
    required this.issuedAt,
    required this.expiresAt,
    this.usedAt,
    this.usedByEmployeeId,
    this.usedAtBranchId,
    this.savedAmount,
    this.pointsEarned,
    required this.deviceFingerprint,
    this.metadata = const {},
  });

  bool get isValid =>
      status == CouponStatus.available &&
      DateTime.now().isBefore(expiresAt);

  bool get isExpired =>
      status == CouponStatus.expired ||
      (status == CouponStatus.available && DateTime.now().isAfter(expiresAt));

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  String get statusDisplayName {
    switch (status) {
      case CouponStatus.available: return 'Disponible';
      case CouponStatus.reserved: return 'Reservado';
      case CouponStatus.used: return 'Utilizado';
      case CouponStatus.expired: return 'Expirado';
      case CouponStatus.cancelled: return 'Cancelado';
    }
  }

  CouponEntity copyWith({
    CouponStatus? status,
    DateTime? usedAt,
    String? usedByEmployeeId,
    String? usedAtBranchId,
    double? savedAmount,
    int? pointsEarned,
  }) {
    return CouponEntity(
      id: id,
      userId: userId,
      commerceId: commerceId,
      commerceName: commerceName,
      promotionId: promotionId,
      promotionTitle: promotionTitle,
      token: token,
      qrData: qrData,
      checksum: checksum,
      status: status ?? this.status,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      usedAt: usedAt ?? this.usedAt,
      usedByEmployeeId: usedByEmployeeId ?? this.usedByEmployeeId,
      usedAtBranchId: usedAtBranchId ?? this.usedAtBranchId,
      savedAmount: savedAmount ?? this.savedAmount,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      deviceFingerprint: deviceFingerprint,
      metadata: metadata,
    );
  }

  @override
  List<Object?> get props => [id, userId, promotionId, status, issuedAt];
}
