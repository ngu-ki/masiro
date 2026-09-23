import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/volume.dart';
import 'package:masiro/misc/context.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// The bottom sheet listing all volumes and chapters of the novel.
/// The current chapter is highlighted and scrolled into view initially.
class ContentsSheet extends StatelessWidget {
  final List<Volume> volumes;
  final int currentChapterId;
  final void Function(int chapterId) onNavigateTo;

  const ContentsSheet({
    super.key,
    required this.volumes,
    required this.currentChapterId,
    required this.onNavigateTo,
  });

  int _indexOfCurrentChapter(List<_ContentsEntry> entries) {
    return entries.indexWhere(
      (entry) => entry.chapter?.id == currentChapterId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();
    final theme = Theme.of(context);
    final entries = <_ContentsEntry>[
      for (final volume in volumes) ...[
        _ContentsEntry(title: volume.title),
        for (final chapter in volume.chapters)
          _ContentsEntry(chapter: chapter),
      ],
    ];
    final initialIndex = _indexOfCurrentChapter(entries).clamp(
      0,
      entries.length - 1,
    );

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      width: double.infinity,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              localizations.contents,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ScrollablePositionedList.builder(
              initialScrollIndex: initialIndex,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final chapter = entry.chapter;
                if (chapter == null) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      top: index == 0 ? 8 : 24,
                      bottom: 4,
                    ),
                    child: Text(
                      entry.title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                final isCurrent = chapter.id == currentChapterId;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? theme.colorScheme.primary
                          : Colors.black,
                      fontWeight: isCurrent ? FontWeight.bold : null,
                    ),
                  ),
                  onTap: () => onNavigateTo(chapter.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentsEntry {
  final String? title;
  final Chapter? chapter;

  const _ContentsEntry({this.title, this.chapter});
}
