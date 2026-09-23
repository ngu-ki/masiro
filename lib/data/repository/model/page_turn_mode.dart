/// Page turn modes of the reader.
enum PageTurnMode {
  /// Simulated page curl animation, like a physical book.
  simulation,

  /// Horizontal sliding animation.
  slide,

  /// Vertical scrolling, the classic continuous reading mode.
  vertical,

  /// Instant page switching without any animation.
  none;

  bool isVertical() {
    return this == PageTurnMode.vertical;
  }

  bool isSimulation() {
    return this == PageTurnMode.simulation;
  }

  bool isPageBased() {
    return this != PageTurnMode.vertical;
  }

  bool hasTapToTurn() {
    return isPageBased();
  }
}

PageTurnMode pageTurnModeFromName(String name) {
  for (final mode in PageTurnMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return PageTurnMode.vertical;
}
