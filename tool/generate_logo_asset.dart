import 'dart:io';

import 'package:image/image.dart' as img;

/// Creates the in app logo from the launcher icon source image.
///
/// The launcher icons of every platform are generated with
/// `dart run flutter_launcher_icons`. This script creates the smaller
/// variant that the application draws next to the wordmark, so the bundle
/// does not have to ship the 1254 pixel source image.
void main(List<String> arguments) {
  const source = 'assets/icon/Snigea.png';
  const target = 'assets/icon/snigea_logo.png';
  const size = 256;

  final file = File(source);
  if (!file.existsSync()) {
    stderr.writeln('The source image $source is missing.');
    exitCode = 1;
    return;
  }

  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) {
    stderr.writeln('The source image $source could not be decoded.');
    exitCode = 1;
    return;
  }

  final resized = img.copyResize(
    image,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );

  File(target).writeAsBytesSync(img.encodePng(resized, level: 9));
  stdout.writeln(
    '$target written (${resized.width}x${resized.height}, '
    '${File(target).lengthSync()} bytes).',
  );
}
