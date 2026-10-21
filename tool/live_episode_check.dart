// Verifies the series episode resolution of the MovieBox provider.
import 'package:dio/dio.dart';
import 'package:snigea/providers/moviebox/moviebox_client.dart';

Future<void> main(List<String> arguments) async {
  final query = arguments.isEmpty ? 'Breaking Bad' : arguments.first;
  final client = MovieBoxClient();
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (s) => s != null && s < 600,
    ),
  );

  final results = await client.search(query);
  final series = results.where((item) => item.isSeries).toList();
  if (series.isEmpty) {
    print('no series found');
    return;
  }
  final item = series.first;
  print('series: ${item.title} (${item.id.value})');

  final details = await client.details(item.id.value);
  print('seasons: ${details.seasons.length}');
  for (final season in details.seasons.take(2)) {
    print('  season ${season.number}: ${season.episodes.length} episodes');
  }

  for (final episode in [1, 2]) {
    try {
      final releases = await client.episodeStreams(item.id.value, 1, episode);
      print('S01E$episode -> ${releases.length} releases');
      for (final release in releases.take(3)) {
        final url = release.directUrl;
        print(
          '  ${release.quality} ${release.codec} '
          's=${release.season} e=${release.episode} '
          'size=${release.sizeBytes != null ? (release.sizeBytes! / 1048576).round() : '-'}MB '
          'host=${url == null ? '-' : Uri.tryParse(url)?.host}',
        );
        if (url == null) continue;
        final response = await dio.get<ResponseBody>(
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
        final bytes = <int>[];
        await for (final chunk in response.data!.stream) {
          bytes.addAll(chunk);
          if (bytes.length >= 32) break;
        }
        final isMp4 =
            bytes.length >= 4 &&
            String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp';
        print(
          '      http=${response.statusCode} '
          'type=${response.headers.value('content-type')} mp4=$isMp4',
        );
      }
    } catch (error) {
      print('S01E$episode -> $error');
    }
  }
}
