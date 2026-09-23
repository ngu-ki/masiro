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
        '-${widget.indentMode.name}';
  }

  TextStyle _buildTextStyle(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    return defaultStyle.copyWith(
      fontSize: widget.fontSize.toDouble(),
      color: widget.textColor,
      height: 1.5,
    );
  }

  double _buildParagraphGap() {
    return widget.fontSize * 0.65;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = _buildTextStyle(context);
        final paragraphGap = _buildParagraphGap();
        final mediaQuery = MediaQuery.of(context);
        final topInset = mediaQuery.padding.top + 44;
        final bottomInset = mediaQuery.padding.bottom + 44;
        final contentWidth =
            constraints.maxWidth - widget.padding.horizontal;
        final contentHeight = constraints.maxHeight - topInset - bottomInset;

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

        final pageWidgets = [
          for (var i = 0; i < _pages.length; i++)
            _buildPage(
              context,
              _pages[i],
              style,
              paragraphGap,
              topInset: topInset,
              bottomInset: bottomInset,
              contentWidth: contentWidth,
              contentHeight: contentHeight,
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
    double paragraphGap, {
    required double topInset,
    required double bottomInset,
    required double contentWidth,
    required double contentHeight,
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
    for (final run in page.runs) {
      if (children.isNotEmpty && run.elementIndex != lastElementIndex) {
        children.add(SizedBox(height: paragraphGap));
      }
      final element = elements[run.elementIndex] as TextContent;
      final displayText = '${widget.indentMode.prefix}${element.text}';
      var fragment = displayText.substring(run.start, run.end);
      if (fragment.endsWith('\n')) {
        fragment = fragment.substring(0, fragment.length - 1);
      }
      children.add(Text(fragment, style: style));
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
