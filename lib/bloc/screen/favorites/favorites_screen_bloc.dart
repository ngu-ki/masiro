import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_event.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_state.dart';
import 'package:masiro/data/repository/favorites_repository.dart';
import 'package:masiro/data/repository/masiro_repository.dart';
import 'package:masiro/data/repository/model/bookshelf_stat.dart';
import 'package:masiro/data/repository/model/novel.dart';
import 'package:masiro/data/repository/model/novel_detail.dart';
import 'package:masiro/data/repository/preferences_repository.dart';
import 'package:masiro/di/get_it.dart';

typedef _FavoritesScreenBloc = Bloc<FavoritesScreenEvent, FavoritesScreenState>;

class FavoritesScreenBloc extends _FavoritesScreenBloc {
  final _favoritesRepository = getIt<FavoritesRepository>();
  final _masiroRepository = getIt<MasiroRepository>();
  final _preferencesRepository = PreferencesRepository();

  /// The favorites in the original order returned by the server.
  List<Novel> _novels = [];

  /// Cached reading statistics keyed by novel id.
  Map<int, BookshelfStat> _stats = {};

  /// Token used to cancel stale unread-count enrichment runs.
  int _enrichToken = 0;

  /// Whether the unread counts have already been enriched once.
  bool _statsEnriched = false;

  FavoritesScreenBloc() : super(_computeInitialState()) {
    on<FavoritesScreenRequested>(_onRequestFavoritesScreen);
    on<FavoritesScreenRefreshed>(_onRefreshFavoritesScreen);
    on<FavoritesScreenSortSelected>(_onSortSelected);
    on<FavoritesScreenManualModeToggled>(_onManualModeToggled);
    on<FavoritesScreenNovelsReordered>(_onNovelsReordered);
    on<FavoritesScreenViewModeChanged>(_onViewModeChanged);
    on<FavoritesScreenNovelStatUpdated>(_onNovelStatUpdated);
    on<FavoritesScreenBatchModeToggled>(_onBatchModeToggled);
    on<FavoritesScreenNovelSelectionToggled>(_onNovelSelectionToggled);
    on<FavoritesScreenAllSelectionToggled>(_onAllSelectionToggled);
    on<FavoritesScreenSelectedNovelsRemoved>(_onSelectedNovelsRemoved);
  }

  /// Builds the initial state from cached data if available, so the screen
  /// doesn't flash a loading indicator on subsequent visits.
  static FavoritesScreenState _computeInitialState() {
    final cached = getIt<FavoritesRepository>().cachedFavorites;
    if (cached == null || cached.isEmpty) {
      return FavoritesScreenInitialState();
    }
    final prefs = PreferencesRepository();
    return FavoritesScreenLoadedState(
      novels: List.from(cached),
      viewMode: prefs.favoritesViewMode == FavoritesViewMode.grid.name
          ? FavoritesViewMode.grid
          : FavoritesViewMode.list,
      stats: prefs.bookshelfStats,
    );
  }

  FavoritesViewMode get _storedViewMode {
    return _preferencesRepository.favoritesViewMode ==
            FavoritesViewMode.grid.name
        ? FavoritesViewMode.grid
        : FavoritesViewMode.list;
  }

  Future<void> _onRequestFavoritesScreen(
    FavoritesScreenRequested event,
    Emitter<FavoritesScreenState> emit,
  ) async {
    try {
      _novels = await _favoritesRepository.getFavorites();
      _stats = _preferencesRepository.bookshelfStats;
      final current = state;
      if (current is FavoritesScreenLoadedState) {
        emit(
          current.copyWith(
            novels:
                _sortNovels(_novels, current.sortMode, current.sortDirection),
            stats: _stats,
          ),
        );
      } else {
        emit(
          FavoritesScreenLoadedState(
            novels: _sortNovels(_novels),
            viewMode: _storedViewMode,
            stats: _stats,
          ),
        );
      }
      await _enrichUnreadCountsIfNeeded();
    } catch (e) {
      emit(FavoritesScreenErrorState(message: e.toString()));
    }
  }

  Future<void> _onRefreshFavoritesScreen(
    FavoritesScreenRefreshed event,
    Emitter<FavoritesScreenState> emit,
  ) async {
    try {
      _novels = await _favoritesRepository.refreshFavorites();
      final current = state;
      if (current is FavoritesScreenLoadedState) {
        emit(
          current.copyWith(
            novels:
                _sortNovels(_novels, current.sortMode, current.sortDirection),
          ),
        );
      } else {
        _stats = _preferencesRepository.bookshelfStats;
        emit(
          FavoritesScreenLoadedState(
            novels: _sortNovels(_novels),
            viewMode: _storedViewMode,
            stats: _stats,
          ),
        );
      }
      await _enrichUnreadCountsIfNeeded(forceRefresh: true);
    } catch (e) {
      emit(FavoritesScreenErrorState(message: e.toString()));
    }
  }

  void _onSortSelected(
    FavoritesScreenSortSelected event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState) {
      return;
    }

    final mode = event.mode;
    // Last updated, word count and chapter count start descending on the
    // first tap (newest / largest on top).
    final startsDescending = mode == FavoritesSortMode.lastUpdated ||
        mode == FavoritesSortMode.wordCount ||
        mode == FavoritesSortMode.chapterCount;
    var direction = startsDescending
        ? FavoritesSortDirection.descending
        : FavoritesSortDirection.ascending;
    // Default order, recently read, word count and chapter count never flip
    // on re-tap; only the other modes toggle their direction.
    if (current.sortMode == mode &&
        mode != FavoritesSortMode.defaultOrder &&
        mode != FavoritesSortMode.recentlyRead &&
        mode != FavoritesSortMode.wordCount &&
        mode != FavoritesSortMode.chapterCount) {
      direction = current.sortDirection == FavoritesSortDirection.ascending
          ? FavoritesSortDirection.descending
          : FavoritesSortDirection.ascending;
    }

    emit(
      current.copyWith(
        novels: _sortNovels(_novels, mode, direction),
        sortMode: mode,
        sortDirection: direction,
      ),
    );
  }

  void _onManualModeToggled(
    FavoritesScreenManualModeToggled event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState) {
      return;
    }

    if (current.manualAdjusting) {
      emit(current.copyWith(manualAdjusting: false));
      return;
    }

    // The manual adjustment only makes sense in the default order.
    emit(
      current.copyWith(
        novels: _sortNovels(
          _novels,
          FavoritesSortMode.defaultOrder,
          current.sortDirection,
        ),
        sortMode: FavoritesSortMode.defaultOrder,
        manualAdjusting: true,
        isBatchMode: false,
        selectedNovelIds: const {},
      ),
    );
  }

  void _onBatchModeToggled(
    FavoritesScreenBatchModeToggled event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState) {
      return;
    }
    final newBatchMode = !current.isBatchMode;
    emit(
      current.copyWith(
        isBatchMode: newBatchMode,
        selectedNovelIds: newBatchMode ? current.selectedNovelIds : const {},
        manualAdjusting: false,
      ),
    );
  }

  void _onNovelSelectionToggled(
    FavoritesScreenNovelSelectionToggled event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState || !current.isBatchMode) {
      return;
    }
    final selected = Set<int>.from(current.selectedNovelIds);
    if (selected.contains(event.novelId)) {
      selected.remove(event.novelId);
    } else {
      selected.add(event.novelId);
    }
    emit(current.copyWith(selectedNovelIds: selected));
  }

  void _onAllSelectionToggled(
    FavoritesScreenAllSelectionToggled event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState || !current.isBatchMode) {
      return;
    }
    final allSelected =
        current.selectedNovelIds.length == current.novels.length;
    emit(
      current.copyWith(
        selectedNovelIds: allSelected
            ? <int>{}
            : current.novels.map((n) => n.id).toSet(),
      ),
    );
  }

  Future<void> _onSelectedNovelsRemoved(
    FavoritesScreenSelectedNovelsRemoved event,
    Emitter<FavoritesScreenState> emit,
  ) async {
    final current = state;
    if (current is! FavoritesScreenLoadedState || !current.isBatchMode) {
      return;
    }
    final selectedIds = current.selectedNovelIds;
    if (selectedIds.isEmpty) {
      return;
    }
    // The uncollect API requires a csrf token per novel, so we fetch each
    // novel's detail to obtain it before removing.
    for (final novelId in selectedIds) {
      try {
        final detail = await _masiroRepository.getNovelDetail(novelId);
        await _favoritesRepository.removeFromFavorites(
          novelId,
          detail.header.csrfToken,
        );
      } catch (_) {
        // Continue removing other novels even if one fails.
      }
    }
    _novels.removeWhere((n) => selectedIds.contains(n.id));
    _stats = Map.fromEntries(
      _stats.entries.where((e) => !selectedIds.contains(e.key)),
    );
    emit(
      current.copyWith(
        novels: _sortNovels(_novels, current.sortMode, current.sortDirection),
        isBatchMode: true,
        selectedNovelIds: const {},
        stats: _stats,
      ),
    );
  }

  void _onNovelsReordered(
    FavoritesScreenNovelsReordered event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState) {
      return;
    }

    if (event.oldIndex < 0 ||
        event.newIndex < 0 ||
        event.oldIndex >= current.novels.length ||
        event.newIndex >= current.novels.length) {
      return;
    }

    final novels = [...current.novels];
    final novel = novels.removeAt(event.oldIndex);
    novels.insert(event.newIndex, novel);

    _preferencesRepository.favoritesOrder =
        novels.map((n) => '${n.id}').toList();

    emit(current.copyWith(novels: novels));
  }

  Future<void> _onViewModeChanged(
    FavoritesScreenViewModeChanged event,
    Emitter<FavoritesScreenState> emit,
  ) async {
    final current = state;
    if (current is! FavoritesScreenLoadedState ||
        current.viewMode == event.mode) {
      return;
    }
    _preferencesRepository.favoritesViewMode = event.mode.name;
    emit(current.copyWith(viewMode: event.mode));
    if (event.mode == FavoritesViewMode.grid) {
      await _enrichUnreadCountsIfNeeded();
    }
  }

  void _onNovelStatUpdated(
    FavoritesScreenNovelStatUpdated event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState) {
      return;
    }
    final newStats = Map<int, BookshelfStat>.from(_stats);
    newStats[event.novelId] = event.stat;
    _stats = newStats;
    _preferencesRepository.bookshelfStats = _stats;
    final novels = current.sortMode == FavoritesSortMode.recentlyRead ||
            current.sortMode == FavoritesSortMode.chapterCount
        ? _sortNovels(_novels, current.sortMode, current.sortDirection)
        : null;
    emit(current.copyWith(stats: _stats, novels: novels));
  }

  /// Builds the unread statistics from a novel detail: chapters are flattened
  /// across volumes in reading order, and the unread count is the number of
  /// chapters after the server-reported last read chapter.
  BookshelfStat _buildStat(NovelDetail detail) {
    final chapters = [
      for (final volume in detail.volumes) ...volume.chapters,
    ];
    final lastReadIndex =
        chapters.indexWhere((c) => c.id == detail.lastReadChapterId);
    final unread = lastReadIndex < 0
        ? chapters.length
        : chapters.length - lastReadIndex - 1;
    return BookshelfStat(
      totalChapters: chapters.length,
      unreadCount: unread,
      lastReadChapterId: detail.lastReadChapterId,
    );
  }

  /// Enriches the unread counts for both list and grid modes. Normal
  /// loads run once; pull-to-refresh always forces a reload.
  Future<void> _enrichUnreadCountsIfNeeded({
    bool forceRefresh = false,
  }) async {
    final current = state;
    if (current is! FavoritesScreenLoadedState) {
      return;
    }
    if (_statsEnriched && !forceRefresh) {
      return;
    }
    _statsEnriched = true;
    await _enrichUnreadCounts(forceRefresh: forceRefresh);
  }

  /// Loads the unread count of every favorite novel one by one in the
  /// background. Cached statistics are shown immediately and each novel is
  /// updated in the state as soon as its detail is fetched.
  Future<void> _enrichUnreadCounts({bool forceRefresh = false}) async {
    final token = ++_enrichToken;
    final novels = List<Novel>.from(_novels);
    for (final novel in novels) {
      if (token != _enrichToken || isClosed) {
        return;
      }
      try {
        final detail = await _masiroRepository.getNovelDetail(
          novel.id,
          forceRefresh: forceRefresh,
        );
        if (token != _enrichToken || isClosed) {
          return;
        }
        // Create a new map so the state change is detected by Equatable.
        // Mutating _stats in place and passing the same reference would
        // make the old and new states share the same map, so BlocBuilder
        // would not rebuild and the grid card would never show the stats.
        final newStats = Map<int, BookshelfStat>.from(_stats);
        newStats[novel.id] = _buildStat(detail);
        _stats = newStats;
        _preferencesRepository.bookshelfStats = _stats;
        final current = state;
        if (current is FavoritesScreenLoadedState) {
          // Re-sort novels if the current order depends on the enriched
          // stats (recently read or chapter count).
          final novels = current.sortMode == FavoritesSortMode.recentlyRead ||
                  current.sortMode == FavoritesSortMode.chapterCount
              ? _sortNovels(_novels, current.sortMode, current.sortDirection)
              : null;
          emit(
            current.copyWith(
              stats: _stats,
              novels: novels,
            ),
          );
        }
      } catch (_) {
        // Keep the cached value when the detail cannot be loaded.
      }
    }
  }

  List<Novel> _sortNovels(
    List<Novel> novels, [
    FavoritesSortMode mode = FavoritesSortMode.defaultOrder,
    FavoritesSortDirection direction = FavoritesSortDirection.ascending,
  ]) {
    switch (mode) {
      case FavoritesSortMode.defaultOrder:
        return _sortByManualOrder(novels);
      case FavoritesSortMode.recentlyRead:
        // Fixed order: the most recently read novel on top. A higher
        // last-read chapter ID generally means more recently read; novels
        // without stats go to the end.
        return [...novels]..sort((a, b) {
            final sa = _stats[a.id];
            final sb = _stats[b.id];
            final la = sa?.lastReadChapterId ?? -1;
            final lb = sb?.lastReadChapterId ?? -1;
            return lb.compareTo(la);
          });
      case FavoritesSortMode.lastUpdated:
        final sorted = [...novels]
          ..sort(
            (a, b) => _parseTime(a.lastUpdatedTime)
                .compareTo(_parseTime(b.lastUpdatedTime)),
          );
        return direction == FavoritesSortDirection.descending
            ? sorted.reversed.toList()
            : sorted;
      case FavoritesSortMode.wordCount:
        // Always descending: novels with more words come first.
        return [...novels]
          ..sort((a, b) => b.words.compareTo(a.words));
      case FavoritesSortMode.chapterCount:
        // Always descending: sort by the total chapter count from the
        // enriched stats. Novels whose stats are not loaded yet (count 0)
        // always sink to the bottom.
        int countOf(Novel n) => _stats[n.id]?.totalChapters ?? 0;
        return [...novels]..sort((a, b) {
          final ca = countOf(a);
          final cb = countOf(b);
          if (ca == 0 && cb != 0) {
            return 1;
          }
          if (cb == 0 && ca != 0) {
            return -1;
          }
          return cb.compareTo(ca);
        });
    }
  }

  List<Novel> _sortByManualOrder(List<Novel> novels) {
    final order = _preferencesRepository.favoritesOrder;
    if (order.isEmpty) {
      return novels;
    }
    final positions = {
      for (var i = 0; i < order.length; i++) int.tryParse(order[i]): i,
    };
    final indexed = novels.asMap().entries.toList()
      ..sort((a, b) {
        final pa = positions[a.value.id];
        final pb = positions[b.value.id];
        if (pa != null && pb != null) {
          return pa.compareTo(pb);
        }
        if (pa != null) {
          return -1;
        }
        if (pb != null) {
          return 1;
        }
        // Keep the original relative order for novels without a manual position.
        return a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  DateTime _parseTime(String? time) {
    if (time == null || time.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    final seconds = int.tryParse(time);
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    return DateTime.tryParse(time) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}
