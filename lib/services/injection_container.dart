import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/datasources/firebase/firebase_auth_datasource.dart';
import '../data/datasources/firebase/firebase_commerce_datasource.dart';
import '../data/datasources/firebase/firebase_coupon_datasource.dart';
import '../data/datasources/firebase/firebase_points_datasource.dart';
import '../data/datasources/firebase/firebase_promotion_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/commerce_repository_impl.dart';
import '../data/repositories/coupon_repository_impl.dart';
import '../data/repositories/points_repository_impl.dart';
import '../data/repositories/promotion_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/commerce_repository.dart';
import '../domain/repositories/coupon_repository.dart';
import '../domain/repositories/points_repository.dart';
import '../domain/repositories/promotion_repository.dart';
import '../presentation/blocs/auth/auth_bloc.dart';
import '../presentation/blocs/commerce/commerce_bloc.dart';
import '../presentation/blocs/coupons/coupons_bloc.dart';
import '../presentation/blocs/map/map_bloc.dart';
import '../presentation/blocs/points/points_bloc.dart';
import '../presentation/blocs/promotions/promotions_bloc.dart';
import 'analytics_service.dart';
import 'image_upload_service.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Firebase singletons
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  sl.registerLazySingleton<FirebaseAnalytics>(() => FirebaseAnalytics.instance);
  sl.registerLazySingleton<FirebaseMessaging>(() => FirebaseMessaging.instance);
  sl.registerLazySingleton<GoogleSignIn>(
    () => GoogleSignIn(scopes: ['email', 'profile']),
  );

  // Services
  sl.registerLazySingleton<AnalyticsService>(
    () => AnalyticsService(analytics: sl()),
  );

  sl.registerLazySingleton<ImageUploadService>(
    () => ImageUploadService(storage: sl()),
  );

  // Datasources
  sl.registerLazySingleton<FirebaseAuthDatasource>(
    () => FirebaseAuthDatasource(
      auth: sl(),
      firestore: sl(),
      googleSignIn: sl(),
    ),
  );

  sl.registerLazySingleton<FirebaseCommerceDatasource>(
    () => FirebaseCommerceDatasource(
      firestore: sl(),
      storage: sl(),
    ),
  );

  sl.registerLazySingleton<FirebaseCouponDatasource>(
    () => FirebaseCouponDatasource(firestore: sl()),
  );

  sl.registerLazySingleton<FirebasePromotionDatasource>(
    () => FirebasePromotionDatasource(
      firestore: sl(),
      storage: sl(),
    ),
  );

  sl.registerLazySingleton<FirebasePointsDatasource>(
    () => FirebasePointsDatasource(firestore: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      datasource: sl(),
      firestore: sl(),
    ),
  );

  sl.registerLazySingleton<CommerceRepository>(
    () => CommerceRepositoryImpl(
      datasource: sl(),
      auth: sl(),
    ),
  );

  sl.registerLazySingleton<CouponRepository>(
    () => CouponRepositoryImpl(
      datasource: sl(),
      auth: sl(),
    ),
  );

  sl.registerLazySingleton<PromotionRepository>(
    () => PromotionRepositoryImpl(datasource: sl()),
  );

  sl.registerLazySingleton<PointsRepository>(
    () => PointsRepositoryImpl(datasource: sl()),
  );

  // BLoCs — factories so each caller gets a fresh instance
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: sl(), analytics: sl()),
  );

  sl.registerFactory<MapBloc>(
    () => MapBloc(
      commerceRepository: sl(),
      promotionRepository: sl(),
    ),
  );

  sl.registerFactory<PromotionsBloc>(
    () => PromotionsBloc(repository: sl(), analytics: sl()),
  );

  sl.registerFactoryParam<CommerceBloc, String, void>(
    (userId, _) => CommerceBloc(
      commerceRepository: sl(),
      userId: userId,
      analytics: sl(),
    ),
  );

  sl.registerFactoryParam<CouponsBloc, String, void>(
    (userId, _) => CouponsBloc(
      couponRepository: sl(),
      userId: userId,
      analytics: sl(),
    ),
  );

  sl.registerFactoryParam<PointsBloc, String, void>(
    (userId, _) => PointsBloc(
      repository: sl(),
      userId: userId,
      analytics: sl(),
    ),
  );
}
