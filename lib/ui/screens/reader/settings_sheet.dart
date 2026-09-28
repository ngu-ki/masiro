import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/indent_mode.dart';
import 'package:masiro/data/repository/model/page_turn_mode.dart';
import 'package:masiro/data/repository/model/text_color_mode.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/ui/screens/reader/reader_palette.dart';

class SettingsSheet extends StatefulWidget {
  final int fontSize;
  final void Function(int fontSize) onFontSizeChanged;
  final int backgroundColor;
  final void Function(int colorValue) onBackgroundColorChanged;
  final PageTurnMode pageTurnMode;
  final void Function(PageTurnMode mode) onPageTurnModeChanged;
  final IndentMode indentMode;
  final void Function(IndentMode mode) onIndentModeChanged;
  final TextColorMode textColorMode;
  final void Function(TextColorMode mode) onTextColorModeChanged;
  final bool shrinkEmptyLines;
  final void Function(bool enabled) onShrinkEmptyLinesChanged;
  final bool forceSimplified;
  final void Function(bool enabled) onForceSimplifiedChanged;

  const SettingsSheet({
    super.key,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.backgroundColor,
    required this.onBackgroundColorChanged,
    required this.pageTurnMode,
    required this.onPageTurnModeChanged,
    required this.indentMode,
    required this.onIndentModeChanged,
    required this.textColorMode,
    required this.onTextColorModeChanged,
    required this.shrinkEmptyLines,
    required this.onShrinkEmptyLinesChanged,
    required this.forceSimplified,
    required this.onForceSimplifiedChanged,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late int fontSize;
  late int backgroundColor;
  late PageTurnMode pageTurnMode;
  late IndentMode indentMode;
  late TextColorMode textColorMode;
  late bool shrinkEmptyLines;
  late bool forceSimplified;

  @override
  void initState() {
    super.initState();
    fontSize = widget.fontSize;
    backgroundColor = widget.backgroundColor;
    pageTurnMode = widget.pageTurnMode;
    indentMode = widget.indentMode;
    textColorMode = widget.textColorMode;
    shrinkEmptyLines = widget.shrinkEmptyLines;
    forceSimplified = widget.forceSimplified;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: [
              Text(localizations.fontSize),
              Expanded(
                child: Slider(
                  value: fontSize.toDouble(),
                  min: 12,
                  max: 32,
                  divisions: 20,
                  label: fontSize.toString(),
                  onChanged: (value) {
                    setState(() => fontSize = value.toInt());
                    widget.onFontSizeChanged(value.toInt());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(localizations.backgroundColor),
          const SizedBox(height: 8),
          // Wrap instead of a fixed Row: with eight color dots the row can
          // exceed the available width on narrow phones.
          Wrap(
            runSpacing: 8,
            children: [
              for (final color in readerBackgroundColors)
                _buildColorDot(color),
            ],
          ),
          const SizedBox(height: 16),
          // The page-turn chips keep the left side; the two text toggles
          // ("force simplified" and "shrink empty lines") sit on the right,
          // with the label on top and the switch directly below it. Two
          // equal spacers put the "force simplified" switch exactly midway
          // between the page-turn chips and the "shrink empty lines" switch.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizations.pageTurnMode),
                  const SizedBox(height: 8),
                  // Fixed width: this column sits in a Row with spacers, so
                  // its width is unbounded and the segmented control would
                  // otherwise not know how wide to be.
                  SizedBox(
                    width: 168,
                    child: _buildSegmentedControl<PageTurnMode>(
                      options: [
                        (localizations.pageTurnSlide, PageTurnMode.slide),
                        (localizations.pageTurnNone, PageTurnMode.none),
                      ],
                      selected: pageTurnMode,
                      onSelected: (mode) {
                        setState(() => pageTurnMode = mode);
                        widget.onPageTurnModeChanged(mode);
                      },
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildSwitchColumn(
                label: localizations.forceSimplified,
                value: forceSimplified,
                onChanged: (enabled) {
                  setState(() => forceSimplified = enabled);
                  widget.onForceSimplifiedChanged(enabled);
                },
              ),
              const Spacer(),
              _buildSwitchColumn(
                label: localizations.shrinkEmptyLines,
                value: shrinkEmptyLines,
                onChanged: (enabled) {
                  setState(() => shrinkEmptyLines = enabled);
                  widget.onShrinkEmptyLinesChanged(enabled);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(localizations.indentMode),
          const SizedBox(height: 8),
          _buildSegmentedControl<IndentMode>(
            options: [
              (localizations.indentNone, IndentMode.none),
              (localizations.indentOne, IndentMode.one),
              (localizations.indentTwo, IndentMode.two),
              (localizations.indentAdaptive, IndentMode.adaptive),
            ],
            selected: indentMode,
            onSelected: (mode) {
              setState(() => indentMode = mode);
              widget.onIndentModeChanged(mode);
            },
          ),
          const SizedBox(height: 16),
          Text(localizations.textColorMode),
          const SizedBox(height: 8),
          _buildSegmentedControl<TextColorMode>(
            options: [
              (localizations.textColorOriginal, TextColorMode.original),
              (localizations.textColorSimplified, TextColorMode.simplified),
              (localizations.textColorUniform, TextColorMode.uniform),
            ],
            selected: textColorMode,
            onSelected: (mode) {
              setState(() => textColorMode = mode);
              widget.onTextColorModeChanged(mode);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = backgroundColor == color.value;
    return GestureDetector(
      onTap: () {
        setState(() => backgroundColor = color.value);
        widget.onBackgroundColorChanged(color.value);
      },
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            width: isSelected ? 2.5 : 1,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.5),
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check_rounded,
                size: 16,
                color: readerContentColor(color),
              )
            : null,
      ),
    );
  }

  /// A compact column with the setting [label] on top and its switch
  /// directly below. Two such columns placed next to each other keep their
  /// labels and switches horizontally aligned. The switch is centered in a
  /// fixed-height box matching the segmented control height (40), so its
  /// horizontal centerline aligns with the page-turn control on the left.
  Widget _buildSwitchColumn({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: Center(
            child: Switch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// A segmented control styled after the tomato-novel reader settings: a
  /// gray rounded bar holding all [options], with the selected option
  /// rendered as a white pill with bold text.
  Widget _buildSegmentedControl<T>({
    required List<(String, T)> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final (label, value) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(value),
                child: Container(
                  alignment: Alignment.center,
                  decoration: value == selected
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        )
                      : null,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: value == selected
                          ? FontWeight.bold
                          : FontWeight.normal,
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
