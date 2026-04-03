/// Hardened input validation utilities for CarpeCarb
/// Protects against injection attacks, control characters, and prompt manipulation
library;

class InputValidation {
  /// Validates food item input with comprehensive security checks
  ///
  /// Returns null if valid, or an error message if invalid
  ///
  /// Security features:
  /// - Blocks control characters (newlines, tabs, etc.)
  /// - Prevents prompt injection attempts
  /// - Rejects SQL-style syntax
  /// - Enforces length limits (2-100 chars)
  /// - Allows only safe punctuation
  static String? validateFoodInput(String input) {
    final trimmed = input.trim();

    // Check for empty input
    if (trimmed.isEmpty) {
      return 'Please enter a food item';
    }

    // Check minimum length
    if (trimmed.length < 2) {
      return 'Food name must be at least 2 characters';
    }

    // Check maximum length (prevent DoS attacks)
    if (trimmed.length > 100) {
      return 'Food name is too long (max 100 characters)';
    }

    // SECURITY: Block prompt injection attempts
    if (_containsPromptInjection(trimmed)) {
      return 'Please enter a valid food name';
    }

    // SECURITY: Block common command injection syntax while keeping normal
    // punctuation valid for food names (e.g., apostrophes and percent signs).
    if (_containsCommandInjection(trimmed)) {
      return 'Please enter a valid food name';
    }

    // SECURITY: Block path traversal patterns.
    if (_containsPathTraversal(trimmed)) {
      return 'Please enter a valid food name';
    }

    // SECURITY: Normalize Unicode confusables (curly apostrophes, dashes, etc.)
    // before the allow-list check so lookalikes are treated as their ASCII equivalents.
    final normalized = _normalizeUnicode(trimmed);

    // SECURITY: Validate character set (pure ASCII allow-list).
    // Use literal space instead of \s to prevent control characters.
    final validPattern = RegExp(r"^[a-zA-Z0-9 \-,.()&%'/]+$");
    if (!validPattern.hasMatch(normalized)) {
      return 'Please use only letters, numbers, and common punctuation';
    }

    // Prevent numeric-only inputs (not valid food names)
    if (RegExp(r'^[\d \-,.()]+$').hasMatch(normalized)) {
      return 'Please enter a valid food name';
    }

    return null;
  }

  /// Detects potential prompt injection attempts
  ///
  /// Blocks common jailbreak/manipulation patterns
  static bool _containsPromptInjection(String input) {
    final lowerInput = input.toLowerCase();

    // Common prompt injection keywords
    final dangerousPatterns = [
      'ignore',
      'system',
      'prompt',
      'instruction',
      'override',
      'jailbreak',
      'dan mode',
      'pretend',
      'act as',
      'roleplay',
      'forget',
    ];

    for (final pattern in dangerousPatterns) {
      if (lowerInput.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  static bool _containsCommandInjection(String input) {
    // Block shell control tokens and command substitution markers.
    return RegExp(r'(;|`|\$\(|&&|\|\|)').hasMatch(input) ||
        // Single pipe used as a shell operator (non-numeric contexts).
        RegExp(r'\|').hasMatch(input);
  }

  static bool _containsPathTraversal(String input) {
    return input.contains('../') || input.contains('..\\');
  }

  /// Normalizes common Unicode confusables to their ASCII equivalents.
  ///
  /// Applied before both validation and API sanitization so the regex
  /// allow-list operates on a consistent, ASCII-like representation.
  static String _normalizeUnicode(String input) {
    return input
        // Apostrophe and single-quote lookalikes
        .replaceAll('\u2019', "'") // right single quotation mark (')
        .replaceAll('\u2018', "'") // left single quotation mark (')
        .replaceAll('\u02BC', "'") // modifier letter apostrophe (ʼ)
        .replaceAll('\u02B9', "'") // modifier letter prime (ʹ)
        .replaceAll('\u02C8', "'") // modifier letter vertical line (ˈ)
        .replaceAll('\u0060', "'") // grave accent (`)
        .replaceAll('\u00B4', "'") // acute accent (´)
        .replaceAll('\u02CA', "'") // modifier letter acute accent (ˊ)
        .replaceAll('\u02CB', "'") // modifier letter grave accent (ˋ)
        .replaceAll('\u0301', "'") // combining acute accent
        .replaceAll('\u0300', "'") // combining grave accent
        .replaceAll('\uFF07', "'") // fullwidth apostrophe (＇)
        .replaceAll('\u055A', "'") // Armenian apostrophe (՚)
        .replaceAll('\u05F3', "'") // Hebrew punctuation geresh (׳)
        .replaceAll('\u2032', "'") // prime (′)
        // Dash lookalikes
        .replaceAll('\u2013', '-') // en dash
        .replaceAll('\u2014', '-') // em dash
        .replaceAll('\u2212', '-'); // minus sign
  }

  /// Sanitizes input before sending to external APIs
  ///
  /// Additional safety layer - removes any control characters that slipped through
  /// Normalizes Unicode confusables to ASCII equivalents
  static String sanitizeForApi(String input) {
    return _normalizeUnicode(input)
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .replaceAll('\x00', '') // null bytes
        .replaceAll(RegExp(r'\s+'), ' ') // collapse multiple spaces
        .trim();
  }
}
