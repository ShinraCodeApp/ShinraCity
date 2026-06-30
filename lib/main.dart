import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'domain/repositories/auth_repository.dart';
import 'firebase_options.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/map/map_bloc.dart';
import 'presentation/blocs/promotions/promotions_bloc.dart';
import 'services/emulator_service.dart';
import 'services/notification_service.dart';
import 'services/injection_container.dart';

bool _onboardingDone = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await EmulatorService.connectToEmulators();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService().initialize();
  await configureDependencies();

  // Read first-launch flag before building the widget tree
  final prefs = await SharedPreferences.getInstance();
  _onboardingDone = prefs.getBool('onboarding_done') ?? false;

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.backgroundCard,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ShinraCityApp());
}

class ShinraCityApp extends StatelessWidget {
  const ShinraCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => GetIt.instance<AuthBloc>()..add(AppStarted()),
        ),
        BlocProvider<MapBloc>(
          create: (_) => GetIt.instance<MapBloc>(),
          lazy: true,
        ),
        BlocProvider<PromotionsBloc>(
          create: (_) => GetIt.instance<PromotionsBloc>(),
          lazy: true,
        ),
      ],
      child: const _AppContent(),
    );
  }
}

class _AppContent extends StatelessWidget {
  const _AppContent();

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(
      context,
      showOnboarding: !_onboardingDone,
    );

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, current) => current is AuthAuthenticated,
      listener: (_, __) async {
        final token = await NotificationService().getToken();
        if (token != null) {
          GetIt.instance<AuthRepository>().updateFcmToken(token);
        }
      },
      child: MaterialApp.router(
        title: 'ShinraCity',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('es', 'AR'),
        supportedLocales: const [
          Locale('es', 'AR'),
          Locale('en', 'US'),
        ],
      ),
    );
  }
}
