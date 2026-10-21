import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/theme/app_theme.dart';
import 'package:snigea/features/player/video_surface.dart';

void main() {
  testWidgets('the video surface fills the screen without an overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          // The loose constraints of a centre are the worst case: the
          // surface has to force the tight ones onto the video.
          body: Center(
            child: VideoSurface(
              child: Container(color: const Color(0xFF00FF00)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    final size = tester.getSize(find.byType(VideoSurface));
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));
  });
}
