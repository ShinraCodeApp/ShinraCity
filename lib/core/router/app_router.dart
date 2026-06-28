import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/blocs/coupons/coupons_bloc.dart';
import '../../presentation/blocs/commerce/commerce_bloc.dart';
import '../../presentation/blocs/points/points_bloc.dart';
import '../../presentation/blocs/promotions/promotions_bloc.dart';
import '../../domain/entities/commerce_entity.dart';
import '../../domain/entities/promotion_entity.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/screens/admin/admin_panel_screen.dart';
import '../../presentation/screens/business/register_business_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/business/business_dashboard_screen.dart';
import '../../presentation/screens/business/create_promotion_screen.dart';
import '../../presentation/screens/business/promotions_list_screen.dart';
import '../../presentation/screens/commerce/commerce_detail_screen.dart';
import '../../presentation/screens/coupons/coupons_screen.dart'
    show CouponsScreen, QRScannerScreen;
import '../../presentation/screens/gamification/leaderboard_screen.dart';
import '../../presentation/screens/gamification/rewards_screen.dart';
import '../../presentation/screens/map/map_screen.dart';
import '../../presentation/screens/business/employees_screen.dart';
import '../../presentation/screens/business/full_statistics_screen.dart';
import '../../presentation/screens/business/plan_upgrade_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/profile_edit_screen.dart';
import '../../presentation/screens/profile/settings_screen.dart';
import '../../presentation/screens/profile/favorites_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/profile/notifications_screen.dart';
import '../widgets/main_shell.dart';

class AppRouter {
  // Singleton router so NotificationService can navigate without BuildContext
  static GoRouter? _instance;
  static GoRouter get instance {
    assert(_instance != null, 'AppRouter.createRouter must be called first');
    return _instance!;
  }

  static GoRouter createRouter(
    BuildContext context, {
    bool showOnboarding = false,
  }) {
    _instance = GoRouter(
      initialLocation: showOnboarding ? '/onboarding' : '/login',
      redirect: (context, state) {
        final authState = context.read<AuthBloc>().state;
        final loc = state.matchedLocation;
        final isPublicPage = loc == '/login' ||
            loc == '/register' ||
            loc == '/onboarding';

        if (authState is AuthUnauthenticated && !isPublicPage) {
          return '/login';
        }

        if (authState is AuthAuthenticated && isPublicPage) {
          return '/map';
        }

        return null;
      },
      refreshListenable: _AuthStateNotifier(context.read<AuthBloc>()),
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),

        // Main shell — bottom nav
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/map',
              builder: (_, __) => const MapScreen(),
            ),
            GoRoute(
              path: '/coupons',
              builder: (context, _) {
                final authState = context.read<AuthBloc>().state;
                final userId = authState is AuthAuthenticated ? authState.user.id : '';
                return BlocProvider(
                  create: (_) => GetIt.instance<CouponsBloc>(param1: userId),
                  child: const CouponsScreen(),
                );
              },
            ),
            GoRoute(
              path: '/rewards',
              builder: (context, _) {
                final authState = context.read<AuthBloc>().state;
                final userId = authState is AuthAuthenticated ? authState.user.id : '';
                return BlocProvider(
                  create: (_) => GetIt.instance<PointsBloc>(param1: userId),
                  child: const RewardsScreen(),
                );
              },
            ),
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/business',
              builder: (_, __) => BlocProvider(
                create: (_) => GetIt.instance<PromotionsBloc>(),
                child: const BusinessDashboardScreen(),
              ),
            ),
          ],
        ),

        GoRoute(
          path: '/register-business',
          builder: (_, __) => const RegisterBusinessScreen(),
        ),
        GoRoute(
          path: '/edit-business/:id',
          builder: (_, state) => RegisterBusinessScreen(
            editCommerceId: state.pathParameters['id'],
          ),
        ),

        // Detail screens (outside shell — no bottom nav)
        GoRoute(
          path: '/commerce/:id',
          builder: (context, state) {
            final commerceId = state.pathParameters['id']!;
            final authState = context.read<AuthBloc>().state;
            final userId = authState is AuthAuthenticated ? authState.user.id : '';
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      GetIt.instance<CommerceBloc>(param1: userId),
                ),
                BlocProvider(
                  create: (_) => GetIt.instance<PromotionsBloc>(),
                ),
                BlocProvider(
                  create: (_) =>
                      GetIt.instance<CouponsBloc>(param1: userId),
                ),
              ],
              child: CommerceDetailScreen(commerceId: commerceId),
            );
          },
        ),
        GoRoute(
          path: '/commerce/:id/create-promotion',
          builder: (_, state) => BlocProvider(
            create: (_) => GetIt.instance<PromotionsBloc>(),
            child: CreatePromotionScreen(
              commerceId: state.pathParameters['id']!,
            ),
          ),
        ),
        GoRoute(
          path: '/commerce/:id/promotions',
          builder: (_, state) => BlocProvider(
            create: (_) => GetIt.instance<PromotionsBloc>(),
            child: PromotionsListScreen(
              commerceId: state.pathParameters['id']!,
            ),
          ),
        ),
        GoRoute(
          path: '/commerce/:id/edit-promotion/:promotionId',
          builder: (_, state) {
            final promotion = state.extra as PromotionEntity?;
            return BlocProvider(
              create: (_) => GetIt.instance<PromotionsBloc>(),
              child: CreatePromotionScreen(
                commerceId: state.pathParameters['id']!,
                existing: promotion,
              ),
            );
          },
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, _) {
            final authState = context.read<AuthBloc>().state;
            final userId = authState is AuthAuthenticated ? authState.user.id : '';
            return BlocProvider(
              create: (_) => GetIt.instance<PointsBloc>(param1: userId),
              child: const LeaderboardScreen(),
            );
          },
        ),
        GoRoute(
          path: '/scan/:commerceId',
          builder: (context, state) {
            final authState = context.read<AuthBloc>().state;
            final userId = authState is AuthAuthenticated ? authState.user.id : '';
            return BlocProvider(
              create: (_) => GetIt.instance<CouponsBloc>(param1: userId),
              child: QRScannerScreen(
                commerceId: state.pathParameters['commerceId']!,
              ),
            );
          },
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) {
            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              final role = authState.user.role.name;
              if (role == 'admin' || role == 'superAdmin') {
                return const AdminPanelScreen();
              }
            }
            return const LoginScreen();
          },
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const SearchScreen(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, __) => const ProfileEditScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/favorites',
          builder: (_, __) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/following',
          builder: (_, __) => const FavoritesScreen(showFollowing: true),
        ),
        GoRoute(
          path: '/coupon-history',
          redirect: (_, __) => '/coupons',
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/commerce/:id/stats',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return FullStatisticsScreen(
              commerceId: state.pathParameters['id']!,
              commerceName: extra?['commerceName'] as String? ?? '',
            );
          },
        ),
        GoRoute(
          path: '/commerce/:id/employees',
          builder: (_, state) => EmployeesScreen(
            commerceId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/business/upgrade',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final currentPlan = extra?['currentPlan'] as CommercePlan? ??
                CommercePlan.free;
            final commerceId = extra?['commerceId'] as String? ?? '';
            return PlanUpgradeScreen(
              currentPlan: currentPlan,
              commerceId: commerceId,
            );
          },
        ),
      ],
    );
    return _instance!;
  }
}

class _AuthStateNotifier extends ChangeNotifier {
  final AuthBloc _authBloc;

  _AuthStateNotifier(this._authBloc) {
    _authBloc.stream.listen((_) => notifyListeners());
  }
}
