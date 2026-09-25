import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/bloc/screen/reader/reader_screen_bloc.dart';
import 'package:masiro/bloc/screen/reader/reader_screen_event.dart';
import 'package:masiro/bloc/screen/reader/reader_screen_state.dart';
import 'package:masiro/data/repository/model/read_position.dart';
import 'package:masiro/data/repository/preferences_repository.dart';
import 'package:masiro/misc/chapter.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/router.dart';
import 'package:masiro/ui/screens/reader/bottom_bar.dart';
import 'package:masiro/ui/screens/reader/chapter_content_pager.dart';
import 'package:masiro/ui/screens/reader/contents_sheet.dart';
import 'package:masiro/ui/screens/reader/payment_detail.dart';
import 'package:masiro/ui/screens/reader/reader_palette.dart';
import 'package:masiro/ui/screens/reader/reading_hud.dart';
import 'package:masiro/ui/screens/reader/settings_sheet.dart';
import 'package:masiro/ui/screens/reader/top_bar.dart';
import 'package:masiro/ui/widgets/error_message.dart';
import 'package:pinyin/pinyin.dart';

class ReaderScreen extends StatefulWidget {
  final int novelId;
  final int chapterId;

  const ReaderScreen({
    super.key,
    required this.novelId,
    required this.chapterId,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const _contentHorizontalPadding = 20.0;

  int? _lastReadChapterIdForPopResult;
  int? _loadedChapterId;
  ReadPosition _currentPosition = startPosition;
  ReaderScreenBloc? _bloc;
  final _progressNotifier = ValueNotifier<double>(0.0);
  final _pagerController = ReaderPagerController();

  /// System bar padding captured in reading mode (menu closed). The reader
  /// content always lays out against this value: opening the menu reveals
  /// the status bar and changes the live padding, but the paginated text
  /// must not resize or shift. It also keeps the body clear of the HUD
  /// title and progress texts, which use the same baseline.
  EdgeInsets? _readingPadding;
  EdgeInsets? _menuPadding;

  /// The system UI mode last applied to the platform. System UI calls are
  /// only made when the desired mode actually changes: rebuilds happen on
  /// every inset change, and re-asserting immersive mode here would fight
  /// the edge-to-edge switch performed while preparing to pop.
  SystemUiMode? _appliedUiMode;

  void _applySystemUiMode(SystemUiMode mode) {
    if (isDesktop || _isPopPending || _appliedUiMode == mode) {
      return;
    }
    _appliedUiMode = mode;
    SystemChrome.setEnabledSystemUIMode(mode);
  }

  @override
  void initState() {
    super.initState();
    _applySystemUiMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Flush the latest position synchronously-ish: the bloc's position
    // events are debounced, and the pending (trailing) write would be
    // cancelled when the bloc closes right after this dispose.
    _bloc?.persistLatestPosition(_currentPosition);
    _progressNotifier.dispose();
    if (!isDesktop) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReaderScreenBloc(novelId: widget.novelId)
        ..add(
          ReaderScreenChapterDetailRequested(chapterId: widget.chapterId),
        ),
      child: BlocBuilder<ReaderScreenBloc, ReaderScreenState>(
        builder: (context, state) {
          final bgColor = state is ReaderScreenLoadedState
              ? Color(state.backgroundColor)
              : const Color(defaultReaderBackgroundColor);
          return Scaffold(
            backgroundColor: bgColor,
            body: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  return;
                }
                _backToPrevScreen(context);
              },
              child: switch (state) {
                ReaderScreenInitialState() => const Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ReaderScreenErrorState() =>
                  ErrorMessage(message: state.message),
                ReaderScreenLoadedState() => buildLoadedScreen(context, state),
              },
            ),
          );
        },
      ),
    );
  }

  Widget buildLoadedScreen(
    BuildContext context,
    ReaderScreenLoadedState state,
  ) {
    final bloc = context.read<ReaderScreenBloc>();
    final chapterDetail = state.chapterDetail;
    final isHudVisible = state.isHudVisible;
    final fontSize = state.fontSize;

    final backgroundColor = Color(state.backgroundColor);
    final contentColor = readerContentColor(backgroundColor);
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: contentColor.computeLuminance() > 0.5
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: backgroundColor,
      systemNavigationBarIconBrightness: contentColor.computeLuminance() > 0.5
          ? Brightness.dark
          : Brightness.light,
    );

    // Reset the tracked position when a new chapter is loaded.
    if (_loadedChapterId != chapterDetail.chapterId) {
      _loadedChapterId = chapterDetail.chapterId;
      _currentPosition = state.position;
      _progressNotifier.value = 0.0;
    }

    // While the menu is visible the system status bar is shown; reading
    // itself stays fully immersive.
    _applySystemUiMode(
      isHudVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );

    // Track the live padding per mode. While the menu is closed, ignore the
    // transient value seen right after closing (the status bar is still
    // animating out) so the frozen reading padding never flaps. It is also
    // frozen while leaving the reader, otherwise restoring the status bar
    // would push the HUD title and the text down mid pop.
    final mqPadding = MediaQuery.of(context).padding;
    if (isHudVisible) {
      _menuPadding = mqPadding;
    } else if (!_isPopPending &&
        (_readingPadding == null || mqPadding != _menuPadding)) {
      _readingPadding = mqPadding;
    }

    final volumes = chapterDetail.volumes;
    final chapterId = chapterDetail.chapterId;
    final nextChapter = getNextChapter(volumes, chapterId);
    final prevChapter = getPreviousChapter(volumes, chapterId);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(
        children: [
          buildReaderContent(context, state),
          // The HUD uses the same frozen reading-mode padding as the body:
          // otherwise opening the menu reveals the status bar and the title
          // and progress texts slide with the live padding while fading out.
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: _readingPadding ?? mqPadding,
            ),
            child: ReadingHud(
              chapterTitle: state.forceSimplified
                  ? ChineseHelper.convertToSimplifiedChinese(
                      chapterDetail.title,
                    )
                  : chapterDetail.title,
              progress: _progressNotifier,
              color: contentColor,
              isVisible: !isHudVisible,
            ),
          ),
          TopBar(
            isVisible: isHudVisible,
            onNavigateBack: () => _backToPrevScreen(context),
            onNavigateToDetail: () {
              context.push(
                RoutePath.novel,
                extra: {'novelId': widget.novelId},
              );
            },
          ),
          BottomBar(
            isVisible: isHudVisible,
            prevChapterId: prevChapter?.id,
            nextChapterId: nextChapter?.id,
            progress: _progressNotifier,
            onSeek: _pagerController.seekToFraction,
            onNavigateTo: (chapterId) {
              _lastReadChapterIdForPopResult = chapterId;
              bloc.add(ReaderScreenChapterNavigated(chapterId: chapterId));
            },
            onContentsClicked: () {
              showModalBottomSheet<void>(
                showDragHandle: true,
                context: context,
                builder: (BuildContext sheetContext) {
                  return ContentsSheet(
                    volumes: chapterDetail.volumes,
                    currentChapterId: chapterDetail.chapterId,
                    onNavigateTo: (chapterId) {
                      Navigator.of(sheetContext).pop();
                      _lastReadChapterIdForPopResult = chapterId;
                      bloc.add(
                        ReaderScreenChapterNavigated(chapterId: chapterId),
                      );
                    },
                  );
                },
              );
            },
            onSettingsClicked: () {
              showModalBottomSheet<void>(
                showDragHandle: true,
                context: context,
                builder: (BuildContext context) {
                  return SettingsSheet(
                    fontSize: fontSize,
                    onFontSizeChanged: (v) {
                      bloc.add(ReaderScreenFontSizeChanged(fontSize: v));
                    },
                    backgroundColor: state.backgroundColor,
                    onBackgroundColorChanged: (colorValue) {
                      bloc.add(
                        ReaderScreenBackgroundColorChanged(
                          colorValue: colorValue,
                        ),
                      );
                    },
                    pageTurnMode: state.pageTurnMode,
                    onPageTurnModeChanged: (mode) {
                      bloc.add(ReaderScreenPageTurnModeChanged(pageTurnMode: mode));
                    },
                    indentMode: state.indentMode,
                    onIndentModeChanged: (mode) {
                      bloc.add(ReaderScreenIndentModeChanged(indentMode: mode));
                    },
                    shrinkEmptyLines: state.shrinkEmptyLines,
                    onShrinkEmptyLinesChanged: (enabled) {
                      bloc.add(
                        ReaderScreenShrinkEmptyLinesChanged(
                          shrinkEmptyLines: enabled,
                        ),
                      );
                    },
                    forceSimplified: state.forceSimplified,
                    onForceSimplifiedChanged: (enabled) {
                      bloc.add(
                        ReaderScreenForceSimplifiedChanged(enabled: enabled),
                      );
                    },
                  );
                },
              );
            },
            onCommentClicked: () {
              context.push(
                RoutePath.comments,
                extra: {'chapterId': chapterId},
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildReaderContent(
    BuildContext context,
    ReaderScreenLoadedState state,
  ) {
    final bloc = context.read<ReaderScreenBloc>();
    _bloc ??= bloc;
    final chapterDetail = state.chapterDetail;
    final paymentInfo = chapterDetail.paymentInfo;
    final loadingStatus = state.loadingStatus;
    final fontSize = state.fontSize;
    final pageTurnMode = state.pageTurnMode;

    if (loadingStatus.isLoading()) {
      return const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(),
        ),
      );
    }

    final backgroundColor = Color(state.backgroundColor);
    final contentColor = readerContentColor(backgroundColor);
    final horizontalPadding = isDesktop ? 120.0 : _contentHorizontalPadding;

    if (paymentInfo != null) {
      return _tapToToggleHud(context, PaymentDetail(paymentInfo: paymentInfo));
    }

    // Lay the reader content out against the frozen reading-mode padding so
    // that showing the status bar (when the menu opens) does not resize and
    // shift the paginated content, while the body stays below the top-left
    // HUD title and above the bottom progress text. The menu bars live
    // outside this subtree and still avoid the status bar normally.
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: _readingPadding ?? EdgeInsets.zero,
      ),
      child: ChapterContentPager(
      mode: pageTurnMode,
      content: chapterDetail.content,
      chapterId: chapterDetail.chapterId,
      fontSize: fontSize,
      textColor: contentColor,
      backgroundColor: backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      initialPosition: state.position,
      getCurrentPosition: () => _currentPosition,
      progressNotifier: _progressNotifier,
      onPositionChange: (position) => _onPositionChange(bloc, position),
      onToggleMenu: () => _toggleHud(context),
      onNextChapter: () {
        final nextChapter = getNextChapter(
          chapterDetail.volumes,
          chapterDetail.chapterId,
        );
        if (nextChapter == null) {
          return;
        }
        _lastReadChapterIdForPopResult = nextChapter.id;
        bloc.add(ReaderScreenChapterNavigated(chapterId: nextChapter.id));
      },
      onPreviousChapter: () {
        final prevChapter = getPreviousChapter(
          chapterDetail.volumes,
          chapterDetail.chapterId,
        );
        if (prevChapter == null) {
          return;
        }
        _lastReadChapterIdForPopResult = prevChapter.id;
        bloc.add(
          ReaderScreenChapterNavigated(
            chapterId: prevChapter.id,
            openAtEnd: true,
          ),
        );
      },
      pagerController: _pagerController,
      indentMode: state.indentMode,
      shrinkEmptyLines: state.shrinkEmptyLines,
      forceSimplified: state.forceSimplified,
      chapterTitle: chapterDetail.title,
      ),
    );
  }

  void _onPositionChange(ReaderScreenBloc bloc, ReadPosition position) {
    _bloc ??= bloc;
    _currentPosition = position;
    bloc.add(ReaderScreenPositionChanged(position: position));
  }

  Widget _tapToToggleHud(BuildContext context, Widget child) {
    return isDesktop
        ? Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _toggleHud(context),
            child: child,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleHud(context),
            child: child,
          );
  }

  void _toggleHud(BuildContext context) {
    context.read<ReaderScreenBloc>().add(ReaderScreenHudToggled());
  }

  /// Set once the reader starts leaving the screen. While true, no system
  /// UI mode changes may be made from build, so the edge-to-edge restore
  /// performed for the pop transition is never undone by a late rebuild.
  /// Stays true until dispose (the reader never comes back from a pop).
  bool _isPopPending = false;

  Future<void> _backToPrevScreen(BuildContext context) async {
    if (_isPopPending) {
      return;
    }
    // The reader is immersive while the menu is closed, so the route below
    // has already been laid out with zero status-bar insets (its content
    // sits at the very top). Restoring edgeToEdge only in dispose makes
    // the page below relayout *during* the pop transition, which looks
    // like the detail/shelf page dropping down. Restore the status bar
    // first while the reader still fully covers the screen, let the page
    // below settle, and only then start the transition.
    if (!isDesktop) {
      final state = context.read<ReaderScreenBloc>().state;
      final hudVisible = state is ReaderScreenLoadedState &&
          state.isHudVisible;
      if (!hudVisible) {
        // Lock UI-mode changes until dispose: rebuilds keep happening
        // during the pop transition below, and re-asserting immersive
        // mode then would relayout the page underneath while it is
        // already becoming visible.
        _isPopPending = true;
        // Switch directly (the helper is locked while a pop is pending)
        // and record the mode so the first rebuild after the inset change
        // doesn't re-assert immersive mode and undo this switch.
        if (!isDesktop) {
          _appliedUiMode = SystemUiMode.edgeToEdge;
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted || !context.mounted) {
          return;
        }
      }
    }
    // Use the imperative Navigator API (instead of context.pop) so the
    // reader works both as a GoRouter route and as a raw route pushed
    // directly from the bookshelf cover tap.
    Navigator.of(context).pop(_lastReadChapterIdForPopResult);
  }
}
