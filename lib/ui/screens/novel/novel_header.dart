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

    // Chapter line: "共171话 · 281.2万字"; the word count is appended only
    // when the site actually reported one.
    final chaptersText = header.words > 0
        ? '${localizations.totalChapters(widget.chapterCount)} · ${localizations.wanWords(formatWordCount(header.words))}'
        : localizations.totalChapters(widget.chapterCount);

    return Row(
      children: [
        SizedBox(
          width: coverWidth,
          height: coverWidth / coverRatio,
          child: Stack(
            children: [
              CachedImage(
                url: header.coverImg.toUrl(),
                width: coverWidth,
                height: coverWidth / coverRatio,
                fit: BoxFit.cover,
              ),
            ],
          ),
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
                    style: const TextStyle(fontSize: 19),
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
                  chaptersText,
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

/// Formats a raw word count in 万 units: 2811659 -> "281.2", 100000 -> "10".
String formatWordCount(int words) {
  final wan = words / 10000;
  return wan.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}
