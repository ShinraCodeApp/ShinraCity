import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Sin cuenta se puede mirar el mapa, los comercios y sus promociones; para
/// guardar algo (cupones, puntos, favoritos, reseñas) hace falta cuenta.
///
/// Devuelve true si hay sesión. Si no, muestra el aviso para crear cuenta o
/// ingresar y devuelve false.
bool requireAccount(BuildContext context, {required String reason}) {
  if (context.read<AuthBloc>().state is AuthAuthenticated) return true;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.backgroundCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondaryDark.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Creá tu cuenta gratis en ${AppConstants.appName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.push('/register');
                },
                child: const Text('Crear cuenta'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/login');
              },
              child: const Text(
                'Ya tengo cuenta',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return false;
}
