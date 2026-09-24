import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/bloc/global/app_theme_cubit.dart';
import 'package:masiro/misc/constant.dart';
import 'package:masiro/misc/context.dart';

class ThemeColorCard extends StatelessWidget {
  const ThemeColorCard({super.key});

  /// Opens the theme color picker dialog. Can be called from anywhere with
  /// an [AppThemeCubit] in the widget tree.
  static void showColorPickerDialog(BuildContext context) {
    final cubit = context.read<AppThemeCubit>();
    final themeColor = cubit.state.themeColor;
    showDialog(
      context: context,
      builder: (context) {
        return _ThemeColorDialog(
          themeColor: themeColor,
          onThemeColorChanged: (color) => cubit.setThemeColor(color),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();

    return BlocBuilder<AppThemeCubit, AppThemeData>(
      buildWhen: (prev, curr) => prev.themeColor != curr.themeColor,
      builder: (context, state) {
        final themeColor = state.themeColor;
        return Card(
          clipBehavior: Clip.hardEdge,
          child: ListTile(
            leading: const Icon(Icons.palette_rounded),
            title: Text(localizations.themeColor),
            onTap: () => showColorPickerDialog(context),
          ),
        );
      },
    );
  }
}

class _ThemeColorDialog extends StatefulWidget {
  final int themeColor;
  final void Function(int) onThemeColorChanged;

  const _ThemeColorDialog({
    required this.themeColor,
    required this.onThemeColorChanged,
  });

  @override
  State<_ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<_ThemeColorDialog> {
  late Color pickerColor;

  @override
  void initState() {
    super.initState();
    pickerColor = Color(widget.themeColor);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations();

    return AlertDialog(
      title: Text(localizations.themeColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      content: SizedBox(
        width: 300,
        child: ColorPicker(
          color: pickerColor,
          padding: const EdgeInsets.only(top: 16),
          enableShadesSelection: false,
          mainAxisSize: MainAxisSize.min,
          pickersEnabled: const <ColorPickerType, bool>{
            ColorPickerType.primary: true,
            ColorPickerType.accent: false,
            ColorPickerType.wheel: true,
          },
          pickerTypeLabels: {
            ColorPickerType.primary: localizations.primaryColor,
            ColorPickerType.wheel: localizations.wheelColor,
          },
          onColorChanged: (color) {
            setState(() => pickerColor = color);
            widget.onThemeColorChanged(color.value);
          },
        ),
      ),
      actions: [
        TextButton(
          child: Text(localizations.reset),
          onPressed: () {
            widget.onThemeColorChanged(defaultThemeColor);
            context.pop();
          },
        ),
        TextButton(
          child: Text(localizations.close),
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}
