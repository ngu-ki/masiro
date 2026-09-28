import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/chapter_detail.dart';
import 'package:masiro/data/repository/model/read_position.dart';

/// A contiguous run of lines from a single text element that is rendered as
/// one [Text] widget on a page.
class ReaderTextRun {
  final int elementIndex;

  /// The start character offset (inclusive) within the element text.
  final int start;

  /// The end character offset (exclusive) within the element text.
  final int end;

  /// The total height of the run, in logical pixels.
  final double height;

  const ReaderTextRun({
    required this.elementIndex,
    required this.start,
    required this.end,
    required this.height,
    this.isBlankGap = false,
  });

  /// Whether this run is a shrunk blank line (e.g. a paragraph made of
  /// `&nbsp;`) rendered as a small gap instead of a full text line.
  final bool isBlankGap;
}

/// The paginated content of a single reader page.
class ReaderPageContent {
  final List<ReaderTextRun> runs;

  /// The element index of the image when this page is a full page image.
  final int? imageElementIndex;

  final ImageContent? image;

  const ReaderPageContent({
    this.runs = const [],
    this.imageElementIndex,
    this.image,
  });

  bool isImagePage() {
    return image != null;
  }

  /// Returns the index of the last element that appears on this page.
  int get lastElementIndex {
    if (isImagePage()) {
      return imageElementIndex!;
    }
    return runs.last.elementIndex;
  }
}

/// Splits the chapter content elements into pages that fit within
/// [maxWidth] x [maxHeight].
///
/// Each paragraph (text element) is measured with a [TextPainter] and split
/// into lines; lines are then packed into pages. A full page image always
/// occupies a page of its own.
/// Whether [text] consists solely of white space, including no-break spaces
/// (`&nbsp;`) and full-width spaces used by some sources.
bool isBlankTextLine(String text) => text
    .replaceAll('\u00A0', '')
    .replaceAll('\u3000', '')
    .trim()
    .isEmpty;

List<ReaderPageContent> paginateChapterContent({
  required List<ChapterContentElement> elements,
  required double maxWidth,
  required double maxHeight,
  required TextStyle style,
  required double paragraphGap,
  String indentPrefix = '',
  bool shrinkEmptyLines = false,

  /// The height a blank line (e.g. a paragraph made only of `&nbsp;`)
  /// collapses to when [shrinkEmptyLines] is enabled.
  double blankGap = 0.0,
  double firstPageHeaderHeight = 0.0,
}) {
  final pages = <ReaderPageContent>[];
  var currentRuns = <ReaderTextRun>[];
  var usedHeight = 0.0;

  // Space reserved on the first page for the chapter title rendered above
  // the body text. Consumed before the first run is placed.
  var pendingHeaderHeight = firstPageHeaderHeight;

  void flush() {
    if (currentRuns.isNotEmpty) {
      pages.add(ReaderPageContent(runs: List.of(currentRuns)));
      currentRuns = <ReaderTextRun>[];
      usedHeight = 0.0;
    }
  }

  for (var elementIndex = 0; elementIndex < elements.length; elementIndex++) {
    final element = elements[elementIndex];

    if (element is ImageContent) {
      flush();
      // A chapter starting with a full-page image has no room for the
      // chapter title header; drop the reservation to avoid a blank gap.
      pendingHeaderHeight = 0.0;
      pages.add(
        ReaderPageContent(image: element, imageElementIndex: elementIndex),
      );
      continue;
    }

    final text = (element as TextContent).text;
    if (text.isEmpty) {
      continue;
    }

    // Blank lines (e.g. paragraphs made only of `&nbsp;`) are collapsed into
    // a small gap so adjacent paragraphs are not separated too far.
    if (shrinkEmptyLines && isBlankTextLine(text)) {
      // Drop blanks at the top of a page and collapse consecutive blanks.
      if (currentRuns.isEmpty || currentRuns.last.isBlankGap) {
        continue;
      }
      if (usedHeight + blankGap > maxHeight) {
        flush();
      } else {
        currentRuns.add(
          ReaderTextRun(
            elementIndex: elementIndex,
            start: 0,
            end: 0,
            height: blankGap,
            isBlankGap: true,
          ),
        );
        usedHeight += blankGap;
      }
      continue;
    }

    // The indentation prefix is part of the laid out text so that the first
    // line is offset by the requested number of character cells.
    final displayText = '$indentPrefix$text';

    final painter = TextPainter(
      text: TextSpan(text: displayText, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout(minWidth: 0, maxWidth: maxWidth);
    final metrics = painter.computeLineMetrics();

    // The character offset at which each line starts.
    final lineStarts = <int>[];
    for (final metric in metrics) {
      final lineTop = metric.baseline - metric.height;
      final position = painter.getPositionForOffset(Offset(0, lineTop + 1));
      lineStarts.add(position.offset);
    }

    for (var line = 0; line < metrics.length; line++) {
      final lineHeight = metrics[line].height;
      final start = lineStarts[line];
      final end = line + 1 < metrics.length
          ? lineStarts[line + 1]
          : displayText.length;
      if (end < start) {
        continue;
      }

      // Reserve paragraph spacing when an element starts on a page that
      // already has content.
      if (line == 0 && currentRuns.isNotEmpty) {
        if (usedHeight + paragraphGap + lineHeight > maxHeight) {
          flush();
        } else {
          usedHeight += paragraphGap;
        }
      }

      // Consume the chapter title reservation before the very first run,
      // so the first page leaves room for the rendered title.
      if (pendingHeaderHeight > 0.0 && currentRuns.isEmpty) {
        usedHeight += pendingHeaderHeight;
        pendingHeaderHeight = 0.0;
      }

      if (currentRuns.isNotEmpty && usedHeight + lineHeight > maxHeight) {
        flush();
      }

      // Extend the previous run when the line belongs to the same element.
      final lastRun = currentRuns.isNotEmpty ? currentRuns.last : null;
      if (lastRun != null &&
          lastRun.elementIndex == elementIndex &&
          lastRun.end == start) {
        currentRuns[currentRuns.length - 1] = ReaderTextRun(
          elementIndex: elementIndex,
          start: lastRun.start,
          end: end,
          height: lastRun.height + lineHeight,
        );
      } else {
        currentRuns.add(
          ReaderTextRun(
            elementIndex: elementIndex,
            start: start,
            end: end,
            height: lineHeight,
          ),
        );
      }
      usedHeight += lineHeight;
    }
    painter.dispose();
  }

  flush();

  if (pages.isEmpty) {
    pages.add(const ReaderPageContent());
  }
  return pages;
}

/// Finds the page that contains the given read position.
int pageIndexOfPosition(
  List<ReaderPageContent> pages,
  ReadPosition position,
) {
  final elementIndex = position.elementIndex;
  final characterIndex = position.elementCharacterIndex ?? 0;

  for (var i = 0; i < pages.length; i++) {
    final page = pages[i];
    if (page.isImagePage()) {
      if (page.imageElementIndex! >= elementIndex) {
        return i;
      }
      continue;
    }
    final lastRun = page.runs.last;
    final isAfterPosition = lastRun.elementIndex > elementIndex ||
        (lastRun.elementIndex == elementIndex && lastRun.end > characterIndex);
    if (isAfterPosition) {
      return i;
    }
  }
  return pages.isEmpty ? 0 : pages.length - 1;
}
