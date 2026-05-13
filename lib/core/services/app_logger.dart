import 'package:intl/intl.dart';

/// App Logging Service - tracks all operations for debugging
class AppLogger {
  static final List<AppLoggerEntry> _entries = [];
  static List<AppLoggerEntry> get entries => List.unmodifiable(_entries);

  static final _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  static void clear() => _entries.clear();

  static void _add(String type, String message, {dynamic data}) {
    final entry = AppLoggerEntry(
      time: DateTime.now(),
      type: type,
      message: message,
      data: data,
    );
    _entries.add(entry);
    print('[${_timeFormat.format(entry.time)}] [ANDROID] [$type] $message ${data != null ? "- $data" : ""}');
  }

  static void userAction(String message, {dynamic data}) => _add('USER_ACTION', message, data: data);
  static void sync(String message, {dynamic data}) => _add('SYNC', message, data: data);
  static void network(String message, {dynamic data}) => _add('NETWORK', message, data: data);
  static void auto(String message, {dynamic data}) => _add('AUTO_PROCESS', message, data: data);
  static void error(String message, [dynamic exception]) => _add('ERROR', message, data: exception);

  // Backward compatibility
  static void info(String message) => sync(message);
  static void success(String message) => sync('SUCCESS: $message');
  static void warn(String message) => _add('WARN', message);

  /// Get full log as copyable text
  static String getFullLog() {
    if (_entries.isEmpty) return 'لا توجد سجلات بعد.';
    final buffer = StringBuffer();
    buffer.writeln('=== Moofid App Logs (Android) ===');
    buffer.writeln('Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${_entries.length}');
    buffer.writeln('-----------------------------------');
    for (final e in _entries) {
      final timeStr = _timeFormat.format(e.time);
      final dataStr = e.data != null ? ' - Data: ${e.data}' : '';
      buffer.writeln('$timeStr [ANDROID] [${e.type}] ${e.message}$dataStr');
    }
    return buffer.toString();
  }

  static bool get hasErrors => _entries.any((e) => e.type == 'ERROR');
  static int get errorCount => _entries.where((e) => e.type == 'ERROR').length;
}

class AppLoggerEntry {
  final DateTime time;
  final String type;
  final String message;
  final dynamic data;
  AppLoggerEntry({required this.time, required this.type, required this.message, this.data});
}
