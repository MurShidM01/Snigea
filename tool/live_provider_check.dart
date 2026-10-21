// A small utility that verifies the live provider behaviour.
//
// Run it with `dart run tool/live_provider_check.dart`. The script talks to
// the real MovieBox API, therefore it needs a network connection. It only
// prints metadata and host names, never a signed URL or a session token.
import 'package:snigea/core/json/json_utils.dart';
import 'package:snigea/providers/moviebox/moviebox_client.dart';
import 'package:snigea/providers/moviebox/moviebox_parser.dart';

Future<void> main(List<String> arguments) async {
  final query = arguments.isEmpty ? 'Inception' : arguments.first;
  final client = MovieBoxClient();

  try {
    final token = await client.ensureSession();
    print('session established (${token.length} characters)');

    final results = await client.search(query);
    print('search "$query" -> ${results.length} results');
    for (final item in results.take(5)) {
      print(
        '  ${item.id.value} | ${item.title} | ${item.year} | '
        '${item.mediaType.name}',
      );
    }
    if (results.isEmpty) return;

    final details = await client.details(results.first.id.value);
    print(
      'details: ${details.title} (${details.year}) '
      'rating=${details.imdbRating} duration=${details.duration}',
    );
    print('  seasons: ${details.seasons.length}');

    final releases = await client.episodeStreams(
      results.first.id.value,
      details.isSeries ? 1 : 0,
      details.isSeries ? 1 : 0,
    );
    print('releases: ${releases.length}');
    for (final release in releases.take(5)) {
      final host = Uri.tryParse(release.directUrl ?? '')?.host ?? '-';
      print(
        '  ${release.quality} ${release.codec} size=${release.sizeBytes} '
        'host=$host',
      );
    }

    final payload = await client.playInfo(results.first.id.value, 0, 0);
    final streams = asList(asMap(payload)?['streams']) ?? const [];
    print('play-info streams: ${streams.length}');
  } catch (error) {
    print('FAILED: $error');
  }
}
