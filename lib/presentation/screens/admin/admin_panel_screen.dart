import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/commerce_entity.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
              ),
              child: Text(
                'ADMIN',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Panel de Control',
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Comercios'),
            Tab(text: 'Usuarios'),
            Tab(text: 'Precios'),
            Tab(text: 'Fraude'),
            Tab(text: 'Moderación'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          labelStyle: AppTextStyles.titleSmall,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboard(),
          _buildCommercesTab(),
          _buildUsersTab(),
          _buildPricesTab(),
          _buildFraudTab(),
          _buildModerationTab(),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 20),
          _buildPendingCommerces(),
          const SizedBox(height: 20),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatStream(
          label: 'Usuarios',
          icon: Icons.people_outline,
          color: AppColors.primary,
          stream: _db.collection(AppConstants.usersCollection)
              .snapshots()
              .map((s) => s.size),
        ),
        _buildStatStream(
          label: 'Comercios',
          icon: Icons.storefront_outlined,
          color: AppColors.secondary,
          stream: _db.collection(AppConstants.commercesCollection)
              .where('status', isEqualTo: 'active')
              .snapshots()
              .map((s) => s.size),
        ),
        _buildStatStream(
          label: 'Promos activas',
          icon: Icons.local_offer_outlined,
          color: AppColors.success,
          stream: _db.collection(AppConstants.promotionsCollection)
              .where('status', isEqualTo: 'active')
              .snapshots()
              .map((s) => s.size),
        ),
        _buildStatStream(
          label: 'Pendientes',
          icon: Icons.pending_outlined,
          color: AppColors.warning,
          stream: _db.collection(AppConstants.commercesCollection)
              .where('status', isEqualTo: 'pending')
              .snapshots()
              .map((s) => s.size),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildStatStream({
    required String label,
    required IconData icon,
    required Color color,
    required Stream<int> stream,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.hasData ? '${snapshot.data}' : '--',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingCommerces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comercios pendientes de verificación',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection(AppConstants.commercesCollection)
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              return _buildEmptyCard('Sin comercios pendientes');
            }
            return Column(
              children: snapshot.data!.docs
                  .map((doc) => _buildPendingCommerceCard(doc))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPendingCommerceCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront, color: AppColors.textSecondaryDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Sin nombre',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
                Text(
                  data['address'] ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _actionBtn(
                icon: Icons.check,
                color: AppColors.success,
                onTap: () => _verifyCommerce(doc.id, true),
              ),
              const SizedBox(width: 6),
              _actionBtn(
                icon: Icons.close,
                color: AppColors.error,
                onTap: () => _verifyCommerce(doc.id, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actividad reciente',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('audit_logs')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              return _buildEmptyCard('Sin actividad registrada');
            }
            return Column(
              children: snapshot.data!.docs
                  .map((doc) => _buildActivityTile(doc))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final action = data['action'] as String? ?? 'action';
    final ts = data['timestamp'] as Timestamp?;
    final time = ts != null
        ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _actionLabel(action),
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
            ),
          ),
          Text(
            time,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommercesTab() {
    return Stack(
      children: [
        Column(
          children: [
            _buildSearchBar('Buscar comercio...'),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection(AppConstants.commercesCollection)
                    .orderBy('createdAt', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return _buildLoader();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (_, i) =>
                        _buildCommerceAdminCard(snapshot.data!.docs[i]),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _showCreateCommerceSheet(context),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_business, color: Colors.black),
            label: Text(
              'Crear Negocio',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommerceAdminCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'pending';
    final statusColors = {
      'active': AppColors.success,
      'pending': AppColors.warning,
      'suspended': AppColors.error,
      'rejected': AppColors.error,
    };
    final statusColor = statusColors[status] ?? AppColors.textSecondaryDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Sin nombre',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
                Text(
                  data['plan'] ?? 'free',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: AppTextStyles.labelSmall.copyWith(color: statusColor),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondaryDark, size: 18),
            color: AppColors.backgroundCard,
            onSelected: (action) => _handleCommerceAction(doc.id, action),
            itemBuilder: (_) => [
              if (status == 'pending')
                const PopupMenuItem(value: 'verify', child: Text('Verificar')),
              if (status == 'active')
                const PopupMenuItem(value: 'suspend', child: Text('Suspender')),
              if (status == 'suspended')
                const PopupMenuItem(value: 'reactivate', child: Text('Reactivar')),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }

  final _userSearchCtrl = TextEditingController();
  String _userSearchQuery = '';

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _userSearchCtrl,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            onChanged: (v) => setState(() => _userSearchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o email...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondaryDark),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textSecondaryDark),
                      onPressed: () {
                        _userSearchCtrl.clear();
                        setState(() => _userSearchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection(AppConstants.usersCollection)
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _buildLoader();
              final docs = snapshot.data!.docs.where((doc) {
                if (_userSearchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['displayName'] as String? ?? '').toLowerCase();
                final email = (data['email'] as String? ?? '').toLowerCase();
                return name.contains(_userSearchQuery) ||
                    email.contains(_userSearchQuery);
              }).toList();
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'Sin resultados',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) => _buildUserAdminCard(docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserAdminCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final role = data['role'] as String? ?? 'user';
    final isActive = data['isActive'] as bool? ?? true;
    final email = data['email'] as String? ?? '';
    final name = data['displayName'] as String? ?? 'Usuario';
    final photoUrl = data['photoUrl'] as String?;
    final totalPoints = data['totalPoints'] as int? ?? 0;
    final level = data['level'] as String? ?? 'explorer';
    final isSuspended = data['isSuspended'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSuspended
              ? AppColors.error.withValues(alpha: 0.4)
              : role == 'admin' || role == 'superAdmin'
                  ? AppColors.secondary.withValues(alpha: 0.3)
                  : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.backgroundSurface,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _roleColor(role).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role,
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: _roleColor(role),
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 12, color: AppColors.textSecondaryDark),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email.isEmpty ? 'Sin email' : email,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondaryDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '⭐ $totalPoints pts  ·  $level',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          if (isSuspended) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SUSPENDIDO',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.error, fontSize: 9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textSecondaryDark, size: 20),
                  color: AppColors.backgroundCard,
                  onSelected: (action) => _handleUserAction(doc.id, action, email: email),
                  itemBuilder: (_) => [
                    if (email.isNotEmpty) ...[
                      PopupMenuItem(
                        value: 'copy_email',
                        child: Row(children: [
                          const Icon(Icons.copy, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text('Copiar email',
                              style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'send_email',
                        child: Row(children: [
                          const Icon(Icons.email, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text('Enviar email',
                              style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                    ],
                    PopupMenuItem(
                      value: 'send_notification',
                      child: Row(children: [
                        const Icon(Icons.notifications_outlined,
                            size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Text('Enviar notificación',
                            style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    if (isActive)
                      PopupMenuItem(
                        value: 'suspend',
                        child: Row(children: [
                          const Icon(Icons.block, size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Text('Suspender',
                              style: TextStyle(color: Colors.white)),
                        ]),
                      )
                    else
                      PopupMenuItem(
                        value: 'reactivate',
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text('Reactivar',
                              style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                    if (role != 'admin' && role != 'superAdmin')
                      PopupMenuItem(
                        value: 'make_admin',
                        child: Row(children: [
                          const Icon(Icons.admin_panel_settings,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text('Hacer admin',
                              style: TextStyle(color: Colors.white)),
                        ]),
                      )
                    else if (role == 'admin')
                      PopupMenuItem(
                        value: 'remove_admin',
                        child: Row(children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: AppColors.textSecondaryDark),
                          const SizedBox(width: 8),
                          Text('Quitar admin',
                              style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricesTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('config').doc('plans').snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        return _PricesEditor(db: _db, currentData: data);
      },
    );
  }

  Widget _buildFraudTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('fraud_flags')
          .where('reviewed', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoader();
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 56, color: AppColors.success),
                const SizedBox(height: 16),
                Text(
                  'Sin alertas de fraude',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (_, i) => _buildFraudCard(snapshot.data!.docs[i]),
        );
      },
    );
  }

  Widget _buildFraudCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['type'] ?? 'fraud_flag',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                data['date'] as String? ?? '',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Usuario: ${data['userId'] ?? 'N/A'}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
          ),
          if (data['count'] != null)
            Text(
              'Cantidad: ${data['count']}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _markFraudReviewed(doc.id),
                child: Text(
                  'Marcar revisado',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _suspendFraudUser(data['userId']),
                child: Text(
                  'Suspender usuario',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModerationTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('moderation_queue')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoader();
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 56, color: AppColors.success),
                const SizedBox(height: 16),
                Text(
                  'Cola de moderación vacía',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (_, i) => _buildModerationCard(snapshot.data!.docs[i]),
        );
      },
    );
  }

  Widget _buildModerationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'content';
    final reason = data['reportReason'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ID: ${data['targetId'] ?? ''}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Motivo: $reason',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _resolveModeration(doc.id, 'approved'),
                child: Text(
                  'Aprobar',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _resolveModeration(doc.id, 'removed'),
                child: Text(
                  'Eliminar',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(String hint) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondaryDark),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  }

  Color _roleColor(String role) {
    const colors = {
      'superAdmin': AppColors.error,
      'admin': AppColors.secondary,
      'businessOwner': AppColors.primary,
      'employee': AppColors.success,
      'user': AppColors.textSecondaryDark,
    };
    return colors[role] ?? AppColors.textSecondaryDark;
  }

  String _actionLabel(String action) {
    const labels = {
      'user_suspended': 'Usuario suspendido',
      'commerce_verified': 'Comercio verificado',
      'commerce_suspended': 'Comercio suspendido',
      'plan_activated': 'Plan activado',
      'moderation_approved': 'Contenido aprobado',
      'moderation_removed': 'Contenido eliminado',
      'role_assigned': 'Rol asignado',
    };
    return labels[action] ?? action.replaceAll('_', ' ');
  }

  Future<void> _verifyCommerce(String id, bool approve) async {
    await _db.collection(AppConstants.commercesCollection).doc(id).update({
      'status': approve ? 'active' : 'rejected',
      'verifiedAt': approve ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('audit_logs').add({
      'action': approve ? 'commerce_verified' : 'commerce_rejected',
      'targetId': id,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _handleCommerceAction(String id, String action) async {
    final Map<String, String> statusMap = {
      'verify': 'active',
      'suspend': 'suspended',
      'reactivate': 'active',
    };
    if (action == 'delete') {
      final ok = await _checkAdminGate(context);
      if (!ok) return;
      await _db.collection(AppConstants.commercesCollection).doc(id).delete();
      await _db.collection('audit_logs').add({
        'action': 'commerce_deleted',
        'targetId': id,
        'adminUid': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comercio eliminado'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (statusMap.containsKey(action)) {
      await _db.collection(AppConstants.commercesCollection).doc(id).update({
        'status': statusMap[action],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> _checkAdminGate(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AdminGateDialog(),
    ) ?? false;
  }

  void _showCreateCommerceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateCommerceSheet(db: _db),
    );
  }

  Future<void> _handleUserAction(String id, String action, {String email = ''}) async {
    switch (action) {
      case 'suspend':
        await _db.collection(AppConstants.usersCollection).doc(id).update({
          'isActive': false,
          'isSuspended': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      case 'reactivate':
        await _db.collection(AppConstants.usersCollection).doc(id).update({
          'isActive': true,
          'isSuspended': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      case 'make_admin':
        await _db.collection(AppConstants.usersCollection).doc(id).update({
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      case 'remove_admin':
        await _db.collection(AppConstants.usersCollection).doc(id).update({
          'role': 'user',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      case 'copy_email':
        if (email.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: email));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📋 Email copiado: $email'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      case 'send_email':
        if (email.isNotEmpty) {
          final uri = Uri.parse('mailto:$email');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        }
      case 'send_notification':
        _showSendNotificationDialog(id);
    }
  }

  void _showSendNotificationDialog(String userId) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '🔔 Enviar notificación',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Mensaje'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondaryDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.black),
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              await _db
                  .collection(AppConstants.usersCollection)
                  .doc(userId)
                  .collection('notifications')
                  .add({
                'title': titleCtrl.text.trim(),
                'body': bodyCtrl.text.trim(),
                'type': 'admin_message',
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Notificación enviada'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _markFraudReviewed(String id) async {
    await _db.collection('fraud_flags').doc(id).update({'reviewed': true});
  }

  Future<void> _suspendFraudUser(String? userId) async {
    if (userId == null) return;
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'isActive': false,
      'isSuspended': true,
      'suspensionReason': 'Actividad fraudulenta detectada',
      'suspendedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('audit_logs').add({
      'action': 'user_suspended',
      'targetId': userId,
      'reason': 'Actividad fraudulenta',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _resolveModeration(String id, String resolution) async {
    await _db.collection('moderation_queue').doc(id).update({
      'status': resolution,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('audit_logs').add({
      'action': 'moderation_$resolution',
      'targetId': id,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

// ── Prices Editor ─────────────────────────────────────────────────────────────

class _PricesEditor extends StatefulWidget {
  final FirebaseFirestore db;
  final Map<String, dynamic>? currentData;
  const _PricesEditor({required this.db, this.currentData});

  @override
  State<_PricesEditor> createState() => _PricesEditorState();
}

class _PricesEditorState extends State<_PricesEditor> {
  static const _plans = [
    ('basic', '⭐ Básico', AppColors.primary),
    ('premium', '🚀 Premium', AppColors.gold),
    ('enterprise', '🏢 Empresarial', AppColors.secondary),
  ];

  late Map<String, TextEditingController> _monthly;
  late Map<String, TextEditingController> _annual;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _monthly = {};
    _annual = {};
    for (final p in _plans) {
      final plan = p.$1;
      final planData = widget.currentData?[plan] as Map<String, dynamic>? ?? {};
      _monthly[plan] = TextEditingController(
        text: (planData['monthly'] ?? _defaults[plan]!['monthly']).toString(),
      );
      _annual[plan] = TextEditingController(
        text: (planData['annual'] ?? _defaults[plan]!['annual']).toString(),
      );
    }
  }

  static const _defaults = {
    'basic': {'monthly': 2990, 'annual': 2392},
    'premium': {'monthly': 5990, 'annual': 4792},
    'enterprise': {'monthly': 14990, 'annual': 11992},
  };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{};
      for (final p in _plans) {
        final plan = p.$1;
        data[plan] = {
          'monthly': int.tryParse(_monthly[plan]!.text) ?? 0,
          'annual': int.tryParse(_annual[plan]!.text) ?? 0,
          'name': plan == 'basic'
              ? 'Básico'
              : plan == 'premium'
                  ? 'Premium'
                  : 'Empresarial',
        };
      }
      data['updatedAt'] = FieldValue.serverTimestamp();
      await widget.db.collection('config').doc('plans').set(data, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Precios actualizados'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [..._monthly.values, ..._annual.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '💰 Precios de planes',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Los precios se reflejan automáticamente en la pantalla de planes.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 20),
          ..._plans.map((p) => _buildPlanCard(p.$1, p.$2, p.$3)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String plan, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  plan.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mensual (ARS)',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _monthly[plan],
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: color.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: color),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Anual (ARS)',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-20%',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.success,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _annual[plan],
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: color.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: color),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Admin Gate Dialog ──────────────────────────────────────────────────────────

class _AdminGateDialog extends StatefulWidget {
  const _AdminGateDialog();

  @override
  State<_AdminGateDialog> createState() => _AdminGateDialogState();
}

class _AdminGateDialogState extends State<_AdminGateDialog> {
  final _ctrl = TextEditingController();
  final _auth = LocalAuthentication();
  bool _obscure = true;
  String? _error;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final available = await _auth.canCheckBiometrics;
      if (mounted) setState(() => _biometricAvailable = available);
    } catch (_) {}
  }

  Future<void> _tryBiometric() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para continuar',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _error = 'Biometría no disponible');
    }
  }

  void _checkPassword() {
    if (_ctrl.text == 'ShinraSakujo') {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Contraseña incorrecta');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.security, color: AppColors.error),
          const SizedBox(width: 8),
          Text(
            'Acceso Admin',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_biometricAvailable) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Usar huella digital'),
                onPressed: _tryBiometric,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFF1E293B))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'o',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFF1E293B))),
                ],
              ),
            ),
          ],
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _checkPassword(),
            decoration: InputDecoration(
              hintText: 'Contraseña de admin',
              hintStyle: TextStyle(color: AppColors.textSecondaryDark),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondaryDark,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              errorText: _error,
              errorStyle: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
          ),
          onPressed: _checkPassword,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

// ── Create Commerce Sheet ──────────────────────────────────────────────────────

class _CreateCommerceSheet extends StatefulWidget {
  final FirebaseFirestore db;
  const _CreateCommerceSheet({required this.db});

  @override
  State<_CreateCommerceSheet> createState() => _CreateCommerceSheetState();
}

class _CreateCommerceSheetState extends State<_CreateCommerceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _lat = TextEditingController(text: '-34.6037');
  final _lng = TextEditingController(text: '-58.3816');

  CommerceCategory _category = CommerceCategory.restaurants;
  bool _saving = false;

  static const _categories = [
    (CommerceCategory.restaurants, '🍽️ Restaurante'),
    (CommerceCategory.cafes, '☕ Cafetería'),
    (CommerceCategory.fastFood, '🍔 Comida Rápida'),
    (CommerceCategory.bar, '🍺 Bar / Pub'),
    (CommerceCategory.bakery, '🥐 Panadería'),
    (CommerceCategory.pharmacies, '💊 Farmacia'),
    (CommerceCategory.health, '🏥 Salud'),
    (CommerceCategory.beauty, '💄 Belleza'),
    (CommerceCategory.clothing, '👕 Ropa'),
    (CommerceCategory.supermarket, '🛒 Supermercado'),
    (CommerceCategory.hardware, '🔩 Ferretería'),
    (CommerceCategory.jewelry, '💎 Joyería'),
    (CommerceCategory.market, '🏪 Feria / Mercado'),
    (CommerceCategory.streetVendor, '🛍️ Vendedor Ambulante'),
    (CommerceCategory.entrepreneur, '🚀 Emprendimiento'),
    (CommerceCategory.artisans, '🎨 Artesanos'),
    (CommerceCategory.services, '🔧 Servicios'),
    (CommerceCategory.automotive, '🚗 Automotriz'),
    (CommerceCategory.education, '📚 Educación'),
    (CommerceCategory.technology, '💻 Tecnología'),
    (CommerceCategory.entertainment, '🎭 Entretenimiento'),
    (CommerceCategory.sports, '⚽ Deportes'),
    (CommerceCategory.tourism, '✈️ Turismo'),
    (CommerceCategory.pets, '🐾 Mascotas'),
    (CommerceCategory.other, '📦 Otros'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final lat = double.tryParse(_lat.text) ?? -34.6037;
      final lng = double.tryParse(_lng.text) ?? -58.3816;
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      await widget.db.collection(AppConstants.commercesCollection).add({
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'category': _category.name,
        'subCategories': [],
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'country': 'Argentina',
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'email': null,
        'website': null,
        'location': GeoPoint(lat, lng),
        'geohash': '',
        'logoUrl': null,
        'galleryUrls': [],
        'socialLinks': {},
        'businessHours': {},
        'tags': [],
        'status': 'active',
        'plan': 'basic',
        'ownerId': adminUid,
        'rating': 0.0,
        'reviewCount': 0,
        'followerCount': 0,
        'activePromotionsCount': 0,
        'isCurrentlyOpen': true,
        'hasActivePromotion': false,
        'isVerified': true,
        'isFeatured': false,
        'pointsConfig': {},
        'authorizedEmployeeIds': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${_name.text.trim()}" creado con éxito'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = true, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_business, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Crear Nuevo Negocio',
                    style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _field(_name, '🏷️ Nombre del negocio'),
              _field(_description, '📝 Descripción'),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<CommerceCategory>(
                  initialValue: _category,
                  dropdownColor: AppColors.backgroundCard,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: '🗂️ Categoría'),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c.$1,
                            child: Text(c.$2, style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
              _field(_address, '📍 Dirección'),
              _field(_city, '🌆 Ciudad'),
              _field(_phone, '📱 Teléfono (opcional)', required: false,
                  keyboard: TextInputType.phone),
              Row(
                children: [
                  Expanded(child: _field(_lat, '🌐 Latitud',
                      keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_lng, '🌐 Longitud',
                      keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Crear Negocio',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
