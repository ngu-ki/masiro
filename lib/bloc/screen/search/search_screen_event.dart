import 'package:equatable/equatable.dart';

sealed class SearchScreenEvent extends Equatable {
  @override
  List<Object> get props => [];
}

final class SearchScreenSearched extends SearchScreenEvent {
  final String keyword;

  SearchScreenSearched({required this.keyword});

  @override
  List<Object> get props => [keyword];
}

final class SearchScreenBottomReached extends SearchScreenEvent {}

/// Resets the search state to its initial empty state. Used when the
/// discovery tab becomes inactive so the next visit starts fresh.
final class SearchScreenReset extends SearchScreenEvent {}
