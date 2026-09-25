import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    // Use the surface color (white in light mode, dark in night mode) as
    // the placeholder so that a brief re-decode after the in-memory image
    // cache evicts a cover is visually indistinguishable from the card.
    final backgroundColor = Theme.of(context).colorScheme.surface;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode at the actual on-screen pixel size (display size times the
        // device pixel ratio) instead of the source resolution: covers in
        // the grid may be displayed at ~100dp while the source is several
        // times larger, so full-resolution decoding wastes decode time,
        // memory and per-frame GPU bandwidth. ResizeImage keeps aspect
        // ratio, so this never distorts the image.
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _targetPixels(
          width,
          constraints.maxWidth,
          devicePixelRatio,
        );
        final cacheHeight = _targetPixels(
          height,
          constraints.maxHeight,
          devicePixelRatio,
        );
        return CachedNetworkImage(
          width: width,
          height: height,
          imageUrl: url,
          fit: fit,
          memCacheWidth: cacheWidth,
          memCacheHeight: cacheHeight,
          // Show cached images immediately instead of fading them in, which
          // otherwise looks like the image is being reloaded on every
          // rebuild.
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          progressIndicatorBuilder: (context, url, progress) {
            return ColoredBox(color: backgroundColor);
          },
          errorWidget: (context, url, error) {
            return ColoredBox(
              color: backgroundColor,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Converts an extent (explicit [extent] when given, otherwise the
  /// bounded [constraint]) into physical pixels, or null when unbounded.
  int? _targetPixels(double? extent, double constraint, double dpr) {
    final value = extent ?? (constraint.isFinite ? constraint : null);
    if (value == null || value <= 0) {
      return null;
    }
    return (value * dpr).round();
  }
}
