import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:masiro/bloc/screen/search/search_screen_event.dart';
import 'package:masiro/bloc/screen/search/search_screen_state.dart';
import 'package:masiro/data/repository/masiro_repository.dart';
import 'package:masiro/di/get_it.dart';

class SearchScreenBloc extends Bloc<SearchScreenEvent, SearchScreenState> {
  final masiroRepository = getIt<MasiroRepository>();

  SearchScreenBloc() : super(SearchScreenLoadedState()) {
    on<SearchScreenSearched>(_onSearchScreenSearched);
    on<SearchScreenBottomReached>(_onSearchScreenBottomReached);
  }

  Future<void> _onSearchScreenSearched(
    SearchScreenSearched event,
    Emitter<SearchScreenState> emit,
  ) async {
    // Ignore empty keywords: otherwise the request hangs on the server and
    // the screen gets stuck on the loading indicator with no way back.
    if (event.keyword.trim().isEmpty) {
      return;
    }
    try {
      emit(SearchScreenLoadingState());
      final keyword = event.keyword;
      final result = await masiroRepository.searchNovels(
        keyword: keyword,
        page: 1,
      );
      emit(
        SearchScreenLoadedState(
          keyword: keyword,
          novels: result.data,
          page: 1,
          totalCount: result.totalCount,
          totalPages: result.totalPages,
          infiniteListStatus: InfiniteListStatus.success,
          hasSearched: true,
        ),
      );
    } catch (e) {
      emit(SearchScreenErrorState(message: e.toString()));
    }
  }

  Future<void> _onSearchScreenBottomReached(
    SearchScreenBottomReached event,
    Emitter<SearchScreenState> emit,
  ) async {
    if (state is! SearchScreenLoadedState) {
      return;
    }
    final loadedState = state as SearchScreenLoadedState;
    if (loadedState.infiniteListStatus == InfiniteListStatus.loading) {
      return;
    }
    if (loadedState.page >= loadedState.totalPages) {
      return;
    }
    try {
      emit(
        loadedState.copyWith(infiniteListStatus: InfiniteListStatus.loading),
      );
      final nextPage = loadedState.page + 1;
      final result = await masiroRepository.searchNovels(
        keyword: loadedState.keyword,
        page: nextPage,
      );
      final novels = loadedState.novels..addAll(result.data);
      emit(
        loadedState.copyWith(
          novels: novels,
          page: nextPage,
          infiniteListStatus: InfiniteListStatus.success,
        ),
      );
    } catch (e) {
      emit(
        loadedState.copyWith(infiniteListStatus: InfiniteListStatus.failure),
      );
    }
  }
}
