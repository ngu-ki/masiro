/// First-line indentation modes of the reader.
///
/// The setting is stored independently for each novel because some books
/// already have indentation in their source content while others do not.
enum IndentMode {
  /// No extra indentation.
  none,

  /// Indent by one full-width character.
  one,

  /// Indent by two full-width characters.
  two,
}

IndentMode indentModeFromName(String name) {
  for (final mode in IndentMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return IndentMode.none;
}

extension IndentModeExtension on IndentMode {
  /// The text prefix used to render the indentation.
  ///
  /// A full-width space takes up exactly one Chinese character cell, so the
  /// length of the prefix matches the number of indented characters.
  String get prefix => '　' * index;
}
