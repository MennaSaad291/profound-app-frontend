class GradingSettingsService {
  GradingSettingsService._();
  static final GradingSettingsService instance = GradingSettingsService._();

  // ── User session ──────────────────────────────────────────────────────────
  // Set once on login, read by any screen that needs the current user's ID.
  int? userId;
  String userName = '';

  // ── Grading preferences ───────────────────────────────────────────────────
  String feedbackTone      = 'formal';     // formal | encouraging | strict
  double gradingSensitivity = 3;           // 1 (lenient) – 5 (strict)
  bool   detailedFeedback  = true;

  static String labelToApiValue(String label) {
    switch (label.toLowerCase()) {
      case 'encouraging': return 'encouraging';
      case 'strict':      return 'strict';
      default:            return 'formal';
    }
  }

  static String apiValueToLabel(String value) {
    switch (value) {
      case 'encouraging': return 'Encouraging';
      case 'strict':      return 'Strict';
      default:            return 'Formal';
    }
  }
}
