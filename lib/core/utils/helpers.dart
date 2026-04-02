import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

const _uuid = Uuid();

/// Generate a unique ID string
String generateId() => _uuid.v4();

/// Returns today as YYYY-MM-DD string
String todayString() {
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
}

/// Clamp a double value between min and max
double clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Clamp an int value between min and max
int clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Format a timestamp to HH:MM string
String formatTime(int timestampMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  return DateFormat('hh:mm a').format(dt);
}

/// Format a timestamp to readable date string
String formatDate(int timestampMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  return DateFormat('dd MMM').format(dt);
}

/// Delay for a given number of milliseconds
Future<void> delay(int ms) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
}

/// Get current timestamp in milliseconds
int nowMs() => DateTime.now().millisecondsSinceEpoch;
