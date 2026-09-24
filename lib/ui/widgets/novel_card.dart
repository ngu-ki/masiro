import 'package:flutter/material.dart';
import 'package:masiro/misc/constant.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/url.dart';
import 'package:masiro/ui/widgets/cached_image.dart';

class NovelCard extends StatelessWidget {
  final String title;
  final String coverImg;
  final String? author;
  final String? lastUpdated;
  final String brief;

  final void Function()? onTap;

  const NovelCard({
    super.key,
    required this.title,
    required this.coverImg,
    required this.author,
    required this.lastUpdated,
    required this.brief,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return buildCard(context);
  }

  Widget buildCard(BuildContext context) {
    final textTheme = context.textTheme();
    final localizations = context.localizations();

    const horizontalPadding = 10.0;
    const verticalPadding = 8.0;
    final coverWidth = isDesktop ? 120.0 : 100.0;
    const textPaddingRight = horizontalPadding;

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: coverWidth,
              child: AspectRatio(
                aspectRatio: 7 / 10,
                child: CachedImage(
                  url: coverImg.toUrl(),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                // Keep the text column as tall as the cover so the card
                // never grows beyond its fixed size.
                height: coverWidth / coverRatio,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    textPaddingRight,
                    verticalPadding,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Measure the title first: when it is too long to leave
                      // room for the author line plus a two-line brief, drop
                      // the brief entirely instead of overflowing the card.
                      final textDirection = Directionality.of(context);
                      final titlePainter = TextPainter(
                        text: TextSpan(
                          text: title,
                          style: textTheme.titleMedium,
                        ),
                        maxLines: 4,
                        textDirection: textDirection,
                      )..layout(maxWidth: constraints.maxWidth);
                      final bodyStyle = DefaultTextStyle.of(context).style;
                      final bodyPainter = TextPainter(
                        text: TextSpan(text: ' ', style: bodyStyle),
                        maxLines: 1,
                        textDirection: textDirection,
                      )..layout(maxWidth: constraints.maxWidth);
                      final bodyLineHeight = bodyPainter.height;
                      final briefLines = isDesktop ? 3 : 2;
                      final requiredHeight = titlePainter.height +
                          6 +
                          bodyLineHeight +
                          4 +
                          bodyLineHeight * briefLines;
                      final showBrief = requiredHeight <= constraints.maxHeight;
                      titlePainter.dispose();
                      bodyPainter.dispose();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleMedium,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text.rich(
                            TextSpan(
                              text: '${localizations.author}: ',
                              children: [
                                TextSpan(
                                  text: author ?? '-',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showBrief) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${localizations.brief}: $brief',
                              maxLines: briefLines,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
