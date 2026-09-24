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
  final _progressNotifier = ValueNotifier<double>(0.0);
  final _currentPageNotifier = ValueNotifier<int>(0);
  final _pagerController = ReaderPagerController();

  @override
  void initState() {
    super.initState();
    if (!isDesktop) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    _currentPageNotifier.dispose();
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
                    child: CircularProgressIndicator(),
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
      _currentPageNotifier.value = 0;
    }

    // While the menu is visible the system status bar is shown; reading
    // itself stays fully immersive.
    if (!isDesktop) {
      SystemChrome.setEnabledSystemUIMode(
        isHudVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      );
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
          ReadingHud(
            chapterTitle: chapterDetail.title,
            novelTitle: chapterDetail.novelTitle,
            currentPage: _currentPageNotifier,
            progress: _progressNotifier,
            color: contentColor,
            isVisible: !isHudVisible,
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

    return ChapterContentPager(
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
      pagerController: _pagerController,
      indentMode: state.indentMode,
      shrinkEmptyLines: state.shrinkEmptyLines,
      chapterTitle: chapterDetail.title,
      onPageChanged: (index) => _currentPageNotifier.value = index,
    );
  }

  void _onPositionChange(ReaderScreenBloc bloc, ReadPosition position) {
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

  void _backToPrevScreen(BuildContext context) {
    context.pop(_lastReadChapterIdForPopResult);
  }
}
