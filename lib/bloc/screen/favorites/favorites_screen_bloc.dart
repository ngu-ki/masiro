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

  FavoritesScreenBloc() : super(FavoritesScreenInitialState()) {
    on<FavoritesScreenRequested>(_onRequestFavoritesScreen);
    on<FavoritesScreenRefreshed>(_onRefreshFavoritesScreen);
    on<FavoritesScreenSortSelected>(_onSortSelected);
    on<FavoritesScreenManualModeToggled>(_onManualModeToggled);
    on<FavoritesScreenNovelMoved>(_onNovelMoved);
    on<FavoritesScreenViewModeChanged>(_onViewModeChanged);
    on<FavoritesScreenNovelStatUpdated>(_onNovelStatUpdated);
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
    var direction = FavoritesSortDirection.ascending;
    if (current.sortMode == mode && mode != FavoritesSortMode.defaultOrder) {
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
      ),
    );
  }

  void _onNovelMoved(
    FavoritesScreenNovelMoved event,
    Emitter<FavoritesScreenState> emit,
  ) {
    final current = state;
    if (current is! FavoritesScreenLoadedState) {
      return;
    }

    final ids = current.novels.map((n) => n.id).toList();
    final from = ids.indexOf(event.novelId);
    final to = event.moveUp ? from - 1 : from + 1;
    if (from < 0 || to < 0 || to >= ids.length) {
      return;
    }
    ids.removeAt(from);
    ids.insert(to, event.novelId);

    _preferencesRepository.favoritesOrder =
        ids.map((id) => '$id').toList();

    final byId = {for (final n in current.novels) n.id: n};
    emit(
      current.copyWith(
        novels: ids.map((id) => byId[id]).whereType<Novel>().toList(),
      ),
    );
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
    _stats[event.novelId] = event.stat;
    _preferencesRepository.bookshelfStats = _stats;
    emit(current.copyWith(stats: _stats));
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
        _stats[novel.id] = _buildStat(detail);
        _preferencesRepository.bookshelfStats = _stats;
        final current = state;
        if (current is FavoritesScreenLoadedState) {
          emit(current.copyWith(stats: _stats));
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
        // The server returns favorites in recently-read order; use the
        // original index as the sort key.
        final indexed = novels.asMap().entries.toList();
        final positions = {
          for (final n in _novels.asMap().entries) n.value.id: n.key,
        };
        indexed.sort((a, b) {
          final pa = positions[a.value.id];
          final pb = positions[b.value.id];
          if (pa != null && pb != null) {
            return pa.compareTo(pb);
          }
          if (pa != null) return -1;
          if (pb != null) return 1;
          return a.key.compareTo(b.key);
        });
        final sorted = indexed.map((e) => e.value).toList();
        return direction == FavoritesSortDirection.descending
            ? sorted.reversed.toList()
            : sorted;
      case FavoritesSortMode.lastUpdated:
        final sorted = [...novels]
          ..sort(
            (a, b) => _parseTime(a.lastUpdatedTime)
                .compareTo(_parseTime(b.lastUpdatedTime)),
          );
        return direction == FavoritesSortDirection.descending
            ? sorted.reversed.toList()
            : sorted;
      case FavoritesSortMode.name:
        final sorted = [...novels]..sort((a, b) => a.title.compareTo(b.title));
        return direction == FavoritesSortDirection.descending
            ? sorted.reversed.toList()
            : sorted;
      case FavoritesSortMode.wordCount:
        final sorted = [...novels]..sort((a, b) => a.words.compareTo(b.words));
        return direction == FavoritesSortDirection.descending
            ? sorted.reversed.toList()
            : sorted;
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
