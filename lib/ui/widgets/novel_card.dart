import 'package:flutter/material.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/url.dart';
import 'package:masiro/ui/widgets/cached_image.dart';
import 'package:masiro/ui/widgets/manual_tooltip.dart';

class NovelCard extends StatelessWidget {
  final String title;
  final String coverImg;
  final String? author;
  final String? lastUpdated;
  final String brief;
  final int lvLimit;

  /// The callbacks for the manual sort mode. When [onMoveUp] and [onMoveDown]
  /// are both null, the manual sort controls are hidden.
  final void Function()? onTap;
  final void Function()? onMoveUp;
  final void Function()? onMoveDown;

  const NovelCard({
    super.key,
    required this.title,
    required this.coverImg,
    required this.author,
    required this.lastUpdated,
    required this.brief,
    required this.lvLimit,
    this.onTap,
    this.onMoveUp,
    this.onMoveDown,
  });

  bool get _showManualControls => onMoveUp != null || onMoveDown != null;

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();
    const cardMargin = 4.0;

    return Stack(
      children: [
        buildCard(context),
        if (lvLimit > 0 && !_showManualControls)
          Positioned(
            top: cardMargin,
            right: cardMargin,
            child: ManualTooltip(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: localizations.levelLimitMessage(lvLimit),
            ),
          ),
        if (_showManualControls)
          Positioned(
            top: cardMargin,
            bottom: cardMargin,
            right: cardMargin,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  onPressed: onMoveUp,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                  onPressed: onMoveDown,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget buildCard(BuildContext context) {
    final textTheme = context.textTheme();
    final localizations = context.localizations();

    const horizontalPadding = 10.0;
    const verticalPadding = 8.0;
    const manualControlsWidth = 48.0;
    final coverWidth = isDesktop ? 120.0 : 100.0;
    final textPaddingRight =
        _showManualControls ? horizontalPadding + manualControlsWidth : horizontalPadding;

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
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  textPaddingRight,
                  verticalPadding,
                ),
                child: Column(
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
                    Text(
                      '${localizations.brief}: $brief',
                      maxLines: isDesktop ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
