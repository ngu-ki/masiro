import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/bloc/screen/search/search_screen_bloc.dart';
import 'package:masiro/bloc/screen/search/search_screen_event.dart';
import 'package:masiro/bloc/screen/search/search_screen_state.dart';
import 'package:masiro/data/repository/model/novel.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/router.dart';
import 'package:masiro/ui/widgets/message.dart';
import 'package:masiro/ui/widgets/novel_card.dart';

class NovelList extends StatefulWidget {
  final List<Novel> novels;
  final InfiniteListStatus status;
  final int totalCount;

  /// Whether a search has already been performed. Before the first search
  /// the discovery page shows a tappable mascot instead of the empty
  /// message.
  final bool hasSearched;

  /// Called when the mascot on the initial empty discovery page is tapped.
  final void Function()? onTapMascot;

  /// Extra space reserved at the top of the scrollable area for the
  /// floating search bar that overlays the list.
  final double topPadding;

  const NovelList({
    super.key,
    required this.novels,
    required this.status,
    required this.totalCount,
    this.hasSearched = true,
    this.onTapMascot,
    this.topPadding = 0,
  });

  @override
  State<NovelList> createState() => _NovelListState();
}

class _NovelListState extends State<NovelList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();
    final novels = widget.novels;
    final status = widget.status;

    if (novels.isEmpty) {
      if (!widget.hasSearched) {
        return Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: Center(
            child: GestureDetector(
              onTap: widget.onTapMascot,
              child: Image.asset(
                'assets/img/click_me.png',
                width: MediaQuery.of(context).size.width * 0.6,
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: Message(message: localizations.noContentMessage),
      );
    }

    final infiniteList = ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        10,
        10 + widget.topPadding,
        10,
        10,
      ),
      itemCount: novels.length,
      itemBuilder: (context, index) {
        final n = novels[index];
        Widget card = NovelCard(
          title: n.title,
          coverImg: n.coverImg,
          author: n.author,
          lastUpdated: n.lastUpdated,
          brief: n.brief,
          onTap: () => context.push(
            RoutePath.novel,
            extra: {'novelId': n.id, 'lvLimit': n.lvLimit},
          ),
        );
        if (isDesktop) {
          card = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: card,
            ),
          );
        }
        return card;
      },
    );

    return Stack(
      children: [
        infiniteList,
        if (status == InfiniteListStatus.loading)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(children: [LinearProgressIndicator()]),
          ),
      ],
    );
  }

  void _onScroll() {
    if (!_isBottom) {
      return;
    }
    context.read<SearchScreenBloc>().add(SearchScreenBottomReached());
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll - 5.0);
  }
}
