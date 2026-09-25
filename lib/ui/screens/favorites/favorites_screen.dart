import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_bloc.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_event.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_state.dart';
import 'package:masiro/data/repository/masiro_repository.dart';
import 'package:masiro/data/repository/model/bookshelf_stat.dart';
import 'package:masiro/data/repository/model/novel.dart';
import 'package:masiro/di/get_it.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/easy_refresh.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/router.dart';
import 'package:masiro/misc/toast.dart';
import 'package:masiro/ui/screens/reader/reader_screen.dart';
import 'package:masiro/ui/widgets/error_message.dart';
import 'package:masiro/ui/widgets/message.dart';
import 'package:masiro/ui/widgets/novel_card.dart';
import 'package:masiro/ui/widgets/novel_grid_card.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final EasyRefreshController _easyRefreshController;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  /// Whether the local favorites search bar is active.
  bool _isSearching = false;

  /// The current keyword used to filter favorited novels.
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _easyRefreshController = EasyRefreshController();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _easyRefreshController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _enterSearch() {
    setState(() => _isSearching = true);
  }

  void _exitSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: BlocProvider(
          create: (_) =>
              FavoritesScreenBloc()..add(FavoritesScreenRequested()),
          child: BlocBuilder<FavoritesScreenBloc, FavoritesScreenState>(
            builder: (context, state) {
              switch (state) {
                case FavoritesScreenInitialState():
                  return const Column(children: [LinearProgressIndicator()]);
                case FavoritesScreenErrorState():
                  return ErrorMessage(message: state.message);
                case FavoritesScreenLoadedState():
                  return buildBody(context, state);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget buildBody(BuildContext context, FavoritesScreenLoadedState state) {
    final localizations = context.localizations();
    final isSearching = _isSearching && !state.isBatchMode;
    final keyword = _searchQuery.trim().toLowerCase();
    final novels = isSearching && keyword.isNotEmpty
        ? state.novels.where((n) {
            return n.title.toLowerCase().contains(keyword) ||
                (n.author?.toLowerCase().contains(keyword) ?? false);
          }).toList()
        : state.novels;
    final isEmptySearchResult =
        isSearching && keyword.isNotEmpty && novels.isEmpty;

    return PopScope(
      canPop: !isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSearching) {
          _exitSearch();
        }
      },
      child: Column(
        children: [
          buildHeader(context, state),
          Expanded(
            child: EasyRefresh(
              controller: _easyRefreshController,
              header: classicHeader(context),
              onRefresh: () {
                context
                    .read<FavoritesScreenBloc>()
                    .add(FavoritesScreenRefreshed());
              },
              child: novels.isNotEmpty
                  ? state.viewMode == FavoritesViewMode.grid
                      ? buildNovelGrid(context, state, novels)
                      : buildNovelList(context, state, novels)
                  : LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20.0),
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Message(
                              message: isEmptySearchResult
                                  ? localizations.noSearchResults
                                  : localizations.noContentMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (state.isBatchMode) buildBatchBottomBar(context, state),
        ],
      ),
    );
  }

  Widget buildHeader(BuildContext context, FavoritesScreenLoadedState state) {
    if (state.isBatchMode) {
      return buildBatchHeader(context, state);
    }
    if (state.manualAdjusting) {
      return buildManualHeader(context);
    }
    if (_isSearching) {
      return buildSearchHeader(context);
    }

    final localizations = context.localizations();
    final isGrid = state.viewMode == FavoritesViewMode.grid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          PopupMenuButton<FavoritesSortMode>(
            tooltip: localizations.sortMode,
            icon: const Icon(Icons.sort_rounded),
            onSelected: (mode) {
              context
                  .read<FavoritesScreenBloc>()
                  .add(FavoritesScreenSortSelected(mode));
            },
            itemBuilder: (_) => [
              buildSortMenuItem(
                context,
                state,
                mode: FavoritesSortMode.recentlyRead,
                label: localizations.recentlyRead,
              ),
              buildSortMenuItem(
                context,
                state,
                mode: FavoritesSortMode.lastUpdated,
                label: localizations.lastUpdated,
              ),
              buildSortMenuItem(
                context,
                state,
                mode: FavoritesSortMode.defaultOrder,
                label: localizations.sortDefault,
              ),
              buildWordChapterSortMenuItem(context, state),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: localizations.searchInFavorites,
            icon: const Icon(Icons.search_rounded),
            onPressed: _enterSearch,
          ),
          PopupMenuButton<String>(
            tooltip: localizations.moreActions,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              final bloc = context.read<FavoritesScreenBloc>();
              if (value == 'view') {
                bloc.add(
                  FavoritesScreenViewModeChanged(
                    isGrid ? FavoritesViewMode.list : FavoritesViewMode.grid,
                  ),
                );
              } else if (value == 'sort') {
                bloc.add(FavoritesScreenManualModeEntered());
              } else if (value == 'batch') {
                bloc.add(FavoritesScreenBatchModeToggled());
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(
                      isGrid
                          ? Icons.view_agenda_outlined
                          : Icons.grid_view_rounded,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isGrid ? localizations.listView : localizations.gridView,
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    const Icon(Icons.swap_vert_rounded),
                    const SizedBox(width: 8),
                    Text(localizations.manualSort),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'batch',
                child: Row(
                  children: [
                    const Icon(Icons.checklist_rounded),
                    const SizedBox(width: 8),
                    Text(localizations.batchManagement),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The header shown while manually adjusting the order: a close button on
  /// the left cancels without saving, and the 确认移动 button on the right
  /// (same slot as 全选 in batch mode) saves the arrangement as 自设排序.
  Widget buildManualHeader(BuildContext context) {
    final localizations = context.localizations();
    final bloc = context.read<FavoritesScreenBloc>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => bloc.add(FavoritesScreenManualModeExited()),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => bloc.add(FavoritesScreenManualModeConfirmed()),
            child: Text(localizations.confirmMove),
          ),
        ],
      ),
    );
  }

  Widget buildSearchHeader(BuildContext context) {
    final localizations = context.localizations();
    // Keep the same vertical padding as the regular header so the shelf
    // list below doesn't shift when entering search mode.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _exitSearch,
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: localizations.searchInFavorites,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                _searchFocusNode.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  Widget buildBatchHeader(
    BuildContext context,
    FavoritesScreenLoadedState state,
  ) {
    final localizations = context.localizations();
    final bloc = context.read<FavoritesScreenBloc>();
    final count = state.selectedNovelIds.length;
    final total = state.novels.length;
    final allSelected = count == total && total > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => bloc.add(FavoritesScreenBatchModeToggled()),
          ),
          Text(
            '$count',
            style: context.textTheme().titleLarge,
          ),
          const Spacer(),
          TextButton(
            onPressed: total == 0
                ? null
                : () => bloc.add(FavoritesScreenAllSelectionToggled()),
            child: Text(
              allSelected ? localizations.cancel : localizations.selectAll,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBatchBottomBar(
    BuildContext context,
    FavoritesScreenLoadedState state,
  ) {
    final localizations = context.localizations();
    final bloc = context.read<FavoritesScreenBloc>();
    final hasSelection = state.selectedNovelIds.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: hasSelection
                ? () => bloc.add(FavoritesScreenSelectedNovelsRemoved())
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(localizations.removeFromFavorites),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<FavoritesSortMode> buildSortMenuItem(
    BuildContext context,
    FavoritesScreenLoadedState state, {
    required FavoritesSortMode mode,
    required String label,
  }) {
    final isSelected = state.sortMode == mode;
    Widget? trailing;
    if (isSelected) {
      // Default order, recently read and last updated have no direction
      // toggle, so they show a check mark; the word/chapter modes show the
      // sort direction arrow.
      if (mode == FavoritesSortMode.defaultOrder ||
          mode == FavoritesSortMode.recentlyRead ||
          mode == FavoritesSortMode.lastUpdated) {
        trailing = const Icon(Icons.check_rounded, size: 20);
      } else {
        trailing = Icon(
          state.sortDirection == FavoritesSortDirection.ascending
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          size: 20,
        );
      }
    }
    return PopupMenuItem<FavoritesSortMode>(
      value: mode,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// The merged "word count · chapter count" sort item. Tapping it switches
  /// between the two; the active criterion is shown in blue. Both orders
  /// are always descending.
  PopupMenuItem<FavoritesSortMode> buildWordChapterSortMenuItem(
    BuildContext context,
    FavoritesScreenLoadedState state,
  ) {
    final localizations = context.localizations();
    final wordActive = state.sortMode == FavoritesSortMode.wordCount;
    final chapterActive = state.sortMode == FavoritesSortMode.chapterCount;
    const activeColor = Colors.blue;

    return PopupMenuItem<FavoritesSortMode>(
      // First tap selects word count; while word count is active the next
      // tap selects chapter count, and vice versa.
      value: wordActive
          ? FavoritesSortMode.chapterCount
          : FavoritesSortMode.wordCount,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: localizations.sortByWordCount,
              style: wordActive
                  ? const TextStyle(color: activeColor)
                  : null,
            ),
            const TextSpan(text: '·'),
            TextSpan(
              text: localizations.sortByChapterCount,
              style: chapterActive
                  ? const TextStyle(color: activeColor)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNovelList(
    BuildContext context,
    FavoritesScreenLoadedState state,
    List<Novel> novels,
  ) {
    final bloc = context.read<FavoritesScreenBloc>();
    final isBatch = state.isBatchMode;
    final isReordering =
        state.manualAdjusting && !isBatch && !_isSearching;

    Widget itemBuilder(BuildContext context, int index) {
      final n = novels[index];
      Widget card = NovelCard(
        key: ValueKey('novel-card-${n.id}'),
        title: n.title,
        coverImg: n.coverImg,
        author: n.author,
        lastUpdated: n.lastUpdated,
        brief: n.brief,
        onTap: isBatch
            ? () => bloc.add(
                  FavoritesScreenNovelSelectionToggled(novelId: n.id),
                )
            : () => _openReader(context, n),
      );

      if (isBatch) {
        final isSelected = state.selectedNovelIds.contains(n.id);
        card = Row(
          key: ValueKey('novel-row-${n.id}'),
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => bloc.add(
                FavoritesScreenNovelSelectionToggled(novelId: n.id),
              ),
            ),
            Expanded(child: card),
          ],
        );
      }

      if (isDesktop) {
        card = Center(
          key: ValueKey('novel-wrap-${n.id}'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: card,
          ),
        );
      }
      return card;
    }

    if (isReordering) {
      // Long-press a card and drag it to a new position.
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: novels.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          bloc.add(
            FavoritesScreenNovelsReordered(
              oldIndex: oldIndex,
              newIndex: newIndex,
            ),
          );
        },
        itemBuilder: itemBuilder,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: novels.length,
      itemBuilder: itemBuilder,
    );
  }

  Widget buildNovelGrid(
    BuildContext context,
    FavoritesScreenLoadedState state,
    List<Novel> novels,
  ) {
    final bloc = context.read<FavoritesScreenBloc>();
    final isBatch = state.isBatchMode;
    final isReordering =
        state.manualAdjusting && !isBatch && !_isSearching;

    Widget grid = LayoutBuilder(
      builder: (context, constraints) {
        const padding = 10.0;
        const spacing = 8.0;
        const cardHorizontalPadding = 4.0;
        final itemWidth =
            (constraints.maxWidth - padding * 2 - spacing * 2) / 3;
        final titleFontSize =
            ((itemWidth - cardHorizontalPadding * 2) / 8).clamp(10.0, 13.0);
        final titleHeight = titleFontSize * 1.4 * 3;
        final itemHeight =
            4 + itemWidth * 10 / 7 + 4 + titleHeight + 2 + 20 + 4;

        final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: spacing,
          mainAxisSpacing: 10,
          childAspectRatio: itemWidth / itemHeight,
        );

        Widget itemBuilder(BuildContext context, int index) {
          final n = novels[index];
          final card = NovelGridCard(
            key: ValueKey('novel-grid-${n.id}'),
            title: n.title,
            coverImg: n.coverImg,
            stat: state.stats[n.id],
            onTap: isBatch
                ? () => bloc.add(
                      FavoritesScreenNovelSelectionToggled(novelId: n.id),
                    )
                : () => _openReader(context, n),
            onDetailTap: isBatch
                ? () => bloc.add(
                      FavoritesScreenNovelSelectionToggled(novelId: n.id),
                    )
                : () => _navigateToNovelDetailScreen(context, n),
            onMore:
                isBatch ? null : () => _navigateToNovelDetailScreen(context, n),
          );

          if (!isBatch) {
            return card;
          }

          final isSelected = state.selectedNovelIds.contains(n.id);
          return Stack(
            key: ValueKey('novel-grid-stack-${n.id}'),
            children: [
              card,
              Positioned(
                top: 0,
                left: 0,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => bloc.add(
                    FavoritesScreenNovelSelectionToggled(novelId: n.id),
                  ),
                ),
              ),
            ],
          );
        }

        if (isReordering) {
          // Long-press a cover and drag it to a new position.
          return ReorderableGridView.builder(
            padding: const EdgeInsets.all(padding),
            gridDelegate: gridDelegate,
            itemCount: novels.length,
            onReorder: (oldIndex, newIndex) {
              bloc.add(
                FavoritesScreenNovelsReordered(
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                ),
              );
            },
            itemBuilder: itemBuilder,
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(padding),
          gridDelegate: gridDelegate,
          itemCount: novels.length,
          itemBuilder: itemBuilder,
        );
      },
    );

    if (isDesktop) {
      grid = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: grid,
        ),
      );
    }
    return grid;
  }

  Future<void> _navigateToNovelDetailScreen(
    BuildContext context,
    Novel n,
  ) async {
    final bool? needRefresh = await context.push(
      RoutePath.novel,
      extra: {'novelId': n.id, 'lvLimit': n.lvLimit},
    );
    if (needRefresh == null || needRefresh == false) {
      return;
    }
    await _easyRefreshController.callRefresh();
  }

  /// Opens the reader directly at the last read chapter (or the first chapter
  /// when the novel has never been read), skipping the novel detail page.
  ///
  /// The reader resolves the target chapter itself (from the bookshelf stat's
  /// lastReadChapterId, falling back to the novel detail) and shows a single
  /// loading spinner while fetching. There is no separate loading dialog on
  /// the bookshelf, so the cover tap -> reader transition is one animation.
  Future<void> _openReader(BuildContext context, Novel n) async {
    final bloc = context.read<FavoritesScreenBloc>();

    // Resume at the chapter recorded in the local bookshelf stat when
    // available; otherwise let the reader resolve the first chapter.
    var lastReadChapterId = 0;
    final state = bloc.state;
    if (state is FavoritesScreenLoadedState) {
      lastReadChapterId = state.stats[n.id]?.lastReadChapterId ?? 0;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final int? lastChapterId = await rootNavigator.push<int?>(
      buildReaderRoute<int?>(
        builder: (_) => ReaderScreen(
          novelId: n.id,
          chapterId: lastReadChapterId,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }

    // Refresh the unread badge from a fresh novel detail. The chapter list is
    // needed to compute how many chapters remain after the one just read.
    try {
      final detail = await getIt<MasiroRepository>().getNovelDetail(n.id);
      final chapters = [
        for (final volume in detail.volumes) ...volume.chapters,
      ];
      final readChapterId = lastChapterId ?? lastReadChapterId;
      final index = chapters.indexWhere((c) => c.id == readChapterId);
      bloc.add(
        FavoritesScreenNovelStatUpdated(
          novelId: n.id,
          stat: BookshelfStat(
            totalChapters: chapters.length,
            unreadCount: index < 0 ? 0 : chapters.length - index - 1,
            lastReadChapterId: readChapterId,
            lastReadAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        e.toString().toast();
      }
    }
  }
}
