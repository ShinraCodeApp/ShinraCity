import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService({required FirebaseAnalytics analytics})
      : _analytics = analytics;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // Auth events
  Future<void> logSignUp({required String method}) =>
      _analytics.logSignUp(signUpMethod: method);

  Future<void> logLogin({required String method}) =>
      _analytics.logLogin(loginMethod: method);

  // Commerce events
  Future<void> logViewCommerce({
    required String commerceId,
    required String commerceName,
    required String category,
  }) =>
      _analytics.logEvent(
        name: 'view_commerce',
        parameters: {
          'commerce_id': commerceId,
          'commerce_name': commerceName,
          'category': category,
        },
      );

  Future<void> logFollowCommerce({required String commerceId}) =>
      _analytics.logEvent(
        name: 'follow_commerce',
        parameters: {'commerce_id': commerceId},
      );

  Future<void> logSearchCommerce({required String query}) =>
      _analytics.logSearch(searchTerm: query);

  // Promotion events
  Future<void> logViewPromotion({
    required String promotionId,
    required String promotionTitle,
    required String commerceId,
    required String type,
  }) =>
      _analytics.logViewPromotion(
        promotionId: promotionId,
        promotionName: promotionTitle,
        creativeName: type,
        creativeSlot: commerceId,
      );

  Future<void> logClaimCoupon({
    required String promotionId,
    required String commerceId,
    required String promotionType,
    double? discountValue,
  }) =>
      _analytics.logEvent(
        name: 'claim_coupon',
        parameters: {
          'promotion_id': promotionId,
          'commerce_id': commerceId,
          'promotion_type': promotionType,
          if (discountValue != null) 'discount_value': discountValue,
        },
      );

  Future<void> logRedeemCoupon({
    required String couponId,
    required String commerceId,
  }) =>
      _analytics.logEvent(
        name: 'redeem_coupon',
        parameters: {
          'coupon_id': couponId,
          'commerce_id': commerceId,
        },
      );

  // Gamification events
  Future<void> logLevelUp({
    required String newLevel,
    required int totalPoints,
  }) =>
      _analytics.logLevelUp(level: totalPoints, character: newLevel);

  Future<void> logAchievementUnlocked({required String achievementId}) =>
      _analytics.logEarnVirtualCurrency(
        virtualCurrencyName: 'achievement',
        value: 1,
      );

  Future<void> logRewardRedeemed({
    required String rewardId,
    required int pointsCost,
  }) =>
      _analytics.logSpendVirtualCurrency(
        itemName: rewardId,
        virtualCurrencyName: 'points',
        value: pointsCost,
      );

  // Map events
  Future<void> logMapOpen({required double lat, required double lon}) =>
      _analytics.logEvent(
        name: 'open_map',
        parameters: {'lat': lat, 'lon': lon},
      );

  Future<void> logFilterApplied({required String category}) =>
      _analytics.logEvent(
        name: 'filter_applied',
        parameters: {'category': category},
      );

  // Business events
  Future<void> logCreatePromotion({
    required String commerceId,
    required String type,
    double? discountValue,
  }) =>
      _analytics.logEvent(
        name: 'create_promotion',
        parameters: {
          'commerce_id': commerceId,
          'type': type,
          if (discountValue != null) 'discount_value': discountValue,
        },
      );

  Future<void> logUpgradePlan({
    required String commerceId,
    required String fromPlan,
    required String toPlan,
  }) =>
      _analytics.logEvent(
        name: 'upgrade_plan',
        parameters: {
          'commerce_id': commerceId,
          'from_plan': fromPlan,
          'to_plan': toPlan,
        },
      );

  // Payment events
  Future<void> logPurchase({
    required String commerceId,
    required String plan,
    required double amount,
    required String currency,
    required String paymentMethod,
  }) =>
      _analytics.logPurchase(
        currency: currency,
        value: amount,
        items: [
          AnalyticsEventItem(
            itemId: commerceId,
            itemName: plan,
          ),
        ],
      );

  // User properties
  Future<void> setUserLevel(String level) =>
      _analytics.setUserProperty(name: 'user_level', value: level);

  Future<void> setUserCity(String city) =>
      _analytics.setUserProperty(name: 'city', value: city);

  Future<void> setAccountType(String type) =>
      _analytics.setUserProperty(name: 'account_type', value: type);
}
