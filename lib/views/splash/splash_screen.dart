import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../login/login_screen.dart';
import '../main/main_scaffold.dart';
import '../../core/services/license_service.dart';
import '../activation/activation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Artificial delay for splash visualization (premium feel)
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;

    // --- تحقق من التفعيل هنا ---
    final licenseService = LicenseService();
    final status = await licenseService.getLicenseStatus();
    
    if (!mounted) return;

    if (status == LicenseStatus.trialNotStarted || status == LicenseStatus.trialExpired) {
      // إما لم يبدأ التجربة بعد، أو انتهت التجربة (يحتاج لتفعيل)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ActivationScreen(initialStatus: status)),
      );
      return;
    }
    // ---------------------------
    // ---------------------------
    
    final authVM = context.read<AuthViewModel>();
    final isLoggedIn = await authVM.loadStoredSession();
    
    if (!mounted) return;
    
    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScaffold()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'app_logo',
              child: Image.asset(
                'assets/logo_small.png',
                width: 180,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
