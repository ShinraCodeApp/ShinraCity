import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Sin conexión a internet', super.code});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

class PermissionFailure extends Failure {
  const PermissionFailure({super.message = 'Permiso denegado', super.code});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Recurso no encontrado', super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Error de caché', super.code});
}

class LocationFailure extends Failure {
  const LocationFailure({super.message = 'Error de geolocalización', super.code});
}

class CouponFailure extends Failure {
  const CouponFailure({required super.message, super.code});
}

class PaymentFailure extends Failure {
  const PaymentFailure({required super.message, super.code});
}

class FraudDetectedFailure extends Failure {
  const FraudDetectedFailure({super.message = 'Actividad sospechosa detectada', super.code});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'No autorizado', super.code});
}

class PlanLimitFailure extends Failure {
  const PlanLimitFailure({super.message = 'Límite del plan alcanzado', super.code});
}
