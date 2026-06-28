class AppConstants {
  AppConstants._();

  static const String appName = 'ShinraCity';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String commercesCollection = 'commerces';
  static const String promotionsCollection = 'promotions';
  static const String couponsCollection = 'coupons';
  static const String pointsCollection = 'points';
  static const String rewardsCollection = 'rewards';
  static const String achievementsCollection = 'achievements';
  static const String categoriesCollection = 'categories';
  static const String notificationsCollection = 'notifications';
  static const String reviewsCollection = 'reviews';
  static const String branchesCollection = 'branches';
  static const String employeesCollection = 'employees';
  static const String transactionsCollection = 'transactions';
  static const String plansCollection = 'plans';
  static const String analyticsCollection = 'analytics';
  static const String auditLogsCollection = 'audit_logs';
  static const String geohashesCollection = 'geohashes';

  // Map Constants
  static const double defaultLatitude = -34.6037;
  static const double defaultLongitude = -58.3816;
  static const double defaultZoom = 14.0;
  static const double nearbyRadiusKm = 5.0;
  static const double maxRadiusKm = 50.0;
  static const int geohashPrecision = 7;
  static const double clusterRadius = 100.0;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Timeouts
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Cache
  static const int cacheMaxAge = 7;
  static const int imageCacheDays = 30;

  // Gamification
  static const int pointsPerCouponRedeemed = 10;
  static const int pointsPerFirstVisit = 50;
  static const int pointsPerReview = 20;
  static const int pointsPerReferral = 100;

  // Level thresholds
  static const Map<String, int> levelThresholds = {
    'explorer': 0,
    'frequent': 500,
    'exemplary': 2000,
    'ambassador': 5000,
    'lifetime': 15000,
  };

  // Coupon
  static const int couponDefaultExpirationDays = 30;
  static const int maxCouponsPerPromotion = 1000;
  static const int maxActiveCouponsPerUser = 20;

  // Plans limits
  static const Map<String, int> planPromotionLimits = {
    'free': 2,
    'basic': -1,
    'premium': -1,
    'enterprise': -1,
  };

  // Geofencing
  static const double geofenceRadiusMeters = 200.0;
  static const int geofenceNotificationCooldownMinutes = 60;

  // API Endpoints
  static const String stripeBaseUrl = 'https://api.stripe.com/v1';
  static const String mercadopagoBaseUrl = 'https://api.mercadopago.com';

  // Storage Paths
  static const String userAvatarsPath = 'users/avatars';
  static const String commerceLogosPath = 'commerces/logos';
  static const String commerceGalleryPath = 'commerces/gallery';
  static const String promotionImagesPath = 'promotions/images';
  static const String rewardImagesPath = 'rewards/images';

  // Regex
  static const String phoneRegex = r'^\+?[1-9]\d{1,14}$';
  static const String urlRegex = r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)$';

  // Encryption
  static const String encryptionAlgorithm = 'AES';
  static const int keyLength = 256;
}
