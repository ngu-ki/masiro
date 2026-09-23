/// Page turn modes of the reader.
enum PageTurnMode {
  /// Horizontal sliding animation.
  slide,

  /// Instant page switching without any animation.
  none,
}

PageTurnMode pageTurnModeFromName(String name) {
  for (final mode in PageTurnMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return PageTurnMode.slide;
}
