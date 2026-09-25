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
  /// The opaque background only extends to the horizontal midline of the
  /// pill's rounded (stadium) ends. Below that line the pill's own opaque
  /// background covers its interior, so scrolling cards stay visible beside
  /// the rounded bottom corners instead of being blocked by a rectangular
  /// patch. The 8px gap below the pill ([searchBarHeight] includes it) is
  /// also left open, so cards travel underneath the pill and its elevation
  /// shadow rather than being clipped on a hard line.
  Widget buildFloatingHeader(BuildContext context) {
    final pillHeight = searchBarHeight - 2 * searchBarPadding;
    final headerBackgroundHeight = searchBarPadding + pillHeight / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerBackgroundHeight,
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
