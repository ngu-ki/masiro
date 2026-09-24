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
import 'package:masiro/misc/chapter.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/easy_refresh.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/router.dart';
import 'package:masiro/misc/toast.dart';
import 'package:masiro/ui/widgets/error_message.dart';
import 'package:masiro/ui/widgets/message.dart';
import 'package:masiro/ui/widgets/novel_card.dart';
import 'package:masiro/ui/widgets/novel_grid_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final EasyRefreshController _easyRefreshController;

  @override
  void initState() {
    super.initState();
    _easyRefreshController = EasyRefreshController();
  }

  @override
  void dispose() {
    _easyRefreshController.dispose();
    super.dispose();
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
    final novels = state.novels;

    return Column(
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
                    ? buildNovelGrid(context, state)
                    : buildNovelList(context, state)
                : LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Message(
                            message: localizations.noContentMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (state.isBatchMode) buildBatchBottomBar(context, state),
      ],
    );
  }

  Widget buildHeader(BuildContext context, FavoritesScreenLoadedState state) {
    if (state.isBatchMode) {
      return buildBatchHeader(context, state);
    }

    final localizations = context.localizations();
    final colorScheme = context.colorScheme();
    final isGrid = state.viewMode == FavoritesViewMode.grid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Row(
        children: [
          Text(
            localizations.favorites,
            style: context.textTheme().titleLarge,
          ),
          const Spacer(),
          IconButton(
            tooltip: isGrid ? localizations.listView : localizations.gridView,
            icon: Icon(
              isGrid
                  ? Icons.view_agenda_outlined
                  : Icons.grid_view_rounded,
            ),
            onPressed: () {
              context.read<FavoritesScreenBloc>().add(
                    FavoritesScreenViewModeChanged(
                      isGrid
                          ? FavoritesViewMode.list
                          : FavoritesViewMode.grid,
                    ),
                  );
            },
          ),
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
                mode: FavoritesSortMode.defaultOrder,
                label: localizations.sortDefault,
              ),
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
                mode: FavoritesSortMode.name,
                label: localizations.sortByName,
              ),
              buildSortMenuItem(
                context,
                state,
                mode: FavoritesSortMode.wordCount,
                label: localizations.sortByWordCount,
              ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: localizations.moreActions,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              final bloc = context.read<FavoritesScreenBloc>();
              if (value == 'sort') {
                bloc.add(FavoritesScreenManualModeToggled());
              } else if (value == 'batch') {
                bloc.add(FavoritesScreenBatchModeToggled());
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_vert_rounded,
                      color: state.manualAdjusting
                          ? colorScheme.primary
                          : null,
                    ),
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
      if (mode == FavoritesSortMode.defaultOrder) {
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

  Widget buildNovelList(
    BuildContext context,
    FavoritesScreenLoadedState state,
  ) {
    final bloc = context.read<FavoritesScreenBloc>();
    final novels = state.novels;
    final isBatch = state.isBatchMode;

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: novels.length,
      itemBuilder: (context, index) {
        final n = novels[index];
        Widget card = NovelCard(
          title: n.title,
          coverImg: n.coverImg,
          author: n.author,
          lastUpdated: n.lastUpdated,
          brief: n.brief,
          lvLimit: n.lvLimit,
          onTap: isBatch
              ? () => bloc.add(
                    FavoritesScreenNovelSelectionToggled(novelId: n.id),
                  )
              : () => _openReader(context, n),
          onMoveUp: !isBatch && state.manualAdjusting && index > 0
              ? () => bloc.add(
                    FavoritesScreenNovelMoved(novelId: n.id, moveUp: true),
                  )
              : null,
          onMoveDown: !isBatch &&
                  state.manualAdjusting &&
                  index < novels.length - 1
              ? () => bloc.add(
                    FavoritesScreenNovelMoved(novelId: n.id, moveUp: false),
                  )
              : null,
        );

        if (isBatch) {
          final isSelected = state.selectedNovelIds.contains(n.id);
          card = Row(
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: card,
            ),
          );
        }
        return card;
      },
    );
  }

  Widget buildNovelGrid(
    BuildContext context,
    FavoritesScreenLoadedState state,
  ) {
    final bloc = context.read<FavoritesScreenBloc>();
    final novels = state.novels;
    final isBatch = state.isBatchMode;

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

        return GridView.builder(
          padding: const EdgeInsets.all(padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 10,
            childAspectRatio: itemWidth / itemHeight,
          ),
          itemCount: novels.length,
          itemBuilder: (context, index) {
            final n = novels[index];
            final card = NovelGridCard(
              title: n.title,
              coverImg: n.coverImg,
              lvLimit: n.lvLimit,
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
          },
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
      extra: {'novelId': n.id},
    );
    if (needRefresh == null || needRefresh == false) {
      return;
    }
    await _easyRefreshController.callRefresh();
  }

  /// Opens the reader directly at the last read chapter (or the first chapter
  /// when the novel has never been read), skipping the novel detail page.
  Future<void> _openReader(BuildContext context, Novel n) async {
    final bloc = context.read<FavoritesScreenBloc>();

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    var dialogDismissed = false;
    void dismissDialog() {
      if (!dialogDismissed) {
        dialogDismissed = true;
        rootNavigator.pop();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final detail = await getIt<MasiroRepository>().getNovelDetail(n.id);
      dismissDialog();
      if (!context.mounted) {
        return;
      }

      final volumes = detail.volumes;
      final firstChapter = volumes.firstOrNull?.chapters.firstOrNull;
      final chapter =
          getChapterFromVolumes(volumes, detail.lastReadChapterId) ??
              firstChapter;
      if (chapter == null) {
        return;
      }

      final int? lastChapterId = await context.push<int?>(
        RoutePath.reader,
        extra: {
          'novelId': n.id,
          'chapterId': chapter.id,
        },
      );
      if (!context.mounted) {
        return;
      }

      // Update the unread badge immediately from the reader result.
      final readChapterId = lastChapterId ?? chapter.id;
      final chapters = [
        for (final volume in volumes) ...volume.chapters,
      ];
      final index = chapters.indexWhere((c) => c.id == readChapterId);
      bloc.add(
        FavoritesScreenNovelStatUpdated(
          novelId: n.id,
          stat: BookshelfStat(
            totalChapters: chapters.length,
            unreadCount: index < 0 ? 0 : chapters.length - index - 1,
          ),
        ),
      );
    } catch (e) {
      dismissDialog();
      if (context.mounted) {
        e.toString().toast();
      }
    }
  }
}
