import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';

/// A shimmering placeholder used while content is loading.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppSpacing.radiusMd,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - value), 0),
              end: Alignment(1 - 2 * (1 - value), 0),
              colors: [
                context.colors.surfaceElevated,
                context.colors.surfaceHigh,
                context.colors.surfaceElevated,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A poster image with a graceful fallback.
///
/// The image is decoded at the size it is displayed at, which keeps the
/// memory footprint of a full catalogue small.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppSpacing.radiusMd,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _fallback(context);
    }

    // The width can be infinite inside a grid, which would produce an
    // invalid decode size and the image would never load.
    final decodeWidth = (width != null && width!.isFinite)
        ? (width! * MediaQuery.devicePixelRatioOf(context)).round()
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: decodeWidth,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (context, _) => ShimmerBox(
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
        errorWidget: (context, _, _) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: context.colors.surfaceHigh,
        border: Border.all(color: context.colors.border),
      ),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: context.colors.textTertiary,
          size: 26,
        ),
      ),
    );
  }
}

/// A wide backdrop image with a gradient scrim.
class BackdropImage extends StatelessWidget {
  const BackdropImage({
    super.key,
    required this.url,
    this.height = 320,
    this.alignment = Alignment.topCenter,
  });

  final String? url;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.colors.surfaceHigh, context.colors.background],
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            alignment: alignment,
            fadeInDuration: Duration(milliseconds: 200),
            placeholder: (context, _) => ShimmerBox(borderRadius: 0),
            errorWidget: (context, _, _) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.colors.surfaceHigh,
                    context.colors.background,
                  ],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.colors.scrim.withValues(alpha: 0.45),
                  context.colors.background.withValues(alpha: 0.82),
                  context.colors.background,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
