// test/unit/grading_settings_service_test.dart
//
// Unit tests for GradingSettingsService singleton.
// These are pure Dart tests — no HTTP, no widgets, no BuildContext needed.
//
// Run with: flutter test test/unit/grading_settings_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:profound_app_frontend/core/services/grading_settings_service.dart';

void main() {
  // Reset singleton state before each test so tests are isolated
  setUp(() {
    GradingSettingsService.instance.feedbackTone      = 'formal';
    GradingSettingsService.instance.gradingSensitivity = 3;
    GradingSettingsService.instance.detailedFeedback  = true;
    GradingSettingsService.instance.userId            = null;
    GradingSettingsService.instance.userName          = '';
  });

  group('GradingSettingsService — singleton identity', () {
    test('always returns the same instance', () {
      final a = GradingSettingsService.instance;
      final b = GradingSettingsService.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('GradingSettingsService — feedbackTone', () {
    test('default value is formal', () {
      expect(GradingSettingsService.instance.feedbackTone, equals('formal'));
    });

    test('can be updated to encouraging', () {
      GradingSettingsService.instance.feedbackTone = 'encouraging';
      expect(GradingSettingsService.instance.feedbackTone, equals('encouraging'));
    });

    test('can be updated to strict', () {
      GradingSettingsService.instance.feedbackTone = 'strict';
      expect(GradingSettingsService.instance.feedbackTone, equals('strict'));
    });
  });

  group('GradingSettingsService — labelToApiValue', () {
    test('Formal maps to formal', () {
      expect(GradingSettingsService.labelToApiValue('Formal'), equals('formal'));
    });

    test('Encouraging maps to encouraging', () {
      expect(GradingSettingsService.labelToApiValue('Encouraging'), equals('encouraging'));
    });

    test('Strict maps to strict', () {
      expect(GradingSettingsService.labelToApiValue('Strict'), equals('strict'));
    });

    test('unknown label defaults to formal', () {
      expect(GradingSettingsService.labelToApiValue('Unknown'), equals('formal'));
    });

    test('case-insensitive matching', () {
      expect(GradingSettingsService.labelToApiValue('ENCOURAGING'), equals('encouraging'));
      expect(GradingSettingsService.labelToApiValue('strict'), equals('strict'));
    });
  });

  group('GradingSettingsService — apiValueToLabel', () {
    test('formal maps to Formal', () {
      expect(GradingSettingsService.apiValueToLabel('formal'), equals('Formal'));
    });

    test('encouraging maps to Encouraging', () {
      expect(GradingSettingsService.apiValueToLabel('encouraging'), equals('Encouraging'));
    });

    test('strict maps to Strict', () {
      expect(GradingSettingsService.apiValueToLabel('strict'), equals('Strict'));
    });

    test('unknown value defaults to Formal', () {
      expect(GradingSettingsService.apiValueToLabel('unknown'), equals('Formal'));
    });
  });

  group('GradingSettingsService — gradingSensitivity', () {
    test('default value is 3', () {
      expect(GradingSettingsService.instance.gradingSensitivity, equals(3));
    });

    test('can be updated', () {
      GradingSettingsService.instance.gradingSensitivity = 5;
      expect(GradingSettingsService.instance.gradingSensitivity, equals(5));
    });

    test('persists across accesses to the same instance', () {
      GradingSettingsService.instance.gradingSensitivity = 1;
      final value = GradingSettingsService.instance.gradingSensitivity;
      expect(value, equals(1));
    });
  });

  group('GradingSettingsService — detailedFeedback', () {
    test('default is true', () {
      expect(GradingSettingsService.instance.detailedFeedback, isTrue);
    });

    test('can be disabled', () {
      GradingSettingsService.instance.detailedFeedback = false;
      expect(GradingSettingsService.instance.detailedFeedback, isFalse);
    });
  });

  group('GradingSettingsService — user session', () {
    test('userId defaults to null', () {
      expect(GradingSettingsService.instance.userId, isNull);
    });

    test('userId can be set after login', () {
      GradingSettingsService.instance.userId = 42;
      expect(GradingSettingsService.instance.userId, equals(42));
    });

    test('userName defaults to empty string', () {
      expect(GradingSettingsService.instance.userName, equals(''));
    });

    test('userName can be set after login', () {
      GradingSettingsService.instance.userName = 'Dr. Ahmed';
      expect(GradingSettingsService.instance.userName, equals('Dr. Ahmed'));
    });

    test('userId and userName persist on the same singleton', () {
      GradingSettingsService.instance.userId   = 7;
      GradingSettingsService.instance.userName = 'Professor Menna';
      expect(GradingSettingsService.instance.userId,   equals(7));
      expect(GradingSettingsService.instance.userName, equals('Professor Menna'));
    });
  });
}
