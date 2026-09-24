import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/chapter_detail.dart';
import 'package:masiro/data/repository/model/indent_mode.dart';
import 'package:masiro/data/repository/model/page_turn_mode.dart';
import 'package:masiro/data/repository/model/read_position.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/render.dart';
import 'package:masiro/ui/screens/reader/pagination.dart';
import 'package:masiro/ui/widgets/cached_image.dart';

/// Controller that allows the menu slider to jump to a position fraction of
/// the current chapter.
class ReaderPagerController {
  void Function(double fraction)? _seekTo;

  bool get isEnabled => _seekTo != null;

  void seekToFraction(double fraction) {
    _seekTo?.call(fraction.clamp(0.0, 1.0));
  }
}

/// Displays the chapter content with page turn modes:
/// slide and none (instant).
///
/// The screen is divided into three tap zones: the left third turns to the
/// previous page, the right third turns to the next page and the middle
/// toggles the menu. On the last page of a chapter, turning the page again
/// navigates to the next chapter.
class ChapterContentPager extends StatefulWidget {
  final PageTurnMode mode;
  final ChapterContent content;
  final int chapterId;
  final int fontSize;
  final Color textColor;
  final Color backgroundColor;
  final EdgeInsets padding;
  final ReadPosition initialPosition;
  final ReadPosition Function() getCurrentPosition;
  final ValueNotifier<double> progressNotifier;
  final void Function(ReadPosition position)? onPositionChange;
  final void Function() onToggleMenu;
  final void Function() onNextChapter;
  final ReaderPagerController pagerController;
  final IndentMode indentMode;
  final bool shrinkEmptyLines;

  /// Title of the current chapter, shown at the top of the first page.
  final String chapterTitle;

  const ChapterContentPager({
    super.key,
    required this.mode,
    required this.content,
    required this.chapterId,
    required this.fontSize,
    required this.textColor,
    required this.backgroundColor,
    required this.padding,
    required this.initialPosition,
    required this.getCurrentPosition,
    required this.progressNotifier,
    this.onPositionChange,
    required this.onToggleMenu,
    required this.onNextChapter,
    required this.pagerController,
    this.indentMode = IndentMode.none,
    this.shrinkEmptyLines = false,
    required this.chapterTitle,
  });

  @override
  State<ChapterContentPager> createState() => _ChapterContentPagerState();
}

class _ChapterContentPagerState extends State<ChapterContentPager> {
  static const _tapSlop = 20.0;
  static const _tapDurationBudget = 400;
  static const _dragThreshold = 60.0;
  static const _chapterEndOverscrollThreshold = 80.0;

  List<ReaderPageContent> _pages = const [];
  String _layoutSignature = '';
  String _configSignature = '';
  ReadPosition? _pendingRestore;
  int _currentPage = 0;

  PageController? _pageController;

  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  double _chapterEndOverscroll = 0.0;

  @override
  void initState() {
    super.initState();
    _configSignature = _buildConfigSignature();
    _pendingRestore = widget.initialPosition;
    widget.pagerController._seekTo = _seekToFraction;
  }

  @override
  void didUpdateWidget(covariant ChapterContentPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSignature = _buildConfigSignature();
    if (newSignature != _configSignature) {
      _configSignature = newSignature;
      // Restore the page that contains the latest read position after
      // re-pagination (e.g. chapter change or font size change).
      _pendingRestore = widget.getCurrentPosition();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  String _buildConfigSignature() {
    return '${widget.chapterId}-${widget.fontSize}-${widget.mode.name}'
        '-${widget.indentMode.name}-${widget.shrinkEmptyLines}';
  }

  TextStyle _buildTextStyle(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    return defaultStyle.copyWith(
      fontSize: widget.fontSize.toDouble(),
      color: widget.textColor,
      height: 1.5,
    );
  }

  /// Style of the chapter title: bold and two points larger than the body.
  TextStyle _buildTitleStyle(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    return defaultStyle.copyWith(
      fontSize: (widget.fontSize + 2).toDouble(),
      fontWeight: FontWeight.bold,
      color: widget.textColor,
      height: 1.5,
    );
  }

  /// Paragraph spacing. With blank-line shrinking on it is 1.5x the line
  /// spacing (line height is 1.5x the font size, so line spacing is 0.5x
  /// the font size); otherwise a slightly tighter default.
  double _buildParagraphGap() {
    return widget.shrinkEmptyLines
        ? widget.fontSize * 0.75
        : widget.fontSize * 0.65;
  }

  /// Fixed blank line between the chapter title and the body on the first
  /// page (one body line). Always applied, independent of the
  /// shrink-empty-lines setting.
  double _buildTitleBodyGap() {
    return widget.fontSize * 1.5;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = _buildTextStyle(context);
        final titleStyle = _buildTitleStyle(context);
        final paragraphGap = _buildParagraphGap();
        final titleBodyGap = _buildTitleBodyGap();
        // Separation across a shrunk blank line is 2.5x the line spacing
        // (1.25x the font size) in total; it consists of this blank gap
        // plus one paragraph gap.
        final blankGap = widget.fontSize * 1.25 - paragraphGap;
        final mediaQuery = MediaQuery.of(context);
        final topInset = mediaQuery.padding.top + 44;
        final bottomInset = mediaQuery.padding.bottom + 44;
        final contentWidth =
            constraints.maxWidth - widget.padding.horizontal;
        final contentHeight = constraints.maxHeight - topInset - bottomInset;

        // Measure the chapter title so the first page reserves its height.
        final titlePainter = TextPainter(
          text: TextSpan(text: widget.chapterTitle, style: titleStyle),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: contentWidth);
        final headerHeight = titlePainter.height + titleBodyGap;
        titlePainter.dispose();

        final signature =
            '$_configSignature-${contentWidth.toStringAsFixed(1)}x${contentHeight.toStringAsFixed(1)}';
        if (signature != _layoutSignature) {
          _layoutSignature = signature;
          _pages = paginateChapterContent(
            elements: widget.content.elements,
            maxWidth: contentWidth,
            maxHeight: contentHeight,
            style: style,
            paragraphGap: paragraphGap,
            indentPrefix: widget.indentMode.prefix,
            shrinkEmptyLines: widget.shrinkEmptyLines,
            blankGap: blankGap,
            firstPageHeaderHeight: headerHeight,
          );
          final restore = _pendingRestore ?? widget.initialPosition;
          _pendingRestore = null;
          _currentPage =
              pageIndexOfPosition(_pages, restore).clamp(0, _pages.length - 1);
          // Notify the HUD and the persistence layer after the current
          // build/layout pass to avoid marking sibling widgets dirty.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _reportProgress();
              _reportPosition(_currentPage);
            }
          });
          _pageController?.dispose();
          _pageController = PageController(initialPage: _currentPage);
        }

        final firstPage = _pages.isNotEmpty ? _pages.first : null;
        final showHeaderOnFirstPage = firstPage != null &&
            !firstPage.isImagePage() &&
            firstPage.runs.isNotEmpty;
        final pageWidgets = [
          for (var i = 0; i < _pages.length; i++)
            _buildPage(
              context,
              _pages[i],
              style,
              paragraphGap,
              blankGap,
              topInset: topInset,
              bottomInset: bottomInset,
              contentWidth: contentWidth,
              contentHeight: contentHeight,
              titleBodyGap: titleBodyGap,
              header: i == 0 && showHeaderOnFirstPage
                  ? Text(
                      widget.chapterTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    )
                  : null,
            ),
        ];
        final chapterEndPage = _buildChapterEndPage(context);

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerUp: (event) => _onPointerUp(context, event),
          child: _buildPageViewPager(pageWidgets, chapterEndPage),
        );
      },
    );
  }

  Widget _buildPageViewPager(
    List<Widget> pageWidgets,
    Widget chapterEndPage,
  ) {
    return NotificationListener<OverscrollNotification>(
      onNotification: _onOverscroll,
      child: PageView(
        controller: _pageController,
        physics: widget.mode == PageTurnMode.none
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: _onPageViewChanged,
        children: [...pageWidgets, chapterEndPage],
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    ReaderPageContent page,
    TextStyle style,
    double paragraphGap,
    double blankGap, {
    required double topInset,
    required double bottomInset,
    required double contentWidth,
    required double contentHeight,
    required double titleBodyGap,
    Widget? header,
  }) {
    if (page.isImagePage()) {
      return CachedImage(
        url: page.image!.src,
        width: contentWidth,
        height: contentHeight,
        fit: BoxFit.contain,
      );
    }

    final elements = widget.content.elements;
    final children = <Widget>[];
    var lastElementIndex = -1;
    // The chapter title already carries its own trailing gap, so the first
    // body run must not add another paragraph gap.
    var suppressNextGap = false;
    if (header != null) {
      children.add(header);
      children.add(SizedBox(height: titleBodyGap));
      suppressNextGap = true;
    }
    for (final run in page.runs) {
      if (run.isBlankGap) {
        children.add(SizedBox(height: blankGap));
        lastElementIndex = run.elementIndex;
        suppressNextGap = false;
        continue;
      }
      if (!suppressNextGap &&
          children.isNotEmpty &&
          run.elementIndex != lastElementIndex) {
        children.add(SizedBox(height: paragraphGap));
      }
      suppressNextGap = false;
      final element = elements[run.elementIndex] as TextContent;
      final displayText = '${widget.indentMode.prefix}${element.text}';
      var fragment = displayText.substring(run.start, run.end);
      if (fragment.endsWith('\n')) {
        fragment = fragment.substring(0, fragment.length - 1);
      }
      children.add(
        Text.rich(
          TextSpan(
            children: _buildFragmentSpans(
              element: element,
              fragment: fragment,
              runStart: run.start,
              prefixLength: widget.indentMode.prefix.length,
              mutedColor: widget.textColor.withValues(alpha: 0.45),
            ),
          ),
          style: style,
        ),
      );
      lastElementIndex = run.elementIndex;
    }

    return Padding(
      padding: widget.padding +
          EdgeInsets.only(top: topInset, bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// Builds the spans of a page [fragment], splitting the source-colored
  /// (muted) ranges out so they are rendered in gray.
  ///
  /// [runStart] is the fragment's start offset within
  /// `indentPrefix + element.text`; [prefixLength] is the indent prefix
  /// length, used to map element-level ranges to fragment offsets.
  List<InlineSpan> _buildFragmentSpans({
    required TextContent element,
    required String fragment,
    required int runStart,
    required int prefixLength,
    required Color mutedColor,
  }) {
    if (element.mutedRanges.isEmpty || fragment.isEmpty) {
      return [TextSpan(text: fragment)];
    }

    // Intersect the element-level muted ranges with the visible fragment.
    final textLength = element.text.length;
    final elementStart = (runStart - prefixLength).clamp(0, textLength);
    final elementEnd =
        (runStart + fragment.length - prefixLength).clamp(0, textLength);
    final localRanges = <(int, int)>[];
    for (final range in element.mutedRanges) {
      final start = range.start > elementStart ? range.start : elementStart;
      final end = range.end < elementEnd ? range.end : elementEnd;
      if (start < end) {
        // Map element offset to fragment-local offset.
        localRanges.add((prefixLength + start - runStart,
            prefixLength + end - runStart));
      }
    }
    if (localRanges.isEmpty) {
      return [TextSpan(text: fragment)];
    }
    localRanges.sort((a, b) => a.$1.compareTo(b.$1));

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final (start, end) in localRanges) {
      if (start > cursor) {
        spans.add(TextSpan(text: fragment.substring(cursor, start)));
      }
      spans.add(
        TextSpan(
          text: fragment.substring(start, end),
          style: TextStyle(color: mutedColor),
        ),
      );
      cursor = end;
    }
    if (cursor < fragment.length) {
      spans.add(TextSpan(text: fragment.substring(cursor)));
    }
    return spans;
  }

  Widget _buildChapterEndPage(BuildContext context) {
    final localizations = context.localizations();
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.backgroundColor,
      padding: widget.padding,
      alignment: Alignment.center,
      child: Text(
        localizations.chapterEndHint,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: widget.textColor.withOpacity(0.5),
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.localPosition;
    _pointerDownTime = DateTime.now();
    _chapterEndOverscroll = 0.0;
  }

  void _onPointerUp(BuildContext context, PointerUpEvent event) {
    final downPosition = _pointerDownPosition;
    final downTime = _pointerDownTime;
    _pointerDownPosition = null;
    _pointerDownTime = null;
    if (downPosition == null || downTime == null) {
      return;
    }

    final offset = event.localPosition - downPosition;
    final duration = DateTime.now().difference(downTime).inMilliseconds;

    if (offset.distance < _tapSlop && duration < _tapDurationBudget) {
      _handleTap(context, downPosition.dx);
      return;
    }

    // In the `none` mode, pages are switched instantly on drag.
    if (widget.mode == PageTurnMode.none &&
        offset.dx.abs() >= _dragThreshold &&
        offset.dx.abs() > offset.dy.abs()) {
      if (offset.dx < 0) {
        _goNext();
      } else {
        _goPrevious();
      }
    }
  }

  void _handleTap(BuildContext context, double dx) {
    final width = context.size?.width ?? 0;
    if (width <= 0) {
      return;
    }
    if (dx < width * 0.3) {
      _goPrevious();
    } else if (dx > width * 0.7) {
      _goNext();
    } else {
      widget.onToggleMenu();
    }
  }

  void _goNext() {
    if (_currentPage >= _pages.length - 1) {
      // The last page of the chapter: turn to the next chapter.
      widget.onNextChapter();
      return;
    }
    _turnToPage(_currentPage + 1);
  }

  void _goPrevious() {
    if (_currentPage <= 0) {
      return;
    }
    _turnToPage(_currentPage - 1);
  }

  void _turnToPage(int index) {
    _currentPage = index;
    _reportProgress();
    _reportPosition(index);

    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    if (widget.mode == PageTurnMode.none) {
      controller.jumpToPage(index);
    } else {
      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _seekToFraction(double fraction) {
    if (_pages.isEmpty) {
      return;
    }
    final target = (fraction * (_pages.length - 1)).round();
    _pageController?.jumpToPage(target);
    _currentPage = target;
    _reportProgress();
    _reportPosition(target);
  }

  void _onPageViewChanged(int index) {
    _currentPage = index;
    _reportProgress();
    _reportPosition(index);
  }

  bool _onOverscroll(OverscrollNotification notification) {
    // Dragging forward on the chapter end page navigates to the next chapter.
    if (_currentPage < _pages.length || notification.overscroll <= 0) {
      return false;
    }
    _chapterEndOverscroll += notification.overscroll;
    if (_chapterEndOverscroll >= _chapterEndOverscrollThreshold) {
      _chapterEndOverscroll = 0.0;
      widget.onNextChapter();
    }
    return false;
  }

  void _reportProgress() {
    final total = _pages.length;
    widget.progressNotifier.value =
        total == 0 ? 0.0 : ((_currentPage + 1) / total).clamp(0.0, 1.0);
  }

  void _reportPosition(int index) {
    if (widget.onPositionChange == null || _pages.isEmpty) {
      return;
    }
    final clamped = index.clamp(0, _pages.length - 1);
    final page = _pages[clamped];

    if (page.isImagePage()) {
      widget.onPositionChange!(
        ReadPosition(
          elementIndex: page.imageElementIndex!,
          elementTopOffset: 0,
        ),
      );
      return;
    }

    final firstRun = page.runs.first;
    widget.onPositionChange!(
      ReadPosition(
        elementIndex: firstRun.elementIndex,
        elementTopOffset: 0,
        elementCharacterIndex: firstRun.start,
        articleCharacterIndex: getArticleCharacterIndex(
          widget.content.elements,
          firstRun.elementIndex,
          firstRun.start,
        ),
      ),
    );
  }
}
