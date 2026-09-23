import 'package:flutter/material.dart';
import 'package:masiro/misc/context.dart';

const Duration _duration = Duration(milliseconds: 500);
const Curve _curve = Curves.fastOutSlowIn;

class TopBar extends StatelessWidget {
  final bool isVisible;

  final void Function() onNavigateBack;
  final void Function() onNavigateToDetail;

  const TopBar({
    super.key,
    required this.isVisible,
    required this.onNavigateBack,
    required this.onNavigateToDetail,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return AnimatedPositioned(
      left: 0,
      right: 0,
      top: isVisible ? 0.0 : -(kToolbarHeight + statusBarHeight),
      duration: _duration,
      curve: _curve,
      child: AppBar(
        leading: IconButton(
          onPressed: onNavigateBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: localizations.detail,
            onPressed: onNavigateToDetail,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
    );
  }
}
