import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../core/router/app_router.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'shinra_city_promos_v2';
  static const _channelName = 'ShinraCity Promociones';
  static const _channelDescription = 'Notificaciones de ShinraCity';

  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
            playSound: true,
            enableLights: true,
            ledColor: Color(0xFF00D4FF),
          ),
        );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Small delay so GoRouter is fully initialized before navigating
      await Future.delayed(const Duration(milliseconds: 500));
      _handleNotificationTap(initialMessage);
    }
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF00D4FF),
          largeIcon: notification.android?.imageUrl != null
              ? FilePathAndroidBitmap(notification.android!.imageUrl!)
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _buildPayload(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split(':');
    _navigateFromData({
      'type': parts[0],
      if (parts.length > 1) 'id': parts[1],
    });
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    try {
      final router = AppRouter.instance;
      switch (type) {
        case 'new_promotion':
        case 'nearby_promotion':
          id != null ? router.push('/commerce/$id') : router.go('/map');
          break;
        case 'coupon_expiring':
        case 'coupon_redeemed':
          router.go('/coupons');
          break;
        case 'achievement':
        case 'level_up':
        case 'reward':
          router.go('/rewards');
          break;
        case 'commerce_verified':
        case 'plan_expiring':
          router.go('/business');
          break;
        default:
          router.go('/map');
      }
    } catch (_) {
      // Router not yet initialized (cold start) — handled by initialMessage delay
    }
  }

  String _buildPayload(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final id = data['id'] ?? '';
    return id.isNotEmpty ? '$type:$id' : type;
  }

  Future<void> cancelNotification(int id) => _localNotifications.cancel(id);

  Future<void> cancelAllNotifications() => _localNotifications.cancelAll();
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler — Firebase handles display automatically
}
