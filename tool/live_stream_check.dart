// Verifies that the MovieBox provider resolves real media links.
//
// Run it with `dart run tool/live_stream_check.dart [title]`.
import 'package:dio/dio.dart';
import 'package:snigea/providers/moviebox/moviebox_client.dart';

Future<void> main(List<String> arguments) async {
  final query = arguments.isEmpty ? 'Dune' : arguments.first;
  final client = MovieBoxClient();
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (s) => s != null && s < 600,
    ),
  );

  final results = await client.search(query);
  if (results.isEmpty) {
    print('no search results');
    return;
  }

  for (final item in results.take(3)) {
    print('--- ${item.title} (${item.year}) ---');
    final releases = await client.episodeStreams(item.id.value, 0, 0);
    print('  releases: ${releases.length}');
    for (final release in releases.take(4)) {
      final url = release.directUrl;
      final host = url == null ? '-' : Uri.tryParse(url)?.host;
      print(
        '  ${release.quality} ${release.codec} '
        'size=${release.sizeBytes != null ? (release.sizeBytes! / 1048576).round() : '-'}MB '
        'host=$host',
      );
      if (url == null) continue;
      var request = dio.get<ResponseBody>(
        url,
        options: Options(
          headers: {
            for (final header in release.mirrors.first.headers)
              header.key: header.value,
            'Range': 'bytes=0-31',
          },
          responseType: ResponseType.stream,
        ),
      );
      final response = await request;
      final bytes = <int>[];
      await for (final chunk in response.data!.stream) {
        bytes.addAll(chunk);
        if (bytes.length >= 32) break;
      }
      final isMp4 =
          bytes.length >= 4 &&
          String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp';
      print(
        '      http=${response.statusCode} type='
        '${response.headers.value('content-type')} mp4=$isMp4',
      );
    }
  }
}
