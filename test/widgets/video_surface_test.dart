import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/features/player/video_surface.dart';

void main() {
  testWidgets('the surface uses the aspect ratio of the video', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              VideoSurface(
                aspectRatio: 2,
                child: ColoredBox(key: ValueKey('video'), color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );

    // The video output is as wide as the screen and half as high.
    final size = tester.getSize(find.byKey(const ValueKey('video')));
    expect(size.width, 800);
    expect(size.height, 400);
  });

  testWidgets('the surface falls back to 16:9 while the size is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              VideoSurface(
                child: ColoredBox(key: ValueKey('video'), color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const ValueKey('video')));
    expect(size.width, 800);
    expect(size.height, 450);
  });

  testWidgets('the surface never covers the whole window', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              VideoSurface(
                child: ColoredBox(key: ValueKey('video'), color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );

    // A surface that fills the window makes Android reject the video
    // buffers, which shows a black screen while the audio plays.
    final size = tester.getSize(find.byKey(const ValueKey('video')));
    expect(size.height, lessThan(600));
  });
}
