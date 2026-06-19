/// Lightweight in-memory store for grading preferences.
/// Shared across all screens in the same session.
class GradingSettingsService {
  GradingSettingsService._();
  static final GradingSettingsService instance = GradingSettingsService._();

  // Default values
  String feedbackTone      = 'formal';     // formal | encouraging | strict
  double gradingSensitivity = 3;           // 1 (lenient) – 5 (strict)
  bool   detailedFeedback  = true;

  /// Maps the Settings dropdown label → API value
  static String labelToApiValue(String label) {
    switch (label.toLowerCase()) {
      case 'encouraging': return 'encouraging';
      case 'strict':      return 'strict';
      default:            return 'formal';
    }
  }

  /// Maps the API value → display label
  static String apiValueToLabel(String value) {
    switch (value) {
      case 'encouraging': return 'Encouraging';
      case 'strict':      return 'Strict';
      default:            return 'Formal';
    }
  }
}
