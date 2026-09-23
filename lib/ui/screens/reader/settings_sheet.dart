import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/page_turn_mode.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/ui/screens/reader/reader_palette.dart';

class SettingsSheet extends StatefulWidget {
  final int fontSize;
  final void Function(int fontSize) onFontSizeChanged;
  final int backgroundColor;
  final void Function(int colorValue) onBackgroundColorChanged;
  final PageTurnMode pageTurnMode;
  final void Function(PageTurnMode mode) onPageTurnModeChanged;

  const SettingsSheet({
    super.key,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.backgroundColor,
    required this.onBackgroundColorChanged,
    required this.pageTurnMode,
    required this.onPageTurnModeChanged,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late int fontSize;
  late int backgroundColor;
  late PageTurnMode pageTurnMode;

  @override
  void initState() {
    super.initState();
    fontSize = widget.fontSize;
    backgroundColor = widget.backgroundColor;
    pageTurnMode = widget.pageTurnMode;
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
          Row(
            children: [
              for (final color in readerBackgroundColors)
                _buildColorDot(color),
            ],
          ),
          const SizedBox(height: 16),
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
}
