import 'package:flutter_test/flutter_test.dart';
import 'package:utkarsh_ai/core/utils/helpers.dart';

void main() {
  group('clamp()', () {
    test('returns value within range unchanged', () {
      expect(clamp(50, 0, 100), equals(50));
    });
    test('clamps value below minimum to minimum', () {
      expect(clamp(-5, 0, 100), equals(0));
    });
    test('clamps value above maximum to maximum', () {
      expect(clamp(150, 0, 100), equals(100));
    });
    test('returns min when value equals min', () {
      expect(clamp(0, 0, 100), equals(0));
    });
    test('returns max when value equals max', () {
      expect(clamp(100, 0, 100), equals(100));
    });
  });

  group('clampInt()', () {
    test('clamps int below min', () => expect(clampInt(-1, 0, 5), equals(0)));
    test('clamps int above max', () => expect(clampInt(10, 0, 5), equals(5)));
    test('keeps int in range',   () => expect(clampInt(3, 0, 5), equals(3)));
  });

  group('todayString()', () {
    test('returns YYYY-MM-DD format', () {
      expect(todayString(), matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
    test('returns todays actual date', () {
      final now = DateTime.now();
      final expected =
          '${now.year}-${now.month.toString().padLeft(2,'0')}'
          '-${now.day.toString().padLeft(2,'0')}';
      expect(todayString(), equals(expected));
    });
  });

  group('generateId()', () {
    test('returns non-empty string', () {
      expect(generateId(), isNotEmpty);
    });
    test('generates unique IDs each time', () {
      expect(generateId(), isNot(equals(generateId())));
    });
    test('returns valid UUID v4 format', () {
      expect(
        generateId(),
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )),
      );
    });
  });

  group('nowMs()', () {
    test('returns current time in milliseconds', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final now    = nowMs();
      final after  = DateTime.now().millisecondsSinceEpoch;
      expect(now, greaterThanOrEqualTo(before));
      expect(now, lessThanOrEqualTo(after));
    });
  });
}
