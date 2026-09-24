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
    return CachedNetworkImage(
      width: width,
      height: height,
      imageUrl: url,
      fit: fit,
      // Show cached images immediately instead of fading them in, which
      // otherwise looks like the image is being reloaded on every rebuild.
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
  }
}
