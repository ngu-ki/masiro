import 'package:flutter/material.dart';
import 'package:masiro/l10n/app_localizations.dart';

extension ContextUtils on BuildContext {
  AppLocalizations localizations() {
    return AppLocalizations.of(this)!;
  }

  ThemeData theme() {
    return Theme.of(this);
  }

  ColorScheme colorScheme() {
    return Theme.of(this).colorScheme;
  }

  /// Background color shared by the main bottom navigation bar, the novel
  /// detail bottom bar and the detail app bar in its scrolled state.
  Color navBarColor() {
    final theme = Theme.of(this);
    return theme.brightness == Brightness.light
        ? const Color(0xFFFAFAFA)
        : theme.colorScheme.surfaceContainer;
  }

  TextTheme textTheme() {
    return Theme.of(this).textTheme;
  }
}
