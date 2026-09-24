import 'package:equatable/equatable.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_state.dart';
import 'package:masiro/data/repository/model/bookshelf_stat.dart';

sealed class FavoritesScreenEvent extends Equatable {
  @override
  List<Object> get props => [];
}

final class FavoritesScreenRequested extends FavoritesScreenEvent {}

final class FavoritesScreenRefreshed extends FavoritesScreenEvent {}

/// Selects a sort mode from the sort menu. Selecting the current mode again
/// toggles the sort direction.
final class FavoritesScreenSortSelected extends FavoritesScreenEvent {
  final FavoritesSortMode mode;

  FavoritesScreenSortSelected(this.mode);

  @override
  List<Object> get props => [mode];
}

/// Turns the manual adjustment mode on or off.
final class FavoritesScreenManualModeToggled extends FavoritesScreenEvent {}

/// Moves a novel up or down in the manual order.
final class FavoritesScreenNovelMoved extends FavoritesScreenEvent {
  final int novelId;
  final bool moveUp;

  FavoritesScreenNovelMoved({required this.novelId, required this.moveUp});

  @override
  List<Object> get props => [novelId, moveUp];
}

/// Switches between the list and grid display modes.
final class FavoritesScreenViewModeChanged extends FavoritesScreenEvent {
  final FavoritesViewMode mode;

  FavoritesScreenViewModeChanged(this.mode);

  @override
  List<Object> get props => [mode];
}

/// Updates the cached bookshelf statistics of a novel, e.g. after the
/// reader is popped.
final class FavoritesScreenNovelStatUpdated extends FavoritesScreenEvent {
  final int novelId;
  final BookshelfStat stat;

  FavoritesScreenNovelStatUpdated({required this.novelId, required this.stat});

  @override
  List<Object> get props => [novelId, stat];
}

/// Toggles the batch management mode on or off.
final class FavoritesScreenBatchModeToggled extends FavoritesScreenEvent {}

/// Toggles the selection of a novel in batch mode.
final class FavoritesScreenNovelSelectionToggled extends FavoritesScreenEvent {
  final int novelId;

  FavoritesScreenNovelSelectionToggled({required this.novelId});

  @override
  List<Object> get props => [novelId];
}

/// Removes all selected novels from favorites.
final class FavoritesScreenSelectedNovelsRemoved extends FavoritesScreenEvent {}

/// Toggles selection of all novels in batch mode.
final class FavoritesScreenAllSelectionToggled extends FavoritesScreenEvent {}
