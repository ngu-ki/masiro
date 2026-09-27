/// Text color display modes of the reader.
///
/// The setting is stored independently for each novel, alongside the other
/// typesetting preferences.
enum TextColorMode {
  /// Keep the colors declared by the source text (inline `color` styles and
  /// `<font color>` tags). Colors are rendered verbatim even on dark
  /// backgrounds, matching the source page.
  original,

  /// Source-colored text is rendered in a muted gray instead of its actual
  /// color. This is the default mode.
  simplified,

  /// Ignore every source color and use the adaptive body color: near-black
  /// on light backgrounds and light gray on dark backgrounds.
  uniform,
}

TextColorMode textColorModeFromName(String name) {
  for (final mode in TextColorMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return TextColorMode.simplified;
}
