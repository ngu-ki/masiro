import 'package:equatable/equatable.dart';
import 'package:masiro/bloc/screen/favorites/favorites_screen_state.dart';

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
