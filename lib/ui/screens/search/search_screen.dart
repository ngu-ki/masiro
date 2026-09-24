import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:masiro/bloc/screen/search/search_screen_bloc.dart';
import 'package:masiro/bloc/screen/search/search_screen_event.dart';
import 'package:masiro/bloc/screen/search/search_screen_state.dart';
import 'package:masiro/ui/screens/search/novel_list.dart';
import 'package:masiro/ui/screens/search/search_top_bar.dart';
import 'package:masiro/ui/widgets/error_message.dart';

class SearchScreen extends StatefulWidget {
  /// The keyword to search automatically when the screen is opened.
  final String? initialKeyword;

  const SearchScreen({super.key, this.initialKeyword});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final GlobalKey<SearchTopBarState> _searchBarKey =
      GlobalKey<SearchTopBarState>();

  @override
  Widget build(BuildContext context) {
    final initialKeyword = widget.initialKeyword;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: BlocProvider(
          create: (_) {
            final bloc = SearchScreenBloc();
            if (initialKeyword != null && initialKeyword.isNotEmpty) {
              bloc.add(SearchScreenSearched(keyword: initialKeyword));
            }
            return bloc;
          },
          child: Column(
            children: [
              SearchTopBar(
                key: _searchBarKey,
                initialKeyword: initialKeyword,
              ),
              Expanded(child: buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBody(BuildContext context) {
    return BlocBuilder<SearchScreenBloc, SearchScreenState>(
      builder: (context, state) {
        switch (state) {
          case SearchScreenLoadingState():
            return const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
            );
          case SearchScreenErrorState():
            return ErrorMessage(message: state.message);
          case SearchScreenLoadedState():
            return NovelList(
              novels: state.novels,
              status: state.infiniteListStatus,
              totalCount: state.totalCount,
              hasSearched: state.hasSearched,
              onTapMascot: () =>
                  _searchBarKey.currentState?.openSearchView(),
            );
        }
      },
    );
  }
}
