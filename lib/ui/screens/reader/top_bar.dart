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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: onNavigateToDetail,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  localizations.detail,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
