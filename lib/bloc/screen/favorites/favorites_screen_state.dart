import 'package:equatable/equatable.dart';
import 'package:masiro/data/repository/model/novel.dart';

/// The sort mode of the favorites list.
enum FavoritesSortMode {
  /// The manually adjusted order.
  defaultOrder,

  /// Sort by the last updated time.
  lastUpdated,

  /// Sort by the novel title.
  name,

  /// Sort by the word count.
  wordCount,
}

/// The sort direction of the favorites list.
enum FavoritesSortDirection {
  ascending,
  descending,
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

  FavoritesScreenLoadedState({
    this.novels = const [],
    this.sortMode = FavoritesSortMode.defaultOrder,
    this.sortDirection = FavoritesSortDirection.ascending,
    this.manualAdjusting = false,
  });

  FavoritesScreenLoadedState copyWith({
    List<Novel>? novels,
    FavoritesSortMode? sortMode,
    FavoritesSortDirection? sortDirection,
    bool? manualAdjusting,
  }) {
    return FavoritesScreenLoadedState(
      novels: novels ?? this.novels,
      sortMode: sortMode ?? this.sortMode,
      sortDirection: sortDirection ?? this.sortDirection,
      manualAdjusting: manualAdjusting ?? this.manualAdjusting,
    );
  }

  @override
  List<Object?> get props => [
        novels,
        sortMode,
        sortDirection,
        manualAdjusting,
      ];
}
