import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_bloc.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_event.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_state.dart';
import 'package:masiro/data/repository/model/novel.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/easy_refresh.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/router.dart';
import 'package:masiro/ui/widgets/error_message.dart';
import 'package:masiro/ui/widgets/message.dart';
import 'package:masiro/ui/widgets/novel_card.dart';

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
      child: SafeArea(
        child: BlocProvider(
          create: (_) => FavoritesScreenBloc()..add(FavoritesScreenRequested()),
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
                ? buildNovelList(context, state)
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
      ],
    );
  }

  Widget buildHeader(BuildContext context, FavoritesScreenLoadedState state) {
    final localizations = context.localizations();
    final colorScheme = context.colorScheme();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Row(
        children: [
          Text(
            localizations.favorites,
            style: context.textTheme().titleLarge,
          ),
          const Spacer(),
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
          IconButton(
            isSelected: state.manualAdjusting,
            tooltip: localizations.manualSort,
            icon: const Icon(Icons.swap_vert_rounded),
            selectedIcon: Icon(
              Icons.swap_vert_rounded,
              color: colorScheme.primary,
            ),
            onPressed: () {
              context
                  .read<FavoritesScreenBloc>()
                  .add(FavoritesScreenManualModeToggled());
            },
          ),
        ],
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

  Widget buildNovelList(BuildContext context, FavoritesScreenLoadedState state) {
    final bloc = context.read<FavoritesScreenBloc>();
    final novels = state.novels;

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
          onTap: () => _navigateToNovelDetailScreen(context, n),
          onMoveUp: state.manualAdjusting && index > 0
              ? () => bloc.add(
                    FavoritesScreenNovelMoved(novelId: n.id, moveUp: true),
                  )
              : null,
          onMoveDown: state.manualAdjusting && index < novels.length - 1
              ? () => bloc.add(
                    FavoritesScreenNovelMoved(novelId: n.id, moveUp: false),
                  )
              : null,
        );
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
}
