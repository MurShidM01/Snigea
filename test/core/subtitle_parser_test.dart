import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/text/subtitle_parser.dart';

void main() {
  group('SubtitleParser', () {
    test('parses a SRT file', () {
      const content = '''
1
00:00:01,000 --> 00:00:03,500
Hello world

2
00:00:04,000 --> 00:00:06,000
Second line
''';
      final cues = SubtitleParser.parse(content);
      expect(cues.length, 2);
      expect(cues.first.start, const Duration(seconds: 1));
      expect(cues.first.end, const Duration(milliseconds: 3500));
      expect(cues.first.text, 'Hello world');
      expect(cues[1].text, 'Second line');
    });

    test('parses a WebVTT file', () {
      const content = '''WEBVTT

00:00:02.000 --> 00:00:04.000 align:start
Caption text
''';
      final cues = SubtitleParser.parse(content);
      expect(cues.length, 1);
      expect(cues.first.start, const Duration(seconds: 2));
      expect(cues.first.text, 'Caption text');
    });

    test('skips malformed blocks', () {
      const content = '''
00:00:xx --> 00:00:03
broken

00:00:01,000 --> 00:00:02,000
valid
''';
      final cues = SubtitleParser.parse(content);
      expect(cues.length, 1);
      expect(cues.first.text, 'valid');
    });

    test('finds the cue at a position', () {
      final cues = SubtitleParser.parse(
        '1\n00:00:01,000 --> 00:00:02,000\nfirst\n',
      );
      expect(
        SubtitleParser.cueAt(cues, const Duration(milliseconds: 1500))?.text,
        'first',
      );
      expect(SubtitleParser.cueAt(cues, const Duration(seconds: 5)), isNull);
    });

    test('returns no cues for empty input', () {
      expect(SubtitleParser.parse(''), isEmpty);
    });
  });
}
