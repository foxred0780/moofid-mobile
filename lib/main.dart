import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'views/login/login_screen.dart';
import 'views/splash/splash_screen.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/customer_viewmodel.dart';
import 'viewmodels/invoice_viewmodel.dart';
import 'viewmodels/payment_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'dart:async';

void main() {
  _startPeriodicSync();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => InvoiceViewModel()),
        ChangeNotifierProxyProvider<AuthViewModel, SettingsViewModel>(
          create: (context) => SettingsViewModel(context.read<AuthViewModel>()),
          update: (context, auth, previous) => previous ?? SettingsViewModel(auth),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, CustomerViewModel>(
          create: (context) => CustomerViewModel(context.read<AuthViewModel>()),
          update: (context, auth, previous) => previous ?? CustomerViewModel(auth),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, PaymentViewModel>(
          create: (context) => PaymentViewModel(context.read<AuthViewModel>()),
          update: (context, auth, previous) => previous ?? PaymentViewModel(auth),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, DashboardViewModel>(
          create: (context) => DashboardViewModel(context.read<AuthViewModel>()),
          update: (context, auth, previous) => previous ?? DashboardViewModel(auth),
        ),
      ],
      child: const MoofidApp(),
    ),
  );
}

class MoofidApp extends StatelessWidget {
  const MoofidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مفيد للأقساط',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: NotificationService.messengerKey,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

// Background sync management
void _startPeriodicSync() {
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    // Only sync if we have a pairing session
    // SyncService.performSync handles check internal
    await SyncService.performSync();
  });
}

