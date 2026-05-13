import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/license_service.dart';
import '../../core/theme/app_colors.dart';
import '../splash/splash_screen.dart';

class ActivationScreen extends StatefulWidget {
  final LicenseStatus initialStatus;
  
  const ActivationScreen({super.key, required this.initialStatus});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final LicenseService _licenseService = LicenseService();
  final TextEditingController _codeController = TextEditingController();
  
  String _deviceId = "جاري التحميل...";
  bool _isLoading = false;
  String? _errorMessage;
  late bool _showStartTrialButton;

  @override
  void initState() {
    super.initState();
    _showStartTrialButton = (widget.initialStatus == LicenseStatus.trialNotStarted);
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    String id = await _licenseService.getDeviceId();
    setState(() {
      _deviceId = id;
    });
  }

  Future<void> _startTrial() async {
    setState(() => _isLoading = true);
    await _licenseService.startTrial();
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("بدأت الفترة التجريبية (يوم واحد). نتمنى لك تجربة ممتعة!"),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SplashScreen()),
    );
  }

  Future<void> _activate() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = "يرجى إدخال كود التفعيل");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool success = await _licenseService.activateApp(_codeController.text);

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم تفعيل التطبيق بنجاح! شكراً لك."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
      );
    } else {
      setState(() => _errorMessage = "كود التفعيل غير صحيح! تأكد من الكود وحاول مجدداً.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_showStartTrialButton ? "مرحباً بك في مفيد" : "تفعيل التطبيق", style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _showStartTrialButton ? Icons.rocket_launch_rounded : Icons.security_rounded, 
                size: 80, 
                color: AppColors.primary
              ),
              const SizedBox(height: 24),
              Text(
                _showStartTrialButton ? "ابدأ تجربتك المجانية" : "انتهت الفترة التجريبية",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _showStartTrialButton 
                  ? "التطبيق يحتاج إلى تفعيل. يمكنك تجربة التطبيق بكامل مميزاته لمدة يوم واحد مجاناً، أو إدخال كود التفعيل إذا قمت بالشراء."
                  : "الرجاء إرسال رقم الجهاز الخاص بك للمطور للحصول على كود التفعيل الخاص بك للاستمرار في استخدام التطبيق.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              
              if (_showStartTrialButton) ...[
                const SizedBox(height: 40),
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startTrial,
                    icon: const Icon(Icons.timer_outlined, color: Colors.white),
                    label: const Text(
                      "ابدأ الفترة التجريبية (يوم واحد)", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("أو", style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 32),
              ],
              
              // عرض رقم الجهاز
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Text(
                      "رقم جهازك (Device ID):",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _deviceId,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: AppColors.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _deviceId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("تم نسخ رقم الجهاز")),
                            );
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // حقل إدخال الكود
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: "أدخل كود التفعيل هنا",
                  errorText: _errorMessage,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // زر التفعيل
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _activate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "تفعيل التطبيق بكود مدفوع", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
