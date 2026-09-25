import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/bloc/screen/novel/novel_screen_bloc.dart';
import 'package:masiro/bloc/screen/novel/novel_screen_event.dart';
import 'package:masiro/bloc/screen/novel/novel_screen_state.dart';
import 'package:masiro/data/repository/model/novel_detail.dart';
import 'package:masiro/data/repository/model/volume.dart';
import 'package:masiro/misc/chapter.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/easy_refresh.dart';
import 'package:masiro/misc/router.dart';
import 'package:masiro/ui/screens/novel/expandable_brief.dart';
import 'package:masiro/ui/screens/novel/novel_header.dart';
import 'package:masiro/ui/screens/novel/volume_list.dart';
import 'package:masiro/ui/screens/reader/reader_screen.dart';
import 'package:masiro/ui/widgets/error_message.dart';
import 'package:masiro/ui/widgets/frozen_media_query.dart';

class NovelScreen extends StatefulWidget {
  final int novelId;

  /// Minimum user level required to read this novel. Zero means no limit.
  final int lvLimit;

  const NovelScreen({
    super.key,
    required this.novelId,
    this.lvLimit = 0,
  });

  @override
  State<NovelScreen> createState() => _NovelScreenState();
}

class _NovelScreenState extends State<NovelScreen> {
  bool _isFavoriteToggled = false;

  /// Whether the body has scrolled under the app bar (the bar shows its
  /// scrolled-under tint at the same time).
  bool _scrolledUnder = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: FrozenInsets(
        child: SafeArea(
          child: BlocProvider(
            create: (context) => NovelScreenBloc(novelId: widget.novelId)
              ..add(NovelScreenRefreshed()),
            child: BlocBuilder<NovelScreenBloc, NovelScreenState>(
              builder: (context, state) {
                switch (state) {
                  case NovelScreenInitialState():
                    return const Column(children: [LinearProgressIndicator()]);
                  case NovelScreenErrorState():
                    return ErrorMessage(message: state.message);
                  case NovelScreenLoadedState():
                    return buildLoadedScreen(context, state);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLoadedScreen(BuildContext context, NovelScreenLoadedState state) {
    final novelDetail = state.novelDetail;
    final header = novelDetail.header;
    final volumes = novelDetail.volumes;
    final lastReadChapterId = novelDetail.lastReadChapterId;
    final isFavorite = header.isFavorite;

    return Scaffold(
      appBar: buildAppBar(context, isFavorite, header.title),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          _backToPrevScreen(context);
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final scrolledUnder = notification.metrics.pixels > 0;
            if (scrolledUnder != _scrolledUnder) {
              setState(() => _scrolledUnder = scrolledUnder);
            }
            return false;
          },
          child: buildBody(context, novelDetail),
        ),
      ),
      bottomNavigationBar: buildBottomBar(
        context,
        volumes,
        lastReadChapterId,
      ),
    );
  }

  /// Formats the novel title for the app bar: at most 12 characters per
  /// line, wrapping onto a second line when needed, and ending the second
  /// line with an ellipsis when the title is longer than two lines.
  String _appBarNovelTitle(String title) {
    final chars = title.characters;
    if (chars.length <= 12) {
      return title;
    }
    final firstLine = chars.take(12).toString();
    final rest = chars.skip(12);
    if (rest.length <= 12) {
      return '$firstLine\n$rest';
    }
    return '$firstLine\n${rest.take(11)}…';
  }

  AppBar buildAppBar(
    BuildContext context,
    bool isFavorite,
    String novelTitle,
  ) {
    final bloc = context.read<NovelScreenBloc>();
    final localizations = context.localizations();

    return AppBar(
      // Match the bottom bar color once the body scrolls under the bar.
      backgroundColor: _scrolledUnder ? context.navBarColor() : null,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () => _backToPrevScreen(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      // While the page is scrolled under the bar (the bar changes color),
      // show the novel title instead of the static label. It uses the same
      // font size as the favorite button and sits at the same position,
      // vertically centered with tight line spacing.
      title: _scrolledUnder
          ? Text(
              _appBarNovelTitle(novelTitle),
              maxLines: 2,
              style: TextStyle(
                fontSize: 14,
                height: 1.1,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
              ),
            )
          : Text(localizations.detail),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: () {
              if (isFavorite) {
                bloc.add(NovelScreenNovelUnfavorited());
              } else {
                bloc.add(NovelScreenNovelFavorited());
              }
              _isFavoriteToggled = true;
            },
            style: TextButton.styleFrom(
              foregroundColor:
                  isFavorite ? Colors.grey : Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              isFavorite
                  ? localizations.inBookshelf
                  : localizations.addToBookshelf,
            ),
          ),
        ),
      ],
    );
  }

  EasyRefresh buildBody(BuildContext context, NovelDetail novelDetail) {
    final bloc = context.read<NovelScreenBloc>();
    final header = novelDetail.header;
    final volumes = novelDetail.volumes;
    final lastReadChapterId = novelDetail.lastReadChapterId;

    return EasyRefresh(
      header: classicHeader(context),
      onRefresh: () async {
        bloc.add(NovelScreenRefreshed());
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          NovelHeader(
            header: header,
            chapterCount: volumes.fold<int>(
              0,
              (sum, volume) => sum + volume.chapters.length,
            ),
            lvLimit: widget.lvLimit,
            onAuthorTap: (author) => _searchAuthor(context, author),
          ),
          const SizedBox(height: 20),
          ExpandableBrief(brief: header.brief),
          const SizedBox(height: 20),
          VolumeList(
            volumes: volumes,
            lastReadChapterId: lastReadChapterId,
            onTap: (chapter, volume) async {
              await _readChapter(context, chapter.novelId, chapter.id);
            },
          ),
        ],
      ),
    );
  }

  Widget buildBottomBar(
    BuildContext context,
    List<Volume> volumes,
    int lastReadChapterId,
  ) {
    final localizations = context.localizations();

    return Container(
      height: 60,
      color: context.navBarColor(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              context.push(
                RoutePath.comments,
                extra: {'novelId': widget.novelId},
              );
            },
            child: Row(
              children: [
                const Icon(Icons.comment, size: 20, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  localizations.novelComments,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _startReading(context, volumes, lastReadChapterId),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                localizations.startReading,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startReading(
    BuildContext context,
    List<Volume> volumes,
    int lastReadChapterId,
  ) async {
    final firstChapter = volumes.firstOrNull?.chapters.firstOrNull;
    final lastReadChapter = getChapterFromVolumes(
      volumes,
      lastReadChapterId,
    );
    final chapter = lastReadChapter ?? firstChapter;
    if (chapter == null) {
      return;
    }
    await _readChapter(context, chapter.novelId, chapter.id);
  }

  Future<void> _readChapter(
    BuildContext context,
    int novelId,
    int chapterId,
  ) async {
    final bloc = context.read<NovelScreenBloc>();
    // Push through the root navigator with the imperative reader route
    // (exactly like the shelf cover tap) instead of go_router.push: a
    // declarative GoRouter page-list reconfiguration while the status-bar
    // inset change is rebuilding the tree recreated this page below the
    // reader, so the reader got replaced immediately and the detail page
    // flashed its initial loading bar.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final transitionFlag = ReaderTransitionInsets.instance;
    // Freeze this page's insets (still edge-to-edge) *before* hiding the
    // status bar, so the app bar and body don't slide up during the
    // transition.
    transitionFlag.value = true;
    final immersiveReady = ReaderScreen.prepareImmersiveEntry();
    try {
      await immersiveReady;
      if (!context.mounted) {
        await ReaderScreen.restoreSystemUi();
        transitionFlag.value = false;
        return;
      }
      final popFuture = rootNavigator.push<int?>(
        buildReaderRoute<int?>(
          builder: (_) => ReaderScreen(
            novelId: novelId,
            chapterId: chapterId,
          ),
        ),
      );
      // The reader is opaque after the forward transition; any inset
      // relayout of this page from here on happens off screen.
      final releaseFreeze = Future<void>.delayed(
        readerTransitionDuration + const Duration(milliseconds: 30),
        () => transitionFlag.value = false,
      );
      final int? lastReadChapterId = await popFuture;
      await releaseFreeze;
      bloc.add(NovelScreenChapterRead(chapterId: lastReadChapterId ?? chapterId));
    } catch (_) {
      await ReaderScreen.restoreSystemUi();
      transitionFlag.value = false;
    }
  }

  void _backToPrevScreen(BuildContext context) {
    context.pop(_isFavoriteToggled);
  }

  void _searchAuthor(BuildContext context, String author) {
    if (author.isEmpty) {
      return;
    }
    final keyword = Uri.encodeQueryComponent(author);
    context.go('${RoutePath.home}?keyword=$keyword');
  }
}
