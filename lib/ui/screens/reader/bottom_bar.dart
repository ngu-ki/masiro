import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:masiro/misc/context.dart';

const Duration _duration = Duration(milliseconds: 500);
const Curve _curve = Curves.fastOutSlowIn;

const bottomBarHeight = kToolbarHeight * 2 + 16;

class BottomBar extends StatelessWidget {
  final bool isVisible;
  final int? prevChapterId;
  final int? nextChapterId;
  final ValueListenable<double>? progress;
  final void Function(double fraction)? onSeek;

  final void Function(int chapterId) onNavigateTo;
  final void Function() onContentsClicked;
  final void Function() onSettingsClicked;
  final void Function() onCommentClicked;

  const BottomBar({
    super.key,
    required this.isVisible,
    this.prevChapterId,
    this.nextChapterId,
    this.progress,
    this.onSeek,
    required this.onNavigateTo,
    required this.onContentsClicked,
    required this.onSettingsClicked,
    required this.onCommentClicked,
  });

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 8.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final localizations = context.localizations();
    final theme = context.theme();
    final appBarThemeColor = theme.appBarTheme.backgroundColor;
    final surfaceContainerColor = theme.colorScheme.surfaceContainer;
    final backgroundColor = theme.brightness == Brightness.light
        ? const Color(0xFFFAFAFA)
        : (appBarThemeColor ?? surfaceContainerColor);
    final foregroundColor = theme.colorScheme.onSurface;

    Widget slider = const Slider(
      value: 0,
      onChanged: null,
    );
    if (progress != null) {
      slider = ValueListenableBuilder<double>(
        valueListenable: progress!,
        builder: (context, value, _) {
          return Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onSeek,
          );
        },
      );
    }

    return AnimatedPositioned(
      left: 0,
      right: 0,
      bottom: isVisible ? 0.0 : -(bottomBarHeight + bottomPadding),
      duration: _duration,
      curve: _curve,
      child: Container(
        color: backgroundColor,
        padding: EdgeInsets.only(
          bottom: bottomPadding,
          left: horizontalPadding,
          right: horizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: prevChapterId == null
                      ? null
                      : () => onNavigateTo(prevChapterId!),
                  icon: const Icon(Icons.skip_previous_rounded),
                  color: foregroundColor,
                ),
                Expanded(child: slider),
                IconButton(
                  onPressed: nextChapterId == null
                      ? null
                      : () => onNavigateTo(nextChapterId!),
                  icon: const Icon(Icons.skip_next_rounded),
                  color: foregroundColor,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLabeledButton(
                  icon: Icons.comment,
                  label: localizations.commentShort,
                  color: foregroundColor,
                  onPressed: onCommentClicked,
                ),
                _buildLabeledButton(
                  icon: Icons.menu_book_rounded,
                  label: localizations.contents,
                  color: foregroundColor,
                  onPressed: onContentsClicked,
                ),
                _buildLabeledButton(
                  icon: Icons.settings_rounded,
                  label: localizations.settings,
                  color: foregroundColor,
                  onPressed: onSettingsClicked,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledButton({
    required IconData icon,
    required String label,
    required Color color,
    required void Function() onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: color,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}
