/// Title normalisation for MovieBox payloads.
///
/// Port of the reference `clean_moviebox_title` routine: it removes leading
/// tag blocks such as `[Dub]`, trailing language/quality suffixes, season
/// markers and resolution tags while keeping genuine release years intact.
library;

const List<String> _languageTags = [
  'hindi',
  'tamil',
  'telugu',
  'kannada',
  'malayalam',
  'bengali',
  'marathi',
  'punjabi',
  'gujarati',
  'urdu',
  'english',
  'spanish',
  'french',
  'german',
  'italian',
  'japanese',
  'korean',
  'chinese',
  'russian',
  'portuguese',
  'turkish',
  'arabic',
  'dub',
  'audio',
  'multi',
  'season',
];

int _rfindIgnoreCase(String haystack, String needle) {
  if (needle.isEmpty) return haystack.length;
  if (haystack.length < needle.length) return -1;
  final h = haystack.toLowerCase();
  final n = needle.toLowerCase();
  return h.lastIndexOf(n);
}

bool _containsIgnoreCase(String haystack, String needle) =>
    _rfindIgnoreCase(haystack, needle) >= 0;

/// Cleans a raw MovieBox title into a human friendly display title.
String cleanMovieBoxTitle(String rawTitle) {
  var title = rawTitle.trim();
  if (title.isEmpty) return '';

  while (title.startsWith('[')) {
    final closePos = title.indexOf(']');
    if (closePos < 0) break;
    final remainder = title.substring(closePos + 1).trim();
    if (remainder.isEmpty) break;
    title = remainder;
  }

  final bracketPos = title.indexOf('[');
  if (bracketPos > 0) {
    title = title.substring(0, bracketPos).trim();
  }

  final parenPos = title.indexOf('(');
  if (parenPos > 0) {
    final inside = title.substring(parenPos + 1);
    final insideContent = inside.split(')').first.trim();
    final isYear =
        insideContent.length == 4 &&
        insideContent.codeUnits.every((c) => c >= 0x30 && c <= 0x39) &&
        (int.tryParse(insideContent) ?? 0) >= 1900 &&
        (int.tryParse(insideContent) ?? 0) <= 2099;
    if (!isYear) {
      title = title.substring(0, parenPos).trim();
    }
  }

  final dashPos = title.lastIndexOf(' - ');
  if (dashPos >= 0) {
    final suffix = title.substring(dashPos + 3);
    var isTag = _languageTags.any((tag) => _containsIgnoreCase(suffix, tag));
    if (!isTag) {
      final trimmed = suffix.trim();
      isTag =
          trimmed.length > 1 &&
          (trimmed[0] == 's' || trimmed[0] == 'S') &&
          trimmed
              .substring(1)
              .split('')
              .every(
                (c) =>
                    (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) ||
                    c == '-',
              );
    }
    if (isTag) {
      title = title.substring(0, dashPos).trim();
    }
  }

  final sIdx = title.lastIndexOf(' S');
  if (sIdx >= 0) {
    final suffix = title.substring(sIdx + 2);
    final isSeason =
        suffix.isNotEmpty &&
        suffix
            .split('')
            .every(
              (c) =>
                  (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) ||
                  c == '-' ||
                  c == 'S',
            );
    if (isSeason && suffix.isNotEmpty) {
      final first = suffix.codeUnitAt(0);
      if (first >= 0x30 && first <= 0x39) {
        title = title.substring(0, sIdx).trim();
      }
    }
  }

  final seasonIdx = _rfindIgnoreCase(title, ' season ');
  if (seasonIdx >= 0) {
    title = title.substring(0, seasonIdx).trim();
  }

  for (final sep in ['_', ' ', '.', '-']) {
    final pos = title.lastIndexOf(sep);
    if (pos < 0) continue;
    final suffix = title.substring(pos + 1);
    final isRes =
        (suffix.endsWith('p') || suffix.endsWith('P')) &&
        suffix.length > 1 &&
        suffix
            .substring(0, suffix.length - 1)
            .split('')
            .every((c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) &&
        ((int.tryParse(suffix.substring(0, suffix.length - 1)) ?? 0) >= 144) &&
        ((int.tryParse(suffix.substring(0, suffix.length - 1)) ?? 0) <= 8640);
    if (isRes) {
      title = title.substring(0, pos).trim();
    }
  }

  final cleaned = title.replaceAll(RegExp(r'[-:_.\s]+$'), '').trim();

  return cleaned.isEmpty ? rawTitle.trim() : cleaned;
}

/// Maps a human language name to an ISO-639-1 code.
String? languageToCode(String name) {
  final lower = name.trim().toLowerCase();
  const map = <String, String>{
    'english': 'en',
    'en': 'en',
    'eng': 'en',
    'spanish': 'es',
    'es': 'es',
    'spa': 'es',
    'español': 'es',
    'castellano': 'es',
    'hindi': 'hi',
    'hi': 'hi',
    'hin': 'hi',
    'french': 'fr',
    'fr': 'fr',
    'fre': 'fr',
    'fra': 'fr',
    'français': 'fr',
    'german': 'de',
    'de': 'de',
    'ger': 'de',
    'deu': 'de',
    'deutsch': 'de',
    'italian': 'it',
    'it': 'it',
    'ita': 'it',
    'italiano': 'it',
    'japanese': 'ja',
    'ja': 'ja',
    'jpn': 'ja',
    '日本語': 'ja',
    'korean': 'ko',
    'ko': 'ko',
    'kor': 'ko',
    '한국어': 'ko',
    'chinese': 'zh',
    'zh': 'zh',
    'zho': 'zh',
    'chi': 'zh',
    '中文': 'zh',
    'mandarin': 'zh',
    'cantonese': 'zh',
    'portuguese': 'pt',
    'pt': 'pt',
    'por': 'pt',
    'português': 'pt',
    'russian': 'ru',
    'ru': 'ru',
    'rus': 'ru',
    'русский': 'ru',
    'arabic': 'ar',
    'ar': 'ar',
    'ara': 'ar',
    'العربية': 'ar',
    'turkish': 'tr',
    'tr': 'tr',
    'tur': 'tr',
    'türkçe': 'tr',
    'bengali': 'bn',
    'bn': 'bn',
    'ben': 'bn',
    'বাংলা': 'bn',
    'tamil': 'ta',
    'ta': 'ta',
    'tam': 'ta',
    'தமிழ்': 'ta',
    'telugu': 'te',
    'te': 'te',
    'tel': 'te',
    'తెలుగు': 'te',
    'malayalam': 'ml',
    'ml': 'ml',
    'mal': 'ml',
    'മലയാളം': 'ml',
    'kannada': 'kn',
    'kn': 'kn',
    'kan': 'kn',
    'ಕನ್ನಡ': 'kn',
    'marathi': 'mr',
    'mr': 'mr',
    'mar': 'mr',
    'मराठी': 'mr',
    'punjabi': 'pa',
    'pa': 'pa',
    'pan': 'pa',
    'ਪੰਜਾਬੀ': 'pa',
    'gujarati': 'gu',
    'gu': 'gu',
    'guj': 'gu',
    'ગુજરાતી': 'gu',
    'urdu': 'ur',
    'ur': 'ur',
    'urd': 'ur',
    'اردو': 'ur',
    'indonesian': 'id',
    'id': 'id',
    'ind': 'id',
    'bahasa': 'id',
    'thai': 'th',
    'th': 'th',
    'tha': 'th',
    'ไทย': 'th',
    'vietnamese': 'vi',
    'vi': 'vi',
    'vie': 'vi',
    'tiếng việt': 'vi',
    'dutch': 'nl',
    'nl': 'nl',
    'dut': 'nl',
    'nld': 'nl',
    'nederlands': 'nl',
    'polish': 'pl',
    'pl': 'pl',
    'pol': 'pl',
    'polski': 'pl',
    'swedish': 'sv',
    'sv': 'sv',
    'swe': 'sv',
    'svenska': 'sv',
    'danish': 'da',
    'da': 'da',
    'dan': 'da',
    'dansk': 'da',
    'norwegian': 'no',
    'no': 'no',
    'nor': 'no',
    'norsk': 'no',
    'finnish': 'fi',
    'fi': 'fi',
    'fin': 'fi',
    'suomi': 'fi',
    'greek': 'el',
    'el': 'el',
    'ell': 'el',
    'gre': 'el',
    'ελληνικά': 'el',
    'hebrew': 'he',
    'he': 'he',
    'heb': 'he',
    'עברית': 'he',
    'czech': 'cs',
    'cs': 'cs',
    'cze': 'cs',
    'ces': 'cs',
    'čeština': 'cs',
    'hungarian': 'hu',
    'hu': 'hu',
    'hun': 'hu',
    'magyar': 'hu',
    'romanian': 'ro',
    'ro': 'ro',
    'rum': 'ro',
    'ron': 'ro',
    'română': 'ro',
    'ukrainian': 'uk',
    'uk': 'uk',
    'ukr': 'uk',
    'українська': 'uk',
    'persian': 'fa',
    'fa': 'fa',
    'fas': 'fa',
    'per': 'fa',
    'فارسی': 'fa',
    'tagalog': 'tl',
    'tl': 'tl',
    'fil': 'tl',
    'filipino': 'tl',
    'malay': 'ms',
    'ms': 'ms',
    'msa': 'ms',
    'may': 'ms',
    'melayu': 'ms',
  };
  return map[lower];
}
