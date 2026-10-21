import 'package:flutter/material.dart';

/// The logo of Snigea.
///
/// The image is the launcher icon of every platform, reduced to the size that
/// the interface needs. It is generated from `assets/icon/Snigea.png` with
/// `dart run tool/generate_logo_asset.dart`.
class SnigeaLogo extends StatelessWidget {
  const SnigeaLogo({super.key, this.size = 28});

  /// The edge length of the logo in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/snigea_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
  }
}
