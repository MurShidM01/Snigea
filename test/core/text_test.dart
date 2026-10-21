import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/text/cleaners.dart';
import 'package:snigea/core/text/moviebox_title.dart';

void main() {
  group('cleanMovieBoxTitle', () {
    test('removes leading tag blocks', () {
      expect(cleanMovieBoxTitle('[Dub] Attack on Titan'), 'Attack on Titan');
      expect(cleanMovieBoxTitle('[1080p] Dune'), 'Dune');
      expect(cleanMovieBoxTitle('[RAW] Spirited Away'), 'Spirited Away');
      expect(
        cleanMovieBoxTitle('[Dub] [1080p] Solo Leveling'),
        'Solo Leveling',
      );
    });

    test('keeps a genuine release year in parentheses', () {
      expect(cleanMovieBoxTitle('Inception (2010)'), 'Inception (2010)');
      expect(
        cleanMovieBoxTitle('(500) Days of Summer'),
        '(500) Days of Summer',
      );
    });

    test('removes a non year parenthesis', () {
      expect(cleanMovieBoxTitle("Movie Name (Director's Cut)"), 'Movie Name');
    });

    test('removes trailing language, season and resolution tags', () {
      expect(cleanMovieBoxTitle('Dune [2021]'), 'Dune');
      expect(cleanMovieBoxTitle('Movie - Hindi Dub'), 'Movie');
      expect(cleanMovieBoxTitle('Breaking Bad S01'), 'Breaking Bad');
      expect(cleanMovieBoxTitle('Dark Season 2'), 'Dark');
      expect(cleanMovieBoxTitle('Interstellar_1080P'), 'Interstellar');
      expect(
        cleanMovieBoxTitle('Ek Deewane Ki Deewaniyat_360P'),
        'Ek Deewane Ki Deewaniyat',
      );
    });

    test('handles empty input', () {
      expect(cleanMovieBoxTitle(''), '');
      expect(cleanMovieBoxTitle('   '), '');
      expect(cleanMovieBoxTitle('Interstellar'), 'Interstellar');
    });
  });

  group('extract4DigitYear', () {
    test('finds the first plausible year', () {
      expect(extract4DigitYear('2010-07-16'), '2010');
      expect(extract4DigitYear('Released in 1999'), '1999');
      expect(extract4DigitYear('no year here'), '');
    });

    test('ignores years that do not start with 1 or 2', () {
      expect(extract4DigitYear('3456'), '');
    });
  });

  group('parseSizeBytes', () {
    test('parses the documented unit set', () {
      expect(parseSizeBytes('1.5 GB'), 1610612736);
      expect(parseSizeBytes('2 GiB'), 2147483648);
      expect(parseSizeBytes('450MB'), 471859200);
      expect(parseSizeBytes('512 KB'), 524288);
      expect(parseSizeBytes('1 TB'), 1099511627776);
    });

    test('returns null for unusable input', () {
      expect(parseSizeBytes('No size here'), isNull);
      expect(parseSizeBytes(''), isNull);
    });
  });

  group('stripEmojis and cleanStreamText', () {
    test('removes emoji but keeps the text', () {
      expect(stripEmojis('Movie 1080p'), 'Movie 1080p');
      expect(cleanStreamText('Movie  1080p'), 'Movie 1080p');
      expect(cleanStreamText('  padded  '), 'padded');
    });
  });

  group('languageToCode', () {
    test('maps the common language names', () {
      expect(languageToCode('English'), 'en');
      expect(languageToCode('hindi'), 'hi');
      expect(languageToCode('Tamil'), 'ta');
      expect(languageToCode('unknown'), isNull);
    });
  });

  group('formatBytes', () {
    test('formats byte counts', () {
      expect(formatBytes(0), '');
      expect(formatBytes(null), '');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1610612736), '1.5 GB');
    });
  });
}
