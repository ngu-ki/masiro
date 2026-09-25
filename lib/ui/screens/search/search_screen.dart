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
          child: Stack(
            children: [
              Positioned.fill(child: buildBody(context)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: buildFloatingHeader(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The floating search bar overlay.
  ///
  /// The opaque background deliberately ends exactly at the bottom edge of
  /// the search pill ([searchBarHeight] includes an 8px bottom gap), so
  /// scrolling cards travel underneath the pill and its elevation shadow
  /// instead of being clipped on a hard white line below the shadow.
  Widget buildFloatingHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: searchBarHeight - 8,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
        SearchTopBar(
          key: _searchBarKey,
          initialKeyword: widget.initialKeyword,
        ),
      ],
    );
  }

  Widget buildBody(BuildContext context) {
    return BlocBuilder<SearchScreenBloc, SearchScreenState>(
      builder: (context, state) {
        switch (state) {
          case SearchScreenLoadingState():
            return Padding(
              padding: const EdgeInsets.only(top: searchBarHeight),
              child: const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          case SearchScreenErrorState():
            return Padding(
              padding: const EdgeInsets.only(top: searchBarHeight),
              child: ErrorMessage(message: state.message),
            );
          case SearchScreenLoadedState():
            return NovelList(
              novels: state.novels,
              status: state.infiniteListStatus,
              totalCount: state.totalCount,
              hasSearched: state.hasSearched,
              topPadding: searchBarHeight,
              onTapMascot: () => context
                  .read<SearchScreenBloc>()
                  .add(SearchScreenSearched(keyword: '')),
            );
        }
      },
    );
  }
}
