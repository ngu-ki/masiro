import 'package:equatable/equatable.dart';
import 'package:masiro/data/repository/model/bookshelf_stat.dart';
import 'package:masiro/data/repository/model/novel.dart';

/// The sort mode of the favorites list.
enum FavoritesSortMode {
  /// The custom order saved by the manual adjustment (自设排序).
  defaultOrder,

  /// Sort by the recently read order; newly favorited novels start at the
  /// front until another novel is read.
  recentlyRead,

  /// Sort by the last updated time.
  lastUpdated,

  /// Sort by the word count (descending only).
  wordCount,

  /// Sort by the total chapter count (descending only).
  chapterCount,
}

/// The sort direction of the favorites list.
enum FavoritesSortDirection {
  ascending,
  descending,
}

/// The display mode of the favorites list.
enum FavoritesViewMode {
  list,
  grid,
}

sealed class FavoritesScreenState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FavoritesScreenInitialState extends FavoritesScreenState {}

class FavoritesScreenErrorState extends FavoritesScreenState {
  final String? message;

  FavoritesScreenErrorState({this.message});

  @override
  List<Object?> get props => [message];
}

class FavoritesScreenLoadedState extends FavoritesScreenState {
  final List<Novel> novels;
  final FavoritesSortMode sortMode;
  final FavoritesSortDirection sortDirection;

  /// Whether the manual adjustment mode is on.
  final bool manualAdjusting;

  /// The list/grid display mode.
  final FavoritesViewMode viewMode;

  /// Reading statistics keyed by novel id.
  final Map<int, BookshelfStat> stats;

  /// Whether the batch management mode is on.
  final bool isBatchMode;

  /// The set of selected novel ids in batch mode.
  final Set<int> selectedNovelIds;

  FavoritesScreenLoadedState({
    this.novels = const [],
    this.sortMode = FavoritesSortMode.recentlyRead,
    this.sortDirection = FavoritesSortDirection.ascending,
    this.manualAdjusting = false,
    this.viewMode = FavoritesViewMode.grid,
    this.stats = const {},
    this.isBatchMode = false,
    this.selectedNovelIds = const {},
  });

  FavoritesScreenLoadedState copyWith({
    List<Novel>? novels,
    FavoritesSortMode? sortMode,
    FavoritesSortDirection? sortDirection,
    bool? manualAdjusting,
    FavoritesViewMode? viewMode,
    Map<int, BookshelfStat>? stats,
    bool? isBatchMode,
    Set<int>? selectedNovelIds,
  }) {
    return FavoritesScreenLoadedState(
      novels: novels ?? this.novels,
      sortMode: sortMode ?? this.sortMode,
      sortDirection: sortDirection ?? this.sortDirection,
      manualAdjusting: manualAdjusting ?? this.manualAdjusting,
      viewMode: viewMode ?? this.viewMode,
      stats: stats ?? this.stats,
      isBatchMode: isBatchMode ?? this.isBatchMode,
      selectedNovelIds: selectedNovelIds ?? this.selectedNovelIds,
    );
  }

  @override
  List<Object?> get props => [
        novels,
        sortMode,
        sortDirection,
        manualAdjusting,
        viewMode,
        stats,
        isBatchMode,
        selectedNovelIds,
      ];
}
