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

  /// Locally recorded timestamps of when each novel entered the favorites.
  Map<int, int> _favoritedAt = {};

  /// The sort mode/direction active before entering the manual adjustment
  /// mode, restored when the adjustment is canceled.
  FavoritesSortMode? _modeBeforeManual;
  FavoritesSortDirection? _directionBeforeManual;

  /// Token used to cancel stale unread-count enrichment runs.
  int _enrichToken = 0;

  /// Whether the unread counts have already been enriched once.
  bool _statsEnriched = false;

  FavoritesScreenBloc() : super(_computeInitialState()) {
    on<FavoritesScreenRequested>(_onRequestFavoritesScreen);
    on<FavoritesScreenRefreshed>(_onRefreshFavoritesScreen);
    on<FavoritesScreenSortSelected>(_onSortSelected);
    on<FavoritesScreenManualModeEntered>(_onManualModeEntered);
    on<FavoritesScreenManualModeConfirmed>(_onManualModeConfirmed);
    on<FavoritesScreenManualModeExited>(_onManualModeExited);
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
    final stats = prefs.bookshelfStats;
    final mode = _parseSortMode(prefs.favoritesSortMode);
    return FavoritesScreenLoadedState(
      novels: _applySort(
        List.from(cached),
        mode,
        FavoritesSortDirection.ascending,
        stats,
        prefs.bookshelfFavoritedAt,
      ),
      sortMode: mode,
      viewMode: prefs.favoritesViewMode == FavoritesViewMode.grid.name
          ? FavoritesViewMode.grid
          : FavoritesViewMode.list,
      stats: stats,
    );
  }

  static FavoritesSortMode _parseSortMode(String name) {
    for (final mode in FavoritesSortMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return FavoritesSortMode.recentlyRead;
  }

  FavoritesSortMode get _storedSortMode =>
      _parseSortMode(_preferencesRepository.favoritesSortMode);

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
      _favoritedAt = Map.from(_preferencesRepository.bookshelfFavoritedAt);
      _stampNewFavorites();
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
            novels: _sortNovels(_novels, _storedSortMode),
            sortMode: _storedSortMode,
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
      _favoritedAt = Map.from(_preferencesRepository.bookshelfFavoritedAt);
      _stampNewFavorites();
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
            novels: _sortNovels(_novels, _storedSortMode),
            sortMode: _storedSortMode,
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

  /// Stamps novels that are new to the favorites with the current time, so
  /// the recently read sort shows them at the front until another novel is
  /// read. Entries of novels no longer favorited are dropped.
  void _stampNewFavorites() {
    final ids = _novels.map((n) => n.id).toSet();
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final id in ids) {
      if (!_favoritedAt.containsKey(id)) {
        _favoritedAt[id] = now;
        changed = true;
      }
    }
    final stale = _favoritedAt.keys.where((id) => !ids.contains(id)).toList();
    for (final id in stale) {
      _favoritedAt.remove(id);
      changed = true;
    }
    if (changed) {
      _preferencesRepository.bookshelfFavoritedAt = _favoritedAt;
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

    _preferencesRepository.favoritesSortMode = mode.name;
    emit(
      current.copyWith(
        novels: _sortNovels(_novels, mode, direction),
        sortMode: mode,
        sortDirection: direction,
      ),
    );
  }

  void _onManualModeEntered(
    FavoritesScreenManualModeEntered event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState || current.manualAdjusting) {
      return;
    }
    // Remember the active sort so it can be restored on cancel. The novels
    // keep the currently displayed arrangement as the starting layout.
    _modeBeforeManual = current.sortMode;
    _directionBeforeManual = current.sortDirection;
    emit(
      current.copyWith(
        manualAdjusting: true,
        isBatchMode: false,
        selectedNovelIds: const {},
      ),
    );
  }

  void _onManualModeConfirmed(
    FavoritesScreenManualModeConfirmed event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState || !current.manualAdjusting) {
      return;
    }
    // Persist the working arrangement as the custom order and switch to it.
    _preferencesRepository.favoritesOrder =
        current.novels.map((n) => '${n.id}').toList();
    _preferencesRepository.favoritesSortMode =
        FavoritesSortMode.defaultOrder.name;
    _modeBeforeManual = null;
    _directionBeforeManual = null;
    emit(
      current.copyWith(
        sortMode: FavoritesSortMode.defaultOrder,
        manualAdjusting: false,
      ),
    );
  }

  void _onManualModeExited(
    FavoritesScreenManualModeExited event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState || !current.manualAdjusting) {
      return;
    }
    // Discard the working arrangement and restore the previous sort mode.
    final mode = _modeBeforeManual ?? current.sortMode;
    final direction = _directionBeforeManual ?? current.sortDirection;
    _modeBeforeManual = null;
    _directionBeforeManual = null;
    emit(
      current.copyWith(
        novels: _sortNovels(_novels, mode, direction),
        sortMode: mode,
        sortDirection: direction,
        manualAdjusting: false,
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

    // The arrangement is only persisted when the adjustment is confirmed.
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

  /// Loads the unread count of every favorite novel one by one, strictly
  /// serially, in the background. This app is a third-party client, so the
  /// request pacing must not look like a scraping script: never fire more
  /// than one detail request at a time. Cached statistics are shown
  /// immediately and UI updates are throttled locally; preferences are
  /// serialized and written only once.
  Future<void> _enrichUnreadCounts({bool forceRefresh = false}) async {
    final token = ++_enrichToken;
    final novels = List<Novel>.from(_novels);

    const minEmitInterval = Duration(milliseconds: 400);
    var lastEmitAt = DateTime.now().subtract(minEmitInterval);

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
        final newStats = Map<int, BookshelfStat>.from(_stats);
        final fresh = _buildStat(detail);
        final old = _stats[novel.id];
        // Preserve the locally recorded reading timestamp; stamp "now"
        // when the server reports reading progress on a new chapter.
        final progressChanged = old != null &&
            old.lastReadChapterId != fresh.lastReadChapterId &&
            fresh.lastReadChapterId != 0;
        final stat = progressChanged
            ? fresh.copyWith(lastReadAt: DateTime.now().millisecondsSinceEpoch)
            : (old != null
                ? fresh.copyWith(lastReadAt: old.lastReadAt)
                : fresh);
        newStats[novel.id] = stat;
        _stats = newStats;

        // Local-only throttle: stats that arrive within the window are
        // accumulated and flushed by the emit after the loop.
        final now = DateTime.now();
        if (now.difference(lastEmitAt) >= minEmitInterval) {
          lastEmitAt = now;
          _emitStatsState();
        }
      } catch (_) {
        // Keep the cached value when the detail cannot be loaded.
      }
    }

    // Persist the whole map once instead of re-encoding it per book, and
    // make sure the final state reflects everything that was fetched.
    if (token == _enrichToken && !isClosed) {
      _preferencesRepository.bookshelfStats = _stats;
      _emitStatsState();
    }
  }

  /// Emits the current stats map (re-sorting when the active order depends
  /// on stats).
  void _emitStatsState() {
    final current = state;
    if (current is! FavoritesScreenLoadedState) {
      return;
    }
    final novels = current.sortMode == FavoritesSortMode.recentlyRead ||
            current.sortMode == FavoritesSortMode.chapterCount
        ? _sortNovels(_novels, current.sortMode, current.sortDirection)
        : null;
    emit(current.copyWith(stats: _stats, novels: novels));
  }

  List<Novel> _sortNovels(
    List<Novel> novels, [
    FavoritesSortMode mode = FavoritesSortMode.recentlyRead,
    FavoritesSortDirection direction = FavoritesSortDirection.ascending,
  ]) {
    return _applySort(novels, mode, direction, _stats, _favoritedAt);
  }

  static List<Novel> _applySort(
    List<Novel> novels,
    FavoritesSortMode mode,
    FavoritesSortDirection direction,
    Map<int, BookshelfStat> stats,
    Map<int, int> favoritedAt,
  ) {
    switch (mode) {
      case FavoritesSortMode.defaultOrder:
        return _applyManualOrder(novels);
      case FavoritesSortMode.recentlyRead:
        // Fixed order: the most recently read novel on top. The key is the
        // later of the locally recorded reading timestamp and the timestamp
        // of entering the favorites, so newly favorited novels start at the
        // front but are overtaken by whatever is read afterwards.
        final indexed = novels.asMap().entries.toList()
          ..sort((a, b) {
            final ta = _recentKey(a.value.id, stats, favoritedAt);
            final tb = _recentKey(b.value.id, stats, favoritedAt);
            if (ta != tb) {
              return tb.compareTo(ta);
            }
            return a.key.compareTo(b.key);
          });
        return indexed.map((e) => e.value).toList();
      case FavoritesSortMode.lastUpdated:
        // Fixed order: the most recently updated novel always comes first.
        return [...novels]
          ..sort(
            (b, a) => _parseTime(a.lastUpdatedTime)
                .compareTo(_parseTime(b.lastUpdatedTime)),
          );
      case FavoritesSortMode.wordCount:
        // Always descending: novels with more words come first.
        return [...novels]
          ..sort((a, b) => b.words.compareTo(a.words));
      case FavoritesSortMode.chapterCount:
        // Always descending: sort by the total chapter count from the
        // enriched stats. Novels whose stats are not loaded yet (count 0)
        // always sink to the bottom.
        int countOf(Novel n) => stats[n.id]?.totalChapters ?? 0;
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

  static int _recentKey(
    int id,
    Map<int, BookshelfStat> stats,
    Map<int, int> favoritedAt,
  ) {
    final read = stats[id]?.lastReadAt ?? 0;
    final favorited = favoritedAt[id] ?? 0;
    return read > favorited ? read : favorited;
  }

  static List<Novel> _applyManualOrder(List<Novel> novels) {
    final order = PreferencesRepository().favoritesOrder;
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

  static DateTime _parseTime(String? time) {
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
