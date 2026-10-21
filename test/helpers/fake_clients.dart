import 'package:snigea/data/models/media.dart';
import 'package:snigea/providers/dramachi/dramachi_client.dart';
import 'package:snigea/providers/fourkhdhub/fourkhdhub_client.dart';
import 'package:snigea/providers/moviebox/moviebox_client.dart';

/// A MovieBox client that answers with an empty catalogue.
class FakeMovieBoxClient extends MovieBoxClient {
  @override
  Future<Object?> homepage(String tabId, int page) async => {
    'items': <Object?>[],
  };

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async =>
      const [];
}

/// A 4KHDHub client that answers with an empty catalogue.
class FakeFourKHdHubClient extends FourKHdHubClient {
  @override
  Future<List<CatalogItem>> latest() async => const [];

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async =>
      const [];
}

/// A Dramachi client that answers with an empty catalogue.
class FakeDramachiClient extends DramachiClient {
  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async =>
      const [];
}
