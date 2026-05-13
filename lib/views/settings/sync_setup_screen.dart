import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/services/pairing_service.dart';
import '../../core/services/sync_service.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SyncSetupScreen extends StatefulWidget {
  const SyncSetupScreen({super.key});

  @override
  State<SyncSetupScreen> createState() => _SyncSetupScreenState();
}

class _SyncSetupScreenState extends State<SyncSetupScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ربط الحاسبة'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MobileScanner(
              onDetect: (capture) async {
                if (_isProcessing) return;
                
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    setState(() => _isProcessing = true);
                    try {
                      await PairingService.savePairing(barcode.rawValue!);
                      
                      // Bridge Session immediately
                      final serverInfo = await SyncService.checkServerStatus();
                      if (serverInfo == null) {
                        throw Exception('لا يمكن الاتصال بالحاسبة. تأكد أنها مرتبطة بنفس الشبكة وأن البرنامج مفتوح.');
                      }

                      await SyncService.bridgeSession(serverInfo);

                      // Auto-login the bridged user
                      if (!mounted) return;
                      final authVM = Provider.of<AuthViewModel>(context, listen: false);
                      final userId = serverInfo['userId']?.toString() ?? '';
                      final userName = serverInfo['userName']?.toString() ?? 'User';
                      if (userId.isNotEmpty) {
                        await authVM.loginById(userId, userName);
                      }

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم الربط وتنشيط الجلسة بنجاح!')),
                      );
                      Navigator.pop(context);
                    } catch (e) {
                      setState(() => _isProcessing = false);
                      String errorStr = e.toString();
                      String msg = 'كود غير صالح';
                      
                      if (errorStr.contains('الاتصال') || errorStr.contains('timeout') || errorStr.contains('os error')) {
                        msg = 'فشل الاتصال: تأكد أن الهاتف والكمبيوتر على نفس الشبكة وأن البرنامج مفتوح.';
                      } else if (errorStr.contains('format')) {
                        msg = 'بيانات الكود غير صحيحة. يرجى إعادة توليد الكود من البرنامج.';
                      } else {
                        msg = 'خطأ التقني: $errorStr';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg), 
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5)
                        ),
                      );
                    }
                    break;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(32),
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 48, color: Color(0xFF3B82F6)),
                  const SizedBox(height: 16),
                  const Text(
                    'امسح الكود من شاشة الحاسبة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'افتح الإعدادات في برنامج الموفد على الحاسبة وامسح كود المزامنة للبدء.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
