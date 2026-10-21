// Verifies that every provider resolves a playable source.
import 'package:dio/dio.dart';
import 'package:snigea/providers/dramachi/dramachi_client.dart';
import 'package:snigea/providers/fourkhdhub/fourkhdhub_client.dart';
import 'package:snigea/providers/moviebox/moviebox_client.dart';
import 'package:snigea/services/playback_service.dart';

Future<void> probe(String url, List<MapEntry<String, String>> headers) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (s) => s != null && s < 600,
    ),
  );
  try {
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        headers: {
          for (final header in headers) header.key: header.value,
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
  } catch (error) {
    print('      probe failed: $error');
  }
}

Future<void> main() async {
  final service = PlaybackService(
    fourKHdHub: FourKHdHubClient(),
    movieBox: MovieBoxClient(),
  );

  // MovieBox
  try {
    final movieBox = MovieBoxClient();
    final results = await movieBox.search('Dune');
    final releases = await movieBox.episodeStreams(
      results.first.id.value,
      0,
      0,
    );
    final source = await service.resolve(
      releases.first,
      subjectId: results.first.id.value,
    );
    print('MovieBox: ${source.url.split('?').first}');
    await probe(source.url, source.headers);
  } catch (error) {
    print('MovieBox: $error');
  }

  // 4KHDHub
  try {
    final fourK = FourKHdHubClient();
    final results = await fourK.search('Dune');
    print('4KHDHub results: ${results.length}');
    final details = await fourK.details(results.first.id.value);
    final releases = await fourK.episodeStreams(results.first.id.value, 0, 0);
    print('4KHDHub releases: ${releases.length}');
    if (releases.isNotEmpty) {
      final source = await service.resolve(releases.first);
      print('  source: ${source.url.split('?').first}');
      print('  label: ${source.sourceLabel}');
      await probe(source.url, source.headers);
    }
  } catch (error) {
    print('4KHDHub: $error');
  }

  // Dramachi
  try {
    final dramachi = DramachiClient();
    final results = await dramachi.search('Queen of Tears');
    print('Dramachi results: ${results.length}');
    if (results.isNotEmpty) {
      final releases = await dramachi.episodeStreams(
        results.first.id.value,
        1,
        1,
      );
      print('Dramachi releases: ${releases.length}');
      if (releases.isNotEmpty) {
        final source = await service.resolve(releases.first);
        print('  source: ${source.url.split('?').first}');
        await probe(source.url, source.headers);
      }
    }
  } catch (error) {
    print('Dramachi: $error');
  }
}
