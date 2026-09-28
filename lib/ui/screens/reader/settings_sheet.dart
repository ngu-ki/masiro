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
          // ("force simplified" and "shrink empty lines") sit on the right
          // of the page-turn title, with the label on top and the switch
          // directly below it, the two columns aligned with each other.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.pageTurnMode),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildModeChip(
                          localizations.pageTurnSlide,
                          PageTurnMode.slide,
                        ),
                        _buildModeChip(
                          localizations.pageTurnNone,
                          PageTurnMode.none,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildSwitchColumn(
                label: localizations.forceSimplified,
                value: forceSimplified,
                onChanged: (enabled) {
                  setState(() => forceSimplified = enabled);
                  widget.onForceSimplifiedChanged(enabled);
                },
              ),
              const SizedBox(width: 8),
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
          Wrap(
            spacing: 8,
            children: [
              _buildIndentChip(
                localizations.indentNone,
                IndentMode.none,
              ),
              _buildIndentChip(
                localizations.indentOne,
                IndentMode.one,
              ),
              _buildIndentChip(
                localizations.indentTwo,
                IndentMode.two,
              ),
              _buildIndentChip(
                localizations.indentAdaptive,
                IndentMode.adaptive,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(localizations.textColorMode),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTextColorChip(
                localizations.textColorOriginal,
                TextColorMode.original,
              ),
              _buildTextColorChip(
                localizations.textColorSimplified,
                TextColorMode.simplified,
              ),
              _buildTextColorChip(
                localizations.textColorUniform,
                TextColorMode.uniform,
              ),
            ],
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
  /// labels and switches horizontally aligned.
  Widget _buildSwitchColumn({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildModeChip(String label, PageTurnMode mode) {
    final isSelected = pageTurnMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (!selected) {
          return;
        }
        setState(() => pageTurnMode = mode);
        widget.onPageTurnModeChanged(mode);
      },
    );
  }

  Widget _buildIndentChip(String label, IndentMode mode) {
    final isSelected = indentMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (!selected) {
          return;
        }
        setState(() => indentMode = mode);
        widget.onIndentModeChanged(mode);
      },
    );
  }

  Widget _buildTextColorChip(String label, TextColorMode mode) {
    final isSelected = textColorMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (!selected) {
          return;
        }
        setState(() => textColorMode = mode);
        widget.onTextColorModeChanged(mode);
      },
    );
  }
}
