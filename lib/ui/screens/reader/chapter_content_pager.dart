import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/chapter_detail.dart';
import 'package:masiro/data/repository/model/indent_mode.dart';
import 'package:masiro/data/repository/model/page_turn_mode.dart';
import 'package:masiro/data/repository/model/read_position.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/render.dart';
import 'package:masiro/ui/screens/reader/pagination.dart';
import 'package:masiro/ui/widgets/cached_image.dart';
import 'package:pinyin/pinyin.dart';

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

  /// Called when the reader pages backwards past the first page of the
  /// chapter; the previous chapter should open on its last page.
  final void Function() onPreviousChapter;
  final ReaderPagerController pagerController;
  final IndentMode indentMode;
  final bool shrinkEmptyLines;
  final bool forceSimplified;

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
    required this.onPreviousChapter,
    required this.pagerController,
    this.indentMode = IndentMode.none,
    this.shrinkEmptyLines = false,
    this.forceSimplified = false,
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

  /// Current page index, used to gate image requests: all text pages are
  /// built up front (so scrubbing the progress bar lands instantly on any
  /// page), but an illustration only loads once its page is current,
  /// adjacent, or already visited.
  final ValueNotifier<int> _pageIndexNotifier = ValueNotifier<int>(0);

  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  double _chapterEndOverscroll = 0.0;
  double _chapterStartOverscroll = 0.0;

  /// Page index whose image is currently (or has just been) prefetched.
  int? _prefetchedImagePage;
  bool _prefetchInFlight = false;

  /// Physical-pixel decode size for prefetched images, matching the size
  /// the on-screen [CachedImage] decodes at, so the prefetched bitmap is
  /// reused directly instead of being decoded a second time.
  int? _prefetchCacheWidth;
  int? _prefetchCacheHeight;

  /// Bumped whenever pagination runs, so a prefetch started for the
  /// previous chapter/config doesn't schedule follow-up work.
  int _paginationGeneration = 0;

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
    _pageIndexNotifier.dispose();
    super.dispose();
  }

  String _buildConfigSignature() {
    return '${widget.chapterId}-${widget.fontSize}-${widget.mode.name}'
        '-${widget.indentMode.name}-${widget.shrinkEmptyLines}'
        '-${widget.forceSimplified}';
  }

  // Converting or normalizing a whole chapter is expensive, so the
  // transformed elements are cached and recomputed only when the source
  // content or a transform-relevant setting changes.
  List<ChapterContentElement>? _transformedSource;
  String _transformedKey = '';
  List<ChapterContentElement>? _transformedElements;

  List<ChapterContentElement> _effectiveElements() {
    final source = widget.content.elements;
    final adaptive = widget.indentMode == IndentMode.adaptive;
    if (!widget.forceSimplified && !adaptive) {
      return source;
    }
    final key = '${widget.forceSimplified}-$adaptive';
    if (!identical(_transformedSource, source) || _transformedKey != key) {
      _transformedSource = source;
      _transformedKey = key;
      _transformedElements = [
        for (final e in source)
          e is TextContent ? _transformTextContent(e, adaptive) : e,
      ];
    }
    return _transformedElements!;
  }

  TextContent _transformTextContent(TextContent element, bool adaptive) {
    var text = element.text;
    var mutedRanges = element.mutedRanges;
    if (adaptive) {
      // Normalize any existing leading indentation (no space, one or two
      // cells of `&nbsp;` or full-width spaces...) so every paragraph starts
      // exactly at the two-cell indent added by the mode prefix.
      var leading = 0;
      while (leading < text.length &&
          _isIndentBlank(text.codeUnitAt(leading))) {
        leading++;
      }
      if (leading > 0) {
        final stripped = text.substring(leading);
        // Keep paragraphs made solely of spaces untouched so they still
        // render as blank lines.
        if (!isBlankTextLine(stripped)) {
          text = stripped;
          mutedRanges = [
            for (final range in mutedRanges)
              if (range.end > leading)
                (
                  start: range.start > leading ? range.start - leading : 0,
                  end: range.end - leading,
                ),
          ];
        }
      }
    }
    if (widget.forceSimplified) {
      text = ChineseHelper.convertToSimplifiedChinese(text);
    }
    return element.copyWith(text: text, mutedRanges: mutedRanges);
  }

  static bool _isIndentBlank(int codeUnit) {
    return codeUnit == 0x20 || // space
        codeUnit == 0x09 || // tab
        codeUnit == 0xA0 || // no-break space (`&nbsp;`)
        codeUnit == 0x3000; // ideographic (full-width) space
  }

  String _effectiveChapterTitle() {
    if (!widget.forceSimplified) {
      return widget.chapterTitle;
    }
    return ChineseHelper.convertToSimplifiedChinese(widget.chapterTitle);
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
        _prefetchCacheWidth =
            (contentWidth * mediaQuery.devicePixelRatio).round();
        _prefetchCacheHeight =
            (contentHeight * mediaQuery.devicePixelRatio).round();
        final elements = _effectiveElements();
        final chapterTitle = _effectiveChapterTitle();

        // Measure the chapter title so the first page reserves its height.
        final titlePainter = TextPainter(
          text: TextSpan(text: chapterTitle, style: titleStyle),
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
            elements: elements,
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
          _currentPage = restore.isEnd
              ? _pages.length - 1
              : pageIndexOfPosition(_pages, restore)
                    .clamp(0, _pages.length - 1);
          // Notify the HUD and the persistence layer after the current
          // build/layout pass to avoid marking sibling widgets dirty.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _pageIndexNotifier.value = _currentPage;
              _reportProgress();
              _reportPosition(_currentPage);
              _scheduleImagePrefetch();
            }
          });
          _pageController?.dispose();
          _pageController = PageController(initialPage: _currentPage);
          _paginationGeneration++;
          _prefetchedImagePage = null;
          _prefetchInFlight = false;
        }

        final firstPage = _pages.isNotEmpty ? _pages.first : null;
        final showHeaderOnFirstPage = firstPage != null &&
            !firstPage.isImagePage() &&
            firstPage.runs.isNotEmpty;
        // Every page is constructed up front so scrubbing the progress bar
        // lands on an already-built page; image pages, however, only start
        // their network request once they are the current/adjacent page or
        // have been visited, so opening a chapter never fires a burst of
        // image downloads.
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
              pageIndex: i,
              pageIndexNotifier: _pageIndexNotifier,
              header: i == 0 && showHeaderOnFirstPage
                  ? Text(
                      chapterTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    )
                  : null,
            ),
        ];

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerUp: (event) => _onPointerUp(context, event),
          child: _buildPageViewPager(
            [...pageWidgets, _buildChapterEndPage(context)],
          ),
        );
      },
    );
  }

  Widget _buildPageViewPager(List<Widget> pageWidgets) {
    return NotificationListener<OverscrollNotification>(
      onNotification: _onOverscroll,
      child: PageView(
        controller: _pageController,
        physics: widget.mode == PageTurnMode.none
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: _onPageViewChanged,
        children: pageWidgets,
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
    required int pageIndex,
    required ValueNotifier<int> pageIndexNotifier,
    Widget? header,
  }) {
    if (page.isImagePage()) {
      return _VisibilityAwareImage(
        url: page.image!.src,
        width: contentWidth,
        height: contentHeight,
        pageIndex: pageIndex,
        currentPageNotifier: pageIndexNotifier,
      );
    }

    final elements = _effectiveElements();
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
    _chapterStartOverscroll = 0.0;
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
      // Already on the first page: turn into the previous chapter and
      // land on its last page.
      widget.onPreviousChapter();
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
    _pageIndexNotifier.value = target;
    _reportProgress();
    _reportPosition(target);
    _scheduleImagePrefetch();
  }

  void _onPageViewChanged(int index) {
    _currentPage = index;
    _pageIndexNotifier.value = index;
    _reportProgress();
    _reportPosition(index);
    _scheduleImagePrefetch();
  }

  /// Warms the disk cache of the nearest full-page image ahead of the
  /// current page, so reaching that page renders it instantly instead of
  /// starting the download on the spot.
  ///
  /// Traffic shaping (this is a third-party client): at most one image
  /// GET is in flight per chapter, and the next one only starts after the
  /// reader actually reaches the previous prefetched image. Pacing is thus
  /// driven by real reading speed, never a whole-chapter burst.
  void _scheduleImagePrefetch() {
    if (_prefetchInFlight || _pages.isEmpty) {
      return;
    }
    // A prefetch for an image the reader hasn't reached yet is still
    // pending: do not walk further through the chapter.
    final pendingPage = _prefetchedImagePage;
    if (pendingPage != null && _currentPage < pendingPage) {
      return;
    }
    for (var i = _currentPage + 1; i < _pages.length; i++) {
      final page = _pages[i];
      if (!page.isImagePage()) {
        continue;
      }
      _prefetchedImagePage = i;
      _prefetchInFlight = true;
      final generation = _paginationGeneration;
      final targetPage = i;
      // Decode at on-screen pixel size; this is the same ResizeImage key
      // the visible CachedImage will use, so display is a direct cache hit.
      final provider = ResizeImage(
        CachedNetworkImageProvider(page.image!.src),
        width: _prefetchCacheWidth,
        height: _prefetchCacheHeight,
      );
      precacheImage(
        provider,
        context,
        onError: (error, stackTrace) {},
      ).then((_) {
        if (!mounted || generation != _paginationGeneration) {
          return;
        }
        _prefetchInFlight = false;
        // Only chain to the following image once the reader has reached
        // the one just prefetched.
        if (_currentPage >= targetPage) {
          _scheduleImagePrefetch();
        }
      });
      return;
    }
  }

  bool _onOverscroll(OverscrollNotification notification) {
    // Dragging backwards on the first page navigates to the previous
    // chapter, which opens on its last page.
    if (_currentPage == 0 && notification.overscroll < 0) {
      _chapterStartOverscroll += -notification.overscroll;
      if (_chapterStartOverscroll >= _chapterEndOverscrollThreshold) {
        _chapterStartOverscroll = 0.0;
        widget.onPreviousChapter();
      }
      return false;
    }
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
          _effectiveElements(),
          firstRun.elementIndex,
          firstRun.start,
        ),
      ),
    );
  }
}

/// A full-page illustration that only starts its network request once its
/// page is currently shown or directly adjacent (preloaded while the
/// reader is one page away), and stays loaded afterwards. All text pages
/// are still constructed eagerly, so this gating only affects image
/// requests — it prevents opening a chapter from downloading every
/// illustration in the chapter at once.
class _VisibilityAwareImage extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final int pageIndex;
  final ValueListenable<int> currentPageNotifier;

  const _VisibilityAwareImage({
    required this.url,
    required this.width,
    required this.height,
    required this.pageIndex,
    required this.currentPageNotifier,
  });

  @override
  State<_VisibilityAwareImage> createState() => _VisibilityAwareImageState();
}

class _VisibilityAwareImageState extends State<_VisibilityAwareImage> {
  /// Latch: once the image has been activated it stays mounted, so paging
  /// back to a visited illustration never unloads it.
  bool _activated = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.currentPageNotifier,
      builder: (context, currentPage, child) {
        final adjacent = (widget.pageIndex - currentPage).abs() <= 1;
        final shouldShow = _activated || adjacent;
        if (adjacent && !_activated) {
          // Persist the latch after this frame; never call setState
          // synchronously while building.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _activated = true);
            }
          });
        }
        if (!shouldShow) {
          // Same neutral placeholder CachedImage uses while loading.
          return ColoredBox(
            color: Theme.of(context).colorScheme.surface,
          );
        }
        return CachedImage(
          url: widget.url,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
        );
      },
    );
  }
}
