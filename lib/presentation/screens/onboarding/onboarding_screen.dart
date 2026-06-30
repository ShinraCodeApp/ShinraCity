import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common/gradient_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      emoji: '🗺️',
      title: 'Descubrí tu ciudad',
      subtitle: 'Explorá comercios, restaurantes y servicios cerca de vos en un mapa interactivo.',
      gradient: [Color(0xFF00D4FF), Color(0xFF0066FF)],
    ),
    _OnboardingPage(
      emoji: '🎉',
      title: 'Ofertas exclusivas',
      subtitle: 'Encontrá descuentos, promociones y beneficios especiales de tus comercios favoritos.',
      gradient: [Color(0xFFFF6B35), Color(0xFFFF1744)],
    ),
    _OnboardingPage(
      emoji: '🏆',
      title: 'Gana recompensas',
      subtitle: 'Acumulá puntos, subí de nivel y desbloqueá logros exclusivos al usar ShinraCity.',
      gradient: [Color(0xFFFFD700), Color(0xFFFFA500)],
    ),
    _OnboardingPage(
      emoji: '📱',
      title: 'Cupones digitales',
      subtitle: 'Reclamá cupones únicos con QR antifraude y usálos directamente en el local.',
      gradient: [Color(0xFF00FF88), Color(0xFF00BCD4)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, index) => _buildPage(_pages[index]),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            page.gradient[0].withValues(alpha: 0.15),
            AppColors.backgroundDark,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            page.emoji,
            style: const TextStyle(fontSize: 80),
          )
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: AppTextStyles.displayMedium.copyWith(
              color: Colors.white,
              fontSize: 30,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pages.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == i ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == i ? AppColors.primary : AppColors.textSecondaryDark,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        if (_currentPage < _pages.length - 1)
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  onPressed: _nextPage,
                  child: const Text('Siguiente'),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _finish,
                child: Text(
                  'Saltar',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
                ),
              ),
            ],
          )
        else
          GradientButton(
            onPressed: _finish,
            child: const Text('¡Empezar!'),
          ),
      ],
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/login');
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}
