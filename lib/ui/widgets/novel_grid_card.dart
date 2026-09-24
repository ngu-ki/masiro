import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/bookshelf_stat.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/url.dart';
import 'package:masiro/ui/widgets/cached_image.dart';

/// The bookshelf card used in the grid display mode.
///
/// The cover keeps a 7:10 aspect ratio; the title is sized so that each line
/// can hold about 8 Chinese characters and is limited to 3 lines.
class NovelGridCard extends StatelessWidget {
  final String title;
  final String coverImg;

  /// Reading progress of the novel. When available, the badge always
  /// shows the read/total chapter counts.
  final BookshelfStat? stat;

  final void Function()? onTap;

  /// Called when the title or stats area is tapped (navigates to detail).
  final void Function()? onDetailTap;

  /// Called when the vertical more button is tapped.
  final void Function()? onMore;

  const NovelGridCard({
    super.key,
    required this.title,
    required this.coverImg,
    this.stat,
    this.onTap,
    this.onDetailTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme();

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 4.0;

        // Size the title so that one line can fit about 8 Chinese characters
        // (a CJK glyph is roughly as wide as the font size).
        final titleFontSize =
            ((constraints.maxWidth - horizontalPadding * 2) / 8)
                .clamp(10.0, 13.0);
        final unreadFontSize = (titleFontSize - 2).clamp(9.0, 11.0);
        final titleHeight = titleFontSize * 1.4 * 3;
        final unread = stat?.unreadCount ?? 0;
        final total = stat?.totalChapters ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 7 / 10,
                    child: CachedImage(
                      url: coverImg.toUrl(),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: onDetailTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    SizedBox(
                      height: titleHeight,
                      child: Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          if (total > 0)
                            Expanded(
                              child: Text(
                                '${total - unread}话/$total话',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: unreadFontSize,
                                  color: colorScheme.outline,
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          InkWell(
                            onTap: onMore,
                            child: Icon(
                              Icons.more_vert_rounded,
                              size: 16,
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
