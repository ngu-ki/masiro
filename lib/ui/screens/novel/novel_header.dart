import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/novel_detail.dart';
import 'package:masiro/misc/constant.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/url.dart';
import 'package:masiro/ui/widgets/cached_image.dart';

class NovelHeader extends StatefulWidget {
  final NovelDetailHeader header;

  /// Total number of chapters across all volumes.
  final int chapterCount;

  /// Called when the author name is tapped.
  final void Function(String author)? onAuthorTap;

  const NovelHeader({
    super.key,
    required this.header,
    required this.chapterCount,
    this.onAuthorTap,
  });

  @override
  State<NovelHeader> createState() => _NovelHeaderState();
}

class _NovelHeaderState extends State<NovelHeader> {
  TapGestureRecognizer? _authorTapRecognizer;

  @override
  void dispose() {
    _authorTapRecognizer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();
    final textTheme = context.textTheme();
    final header = widget.header;
    const coverWidth = 160.0;

    final onAuthorTap = widget.onAuthorTap;
    if (onAuthorTap != null) {
      _authorTapRecognizer?.dispose();
      _authorTapRecognizer = TapGestureRecognizer()
        ..onTap = () => onAuthorTap(header.author);
    }

    return Row(
      children: [
        CachedImage(
          url: header.coverImg.toUrl(),
          width: coverWidth,
          height: coverWidth / coverRatio,
          fit: BoxFit.cover,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    header.title,
                    style: textTheme.titleLarge,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: '${localizations.author}: ',
                    style: textTheme.bodyLarge,
                    children: [
                      TextSpan(
                        text: header.author,
                        style: textTheme.bodyLarge?.copyWith(
                          color: Colors.blue,
                        ),
                        recognizer: _authorTapRecognizer,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${localizations.translator}: ${header.translators.join(', ')}',
                  style: textTheme.bodyLarge,
                ),
                Text(
                  '${localizations.status}: ${header.status}',
                  style: textTheme.bodyLarge,
                ),
                Text(
                  localizations.totalChapters(widget.chapterCount),
                  style: textTheme.bodyLarge,
                ),
                if (isDesktop)
                  Text(
                    '${localizations.originalBook}: ${header.originalBook}',
                    style: textTheme.bodyLarge,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
