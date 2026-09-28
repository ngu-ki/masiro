import 'package:flutter/material.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/ui/widgets/after_layout.dart';

const _maskHeight = 60.0;
const _defaultMaxHeight = 200.0;

/// Width of the fade-out gradient to the left of the overflow chevron.
const double _kChevronFadeWidth = 12;

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

  /// Whether the tag row is expanded to show all tags on multiple lines.
  bool areTagsExpanded = false;

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
        colors: [
          surfaceColor.withOpacity(0),
          surfaceColor.withOpacity(0.8),
          surfaceColor.withOpacity(1.0),
          surfaceColor.withOpacity(1.0),
        ],
        stops: const [0.0, 0.5, 0.625, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TagRow(
          tags: widget.tags,
          lvLimit: widget.lvLimit,
          isLevelLimitVisible: isLevelLimitVisible,
          onToggleLevelLimit: () => setState(
            () => isLevelLimitVisible = !isLevelLimitVisible,
          ),
          areTagsExpanded: areTagsExpanded,
          onToggleTags: () => setState(() => areTagsExpanded = !areTagsExpanded),
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
}

/// The "简介" title row with tag chips.
///
/// Collapsed: title + as many chips as fit on one line, with the clipped
/// portion hidden behind a left-to-opaque surface gradient and a ">" chevron
/// pinned to the right content edge. Expanded: all chips wrap freely and a
/// "<" chevron follows the last chip.
class _TagRow extends StatefulWidget {
  final List<String> tags;
  final int lvLimit;
  final bool isLevelLimitVisible;
  final VoidCallback onToggleLevelLimit;
  final bool areTagsExpanded;
  final VoidCallback onToggleTags;

  const _TagRow({
    required this.tags,
    required this.lvLimit,
    required this.isLevelLimitVisible,
    required this.onToggleLevelLimit,
    required this.areTagsExpanded,
    required this.onToggleTags,
  });

  @override
  State<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends State<_TagRow> {
  /// Whether the collapsed tag row's content exceeds one line's width.
  bool _overflows = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme();
    final localizations = context.localizations();
    final chevronColor = colorScheme.onSurface.withOpacity(0.45);

    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          localizations.brief,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        if (widget.lvLimit > 0) ...[
          const SizedBox(width: 2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggleLevelLimit,
            child: const Icon(Icons.info_outline_rounded, size: 18),
          ),
        ],
      ],
    );

    final levelLimitMessage = widget.lvLimit > 0 && widget.isLevelLimitVisible
        ? Text(
            localizations.levelLimitMessage(widget.lvLimit),
            style: TextStyle(fontSize: 12, color: colorScheme.outline),
          )
        : null;

    if (widget.tags.isEmpty) {
      return Wrap(
        spacing: 6,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          titleRow,
          if (levelLimitMessage != null) levelLimitMessage,
        ],
      );
    }

    final chevron = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggleTags,
      child: Icon(
        widget.areTagsExpanded
            ? Icons.keyboard_arrow_left_rounded
            : Icons.keyboard_arrow_right_rounded,
        size: 20,
        color: chevronColor,
      ),
    );

    final chips = [
      for (final tag in widget.tags) _TagChip(tag: tag),
    ];

    // Chips separated by a fixed 6px gap for the single-line Rows below.
    final spacedChips = <Widget>[
      for (var i = 0; i < chips.length; i++) ...[
        chips[i],
        if (i != chips.length - 1) const SizedBox(width: 6),
      ],
    ];

    if (widget.areTagsExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              titleRow,
              if (levelLimitMessage != null) ...[
                const SizedBox(width: 6),
                levelLimitMessage,
              ],
              const Spacer(),
              chevron,
            ],
          ),
          const SizedBox(height: 8),
          // All tags re-flow onto as many lines as needed; chips are exactly
          // the same size as in the collapsed state.
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: chips,
          ),
        ],
      );
    }

    // Collapsed: clip to one line; chevron + gradient overlay on the right,
    // only when the content actually overflows.
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: SizedBox(
            width: constraints.maxWidth,
            height: 24,
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                // Hidden measurement pass: lay the full row out without width
                // limit and compare its intrinsic width against the available
                // width, reserving room for the chevron when it is shown.
                Offstage(
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: AfterLayout(
                      callback: (renderObject) {
                        final contentWidth = renderObject.size.width;
                        // Reserve chevron (20) + fade (12) when overflow would
                        // force the chevron to appear.
                        final available = constraints.maxWidth -
                            (_overflows ? 32 : 0);
                        final overflows = contentWidth > available;
                        if (overflows != _overflows) {
                          setState(() => _overflows = overflows);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          titleRow,
                          if (levelLimitMessage != null) ...[
                            const SizedBox(width: 6),
                            levelLimitMessage,
                          ],
                          const SizedBox(width: 6),
                          ...spacedChips,
                        ],
                      ),
                    ),
                  ),
                ),
                // Visible row, clipped at one line.
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          titleRow,
                          if (levelLimitMessage != null) ...[
                            const SizedBox(width: 6),
                            levelLimitMessage,
                          ],
                          const SizedBox(width: 6),
                          ...spacedChips,
                        ],
                      ),
                    ),
                  ),
                ),
                if (_overflows)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            colorScheme.surface.withOpacity(0),
                            colorScheme.surface,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.only(left: _kChevronFadeWidth),
                      child: chevron,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A compact gray rounded-rectangle chip. Its height matches the 17sp
/// "简介" title so the chip edges align with the title glyphs.
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme();
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        // Force the line box to 17px so the glyph is vertically centered in
        // the chip without an alignment (which would stretch the chip to fill
        // bounded width, e.g. inside a Wrap).
        strutStyle: const StrutStyle(
          fontSize: 12,
          height: 17 / 12,
          forceStrutHeight: true,
        ),
        style: context.textTheme().bodyLarge?.copyWith(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.45),
            ),
      ),
    );
  }
}
