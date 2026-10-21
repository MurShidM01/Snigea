/// Text normalisation helpers.
///
/// These are direct Dart ports of the string utilities used by the reference
/// MovieBox-TUI implementation, so provider payloads are parsed identically.
library;

/// Removes emoji and pictographic characters from [input].
///
/// Matches the reference implementation, which strips the emoji unicode
/// blocks, variation selectors and the zero-width joiner.
String stripEmojis(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final isEmoji =
        (rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        (rune >= 0x2300 && rune <= 0x23FF) ||
        (rune >= 0x2B00 && rune <= 0x2BFF) ||
        (rune >= 0xFE00 && rune <= 0xFE0F) ||
        rune == 0x200D;
    if (!isEmoji) {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Strips emoji and collapses repeated whitespace in a single pass.
String cleanStreamText(String input) {
  final withoutEmoji = stripEmojis(input);
  final cleaned = StringBuffer();
  var lastWasSpace = false;
  for (final rune in withoutEmoji.runes) {
    final isSpace = _isWhitespace(rune);
    if (isSpace) {
      if (!lastWasSpace && cleaned.isNotEmpty) {
        cleaned.write(' ');
        lastWasSpace = true;
      }
    } else {
      cleaned.writeCharCode(rune);
      lastWasSpace = false;
    }
  }
  return cleaned.toString().trim();
}

bool _isWhitespace(int rune) {
  return rune == 0x20 ||
      rune == 0x09 ||
      rune == 0x0A ||
      rune == 0x0B ||
      rune == 0x0C ||
      rune == 0x0D ||
      rune == 0x85 ||
      rune == 0xA0 ||
      (rune >= 0x2000 && rune <= 0x200A) ||
      rune == 0x2028 ||
      rune == 0x2029 ||
      rune == 0x202F ||
      rune == 0x205F ||
      rune == 0x3000;
}

/// Extracts the first plausible four digit year from [raw].
///
/// The first digit must be `1` or `2`, matching the reference behaviour.
String extract4DigitYear(String raw) {
  final bytes = raw.codeUnits;
  for (var i = 0; i + 4 <= bytes.length; i++) {
    final window = bytes.sublist(i, i + 4);
    if (window.every((c) => c >= 0x30 && c <= 0x39)) {
      final first = window.first - 0x30;
      if (first == 1 || first == 2) {
        return String.fromCharCodes(window);
      }
    }
  }
  return '';
}

/// Parses a human readable size such as `1.5 GB` into a byte count.
///
/// Supports the same unit set as the reference implementation.
int? parseSizeBytes(String text) {
  if (text.trim().isEmpty) return null;
  final parts = text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  for (var i = 0; i < parts.length; i++) {
    final clean = parts[i].replaceAll(RegExp(r'[^A-Za-z0-9.]'), '');
    final parsed = double.tryParse(clean);
    if (parsed != null && i + 1 < parts.length) {
      final unit = parts[i + 1]
          .replaceAll(RegExp(r'[^A-Za-z]'), '')
          .toUpperCase();
      switch (unit) {
        case 'TB':
        case 'TIB':
        case 'T':
          return (parsed * 1099511627776).round();
        case 'GB':
        case 'GIB':
        case 'G':
          return (parsed * 1073741824).round();
        case 'MB':
        case 'MIB':
        case 'M':
          return (parsed * 1048576).round();
        case 'KB':
        case 'KIB':
        case 'K':
          return (parsed * 1024).round();
      }
    }
    final upper = clean.toUpperCase();
    const suffixes = <String, double>{
      'TIB': 1099511627776,
      'TB': 1099511627776,
      'GIB': 1073741824,
      'GB': 1073741824,
      'MIB': 1048576,
      'MB': 1048576,
      'KIB': 1024,
      'KB': 1024,
    };
    for (final entry in suffixes.entries) {
      if (upper.endsWith(entry.key)) {
        final numText = upper.substring(0, upper.length - entry.key.length);
        final num = double.tryParse(numText);
        if (num != null) {
          return (num * entry.value).round();
        }
      }
    }
  }
  return null;
}

/// Formats a byte count for display, e.g. `1.4 GB`.
String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final precision = unitIndex <= 1 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}
