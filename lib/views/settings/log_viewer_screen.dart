import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/app_logger.dart';
import 'package:intl/intl.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _searchQuery = '';
  final _timeFormat = DateFormat('HH:mm:ss.SSS');

  @override
  Widget build(BuildContext context) {
    final filteredLogs = AppLogger.entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.message.contains(_searchQuery) || e.type.contains(_searchQuery);
    }).toList().reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل العمليات (Logs)'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'نسخ الكل',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: AppLogger.getFullLog()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ جميع السجلات ✓')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'مسح',
            onPressed: () {
              setState(() {
                AppLogger.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث في السجلات...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: filteredLogs.isEmpty
                ? const Center(child: Text('لا توجد سجلات حالياً'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final e = filteredLogs[index];
                      return _buildLogItem(e);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(AppLoggerEntry entry) {
    Color color;
    IconData icon;
    switch (entry.type) {
      case 'USER_ACTION':
        color = Colors.blue;
        icon = Icons.person;
        break;
      case 'SYNC':
        color = Colors.green;
        icon = Icons.sync;
        break;
      case 'NETWORK':
        color = Colors.orange;
        icon = Icons.wifi;
        break;
      case 'ERROR':
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                entry.type,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              Text(
                _timeFormat.format(entry.time),
                style: const TextStyle(color: AppColors.outline, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (entry.data != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(6),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.data.toString(),
                style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
