/// A single subtitle cue.
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

/// Parses SRT and WebVTT subtitle files into a list of cues.
///
/// The parser is intentionally tolerant: malformed timestamps are skipped and
/// unknown blocks are ignored, which matches how the upstream caption files
/// behave.
abstract final class SubtitleParser {
  /// Parses [content] into subtitle cues.
  static List<SubtitleCue> parse(String content) {
    if (content.trim().isEmpty) return const [];

    final normalised = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalised.split('\n');
    final cues = <SubtitleCue>[];

    var index = 0;
    while (index < lines.length) {
      final line = lines[index].trim();
      if (line.isEmpty || _isCounter(line) || line.startsWith('WEBVTT')) {
        index++;
        continue;
      }

      final timing = _parseTiming(line);
      if (timing == null) {
        index++;
        continue;
      }

      final textLines = <String>[];
      index++;
      while (index < lines.length && lines[index].trim().isNotEmpty) {
        textLines.add(lines[index].trim());
        index++;
      }

      if (textLines.isEmpty) continue;
      cues.add(
        SubtitleCue(
          start: timing.$1,
          end: timing.$2,
          text: textLines.join('\n'),
        ),
      );
    }
    return cues;
  }

  /// The cue that is visible at [position], if any.
  static SubtitleCue? cueAt(List<SubtitleCue> cues, Duration position) {
    for (final cue in cues) {
      if (position >= cue.start && position <= cue.end) return cue;
    }
    return null;
  }

  static bool _isCounter(String line) {
    final value = int.tryParse(line);
    return value != null;
  }

  static (Duration, Duration)? _parseTiming(String line) {
    final parts = line.split(RegExp(r'\s*-->\s*'));
    if (parts.length < 2) return null;
    final start = _parseTimestamp(parts[0]);
    final end = _parseTimestamp(parts[1].split(' ').first);
    if (start == null || end == null) return null;
    return (start, end);
  }

  static Duration? _parseTimestamp(String raw) {
    final value = raw.trim().replaceFirst(',', '.');
    final parts = value.split(':');
    if (parts.length < 2 || parts.length > 3) return null;

    int hours = 0;
    int minutes = 0;
    double seconds = 0;

    if (parts.length == 3) {
      final parsedHours = int.tryParse(parts[0]);
      final parsedMinutes = int.tryParse(parts[1]);
      final parsedSeconds = double.tryParse(parts[2]);
      if (parsedHours == null ||
          parsedMinutes == null ||
          parsedSeconds == null) {
        return null;
      }
      hours = parsedHours;
      minutes = parsedMinutes;
      seconds = parsedSeconds;
    } else {
      final parsedMinutes = int.tryParse(parts[0]);
      final parsedSeconds = double.tryParse(parts[1]);
      if (parsedMinutes == null || parsedSeconds == null) return null;
      minutes = parsedMinutes;
      seconds = parsedSeconds;
    }
    if (minutes > 59 || seconds >= 60) return null;
    return Duration(
      milliseconds: ((hours * 3600 + minutes * 60 + seconds) * 1000).round(),
    );
  }
}
