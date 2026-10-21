import 'package:flutter/material.dart';

/// The surface that hosts the video output.
///
/// The video is sized to its own aspect ratio. A video widget that fills the
/// whole screen creates a surface that is larger than the buffer that the
/// decoder allocates, and Android then rejects every buffer, which shows a
/// black screen while the audio plays.
class VideoSurface extends StatelessWidget {
  const VideoSurface({super.key, required this.child, this.aspectRatio});

  /// The video output.
  final Widget child;

  /// The aspect ratio of the video, when it is known.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    // Until the decoder reports the size, the common 16:9 ratio is used, so
    // the surface never covers the whole window.
    final ratio =
        (aspectRatio != null && aspectRatio!.isFinite && aspectRatio! > 0)
        ? aspectRatio!
        : 16 / 9;
    return Center(
      child: AspectRatio(aspectRatio: ratio, child: child),
    );
  }
}
