import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'account_required_sheet.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _ShinraBottomNav(),
    );
  }
}

class _ShinraBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'Mapa',
                isActive: location == '/map',
                onTap: () => context.go('/map'),
              ),
              _NavItem(
                icon: Icons.confirmation_num_outlined,
                activeIcon: Icons.confirmation_num,
                label: 'Cupones',
                isActive: location == '/coupons',
                onTap: () {
                  if (requireAccount(context,
                      reason: 'Guardá cupones de los comercios cerca tuyo y usalos cuando quieras.')) {
                    context.go('/coupons');
                  }
                },
              ),
              _CenterFAB(
                onTap: () => context.push('/search'),
              ),
              _NavItem(
                icon: Icons.star_outline,
                activeIcon: Icons.star,
                label: 'Rewards',
                isActive: location == '/rewards',
                onTap: () {
                  if (requireAccount(context,
                      reason: 'Sumá puntos con cada cupón que uses y canjealos por recompensas.')) {
                    context.go('/rewards');
                  }
                },
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Perfil',
                isActive: location == '/profile',
                onTap: () {
                  if (requireAccount(context,
                      reason: 'Tu perfil guarda tus favoritos, los comercios que seguís y tu nivel.')) {
                    context.go('/profile');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.primary : AppColors.textSecondaryDark,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Poppins',
                  color: isActive ? AppColors.primary : AppColors.textSecondaryDark,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterFAB extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.explore,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
