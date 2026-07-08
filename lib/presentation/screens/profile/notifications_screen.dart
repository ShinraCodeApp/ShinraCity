import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _Notif {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  _Notif({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  factory _Notif.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Notif(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      type: d['type'] as String? ?? '',
      payload: (d['payload'] as Map<String, dynamic>?) ?? {},
      isRead: d['isRead'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_Notif>? _notifications;
  bool _loading = true;
  String? _error;
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state is AuthAuthenticated)
        ? (context.read<AuthBloc>().state as AuthAuthenticated).user
        : null;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snap) => setState(() {
            _notifications = snap.docs.map(_Notif.fromDoc).toList();
            _loading = false;
          }),
          onError: (e) => setState(() {
            _error = e.toString();
            _loading = false;
          }),
        );
  }

  Future<void> _markRead(String userId, _Notif notif) async {
    if (notif.isRead) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notif.id)
        .update({'isRead': true});
    // Stream will push the updated snapshot automatically
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleTap(_Notif notif, String userId) {
    _markRead(userId, notif);
    final payload = notif.payload;
    switch (notif.type) {
      case 'new_promotion':
      case 'nearby_promotion':
        final cid = payload['commerceId'] as String?;
        cid != null ? context.push('/commerce/$cid') : context.go('/map');
        break;
      case 'coupon_expiring':
      case 'coupon_redeemed':
        context.go('/coupons');
        break;
      case 'achievement_unlocked':
      case 'level_up':
      case 'reward':
        context.go('/rewards');
        break;
      case 'commerce_verified':
      case 'plan_expiring':
        context.go('/business');
        break;
      default:
        break;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_promotion':
      case 'nearby_promotion':
        return Icons.local_offer_rounded;
      case 'coupon_expiring':
        return Icons.timer_rounded;
      case 'coupon_redeemed':
        return Icons.qr_code_rounded;
      case 'achievement_unlocked':
        return Icons.emoji_events_rounded;
      case 'level_up':
        return Icons.trending_up_rounded;
      case 'reward':
        return Icons.card_giftcard_rounded;
      case 'plan_expiring':
      case 'commerce_verified':
        return Icons.store_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'achievement_unlocked':
        return AppColors.accent;
      case 'level_up':
        return AppColors.accentGreen;
      case 'new_promotion':
      case 'nearby_promotion':
        return AppColors.secondary;
      case 'coupon_expiring':
        return AppColors.warning;
      case 'coupon_redeemed':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = (context.read<AuthBloc>().state is AuthAuthenticated)
        ? (context.read<AuthBloc>().state as AuthAuthenticated).user
        : null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundCard : Colors.white,
        elevation: 0,
        title: Text(
          'Notificaciones',
          style: TextStyle(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_notifications != null && _notifications!.any((n) => !n.isRead) && user != null)
            TextButton(
              onPressed: () => _markAllRead(user.id),
              child: const Text('Marcar todas', style: TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
      body: _buildBody(isDark, user?.id ?? ''),
    );
  }

  Future<void> _markAllRead(String userId) async {
    if (_notifications == null) return;
    final unread = _notifications!.where((n) => !n.isRead).toList();
    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications');
    for (final n in unread) {
      batch.update(col.doc(n.id), {'isRead': true});
    }
    await batch.commit();
    // Stream will push the updated snapshot automatically
  }

  Widget _buildBody(bool isDark, String userId) {
    if (_loading) return _buildShimmer(isDark);
    if (_error != null) return _buildError();
    if (_notifications == null || _notifications!.isEmpty) return _buildEmpty(isDark);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _notifications!.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        indent: 72,
      ),
      itemBuilder: (context, i) {
        final notif = _notifications![i];
        return _buildTile(notif, isDark, userId)
            .animate()
            .fadeIn(delay: Duration(milliseconds: i * 40), duration: 250.ms);
      },
    );
  }

  Widget _buildTile(_Notif notif, bool isDark, String userId) {
    final color = _colorFor(notif.type);
    final icon = _iconFor(notif.type);
    final bg = isDark ? AppColors.backgroundCard : Colors.white;
    final unreadBg = isDark
        ? AppColors.backgroundCard.withValues(alpha: 0.95)
        : AppColors.primary.withValues(alpha: 0.04);

    return Material(
      color: notif.isRead ? bg : unreadBg,
      child: InkWell(
        onTap: () => _handleTap(notif, userId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notif.createdAt, locale: 'es'),
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer(bool isDark) {
    final base = isDark ? AppColors.backgroundSurface : Colors.grey.shade200;
    final highlight = isDark ? AppColors.backgroundCard : Colors.grey.shade100;
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(height: 12, width: 200, color: Colors.white),
                    const SizedBox(height: 4),
                    Container(height: 10, width: 80, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 72,
              color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                  .withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Sin notificaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando haya novedades aparecerán aquí',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('No se pudieron cargar las notificaciones'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => setState(() { _loading = true; _error = null; }), child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
