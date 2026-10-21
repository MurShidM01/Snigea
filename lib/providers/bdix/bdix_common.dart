/// Shared heuristics for the BDIX providers.
///
/// The detection rules mirror the reference implementation exactly.
library;

/// Detects the audio language advertised by a release name.
String? detectBdixAudioLanguage(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('hindi')) return 'Hindi';
  if (lower.contains('bengali') || lower.contains('bangla')) return 'Bengali';
  if (lower.contains('tamil')) return 'Tamil';
  if (lower.contains('telugu')) return 'Telugu';
  if (lower.contains('dual')) return 'Dual Audio';
  if (lower.contains('multi')) return 'Multi Audio';
  if (lower.contains('english')) return 'English';
  return null;
}

/// Detects the resolution advertised by a release name.
String? detectBdixResolution(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('2160p') || lower.contains('4k')) return '4K';
  if (lower.contains('1080p')) return '1080p';
  if (lower.contains('720p')) return '720p';
  if (lower.contains('480p')) return '480p';
  return null;
}

/// Detects the codec advertised by a release name.
String? detectBdixCodec(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('x265') || lower.contains('hevc')) return 'HEVC';
  if (lower.contains('x264') || lower.contains('h264')) return 'x264';
  if (lower.contains('av1')) return 'AV1';
  return null;
}
