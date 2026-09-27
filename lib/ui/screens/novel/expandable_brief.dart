import 'package:flutter/material.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/ui/widgets/after_layout.dart';

const _maskHeight = 40.0;
const _defaultMaxHeight = 200.0;

class ExpandableBrief extends StatefulWidget {
  final String brief;

  /// Novel tags shown as chips to the right of the "简介" title.
  final List<String> tags;

  /// Minimum user level required to read this novel. Zero means no limit.
  final int lvLimit;

  const ExpandableBrief({
    super.key,
    required this.brief,
    this.tags = const [],
    this.lvLimit = 0,
  });

  @override
  State<ExpandableBrief> createState() => _ExpandableBriefState();
}

class _ExpandableBriefState extends State<ExpandableBrief> {
  bool isExpanded = false;
  bool isExpandable = false;
  bool isLevelLimitVisible = false;
  late double intrinsicHeight;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme();
    final localizations = context.localizations();
    final surfaceColor = context.colorScheme().surface;

    // The scraped brief text starts with an inline "简介：" label. Strip it so
    // the label can be rendered as a standalone title instead.
    final briefContent = widget.brief.replaceFirst(
      RegExp(r'^[简簡]介\s*[：:]\s*'),
      '',
    );

    final boxDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [surfaceColor.withOpacity(0.5), surfaceColor.withOpacity(1.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.brief,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.lvLimit > 0) ...[
                  const SizedBox(width: 2),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(
                      () => isLevelLimitVisible = !isLevelLimitVisible,
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                    ),
                  ),
                ],
              ],
            ),
            if (widget.lvLimit > 0 && isLevelLimitVisible)
              Text(
                localizations.levelLimitMessage(widget.lvLimit),
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme().outline,
                ),
              ),
            for (final tag in widget.tags) _buildTagChip(context, tag),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            AnimatedContainer(
              constraints: BoxConstraints(
                maxHeight: isExpanded
                    ? intrinsicHeight + _maskHeight
                    : _defaultMaxHeight + _maskHeight,
              ),
              height: isExpanded ? intrinsicHeight + _maskHeight : null,
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: AfterLayout(
                callback: (value) {
                  final maxHeight = value.getMaxIntrinsicHeight(value.size.width);
                  setState(() {
                    intrinsicHeight = maxHeight;
                    isExpandable = maxHeight > _defaultMaxHeight;
                  });
                },
                child: SelectionArea(
                  child: Text(
                    briefContent,
                    softWrap: true,
                    style: textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
            if (isExpandable)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: _maskHeight,
                  decoration: boxDecoration,
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => setState(() => isExpanded = !isExpanded),
                    child: Text(
                      isExpanded
                          ? localizations.collapse
                          : localizations.expand,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// A gray rounded-rectangle chip matching the brief content's text style.
  Widget _buildTagChip(BuildContext context, String tag) {
    final colorScheme = context.colorScheme();
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag,
        style: context.textTheme().bodyLarge,
      ),
    );
  }
}
