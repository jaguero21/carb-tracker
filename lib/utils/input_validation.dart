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

    // SECURITY: Validate character set
    // FIXED: Use literal space instead of \s to prevent control characters
    // Allows both straight (') and curly (') apostrophes for restaurant names
    // iOS keyboards insert curly apostrophes by default
    final validPattern = RegExp(r"^[a-zA-Z0-9 \-,.()&%'/\u2019]+$");
    if (!validPattern.hasMatch(trimmed)) {
      return 'Please use only letters, numbers, and common punctuation';
    }

    // Prevent numeric-only inputs (not valid food names)
    if (RegExp(r'^[\d \-,.()]+$').hasMatch(trimmed)) {
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

  /// Sanitizes input before sending to external APIs
  ///
  /// Additional safety layer - removes any control characters that slipped through
  /// Normalizes curly apostrophes to straight apostrophes
  static String sanitizeForApi(String input) {
    return input
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .replaceAll('\x00', '') // null bytes
        .replaceAll('\u2019', "'") // normalize curly apostrophe (') to straight (')
        .replaceAll(RegExp(r'\s+'), ' ') // collapse multiple spaces
        .trim();
  }
}
