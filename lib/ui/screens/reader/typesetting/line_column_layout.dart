import 'typeset_models.dart';

/// One laid-out column: the unit at [index] occupies the horizontal
/// interval [xStart, xEnd) relative to the line origin, playing role
/// [kind].
class ColumnBox {
  final int index;
  final double xStart;
  final double xEnd;
  final GlyphColumnKind kind;

  const ColumnBox(this.index, this.xStart, this.xEnd, this.kind);

  @override
  String toString() => 'ColumnBox($index, [$xStart,$xEnd), $kind)';
}

/// Result of laying out a single line's columns.
class LineColumnResult {
  final List<ColumnBox> columns;

  /// X where body text (and the underline) starts. With a hung
  /// punctuation this is the hung mark's left edge.
  final double indentWidth;

  /// Extra width per justify gap (see [justifyViaSpaces]); 0 for natural
  /// lines.
  final double justifyGap;

  /// Whether [justifyGap] is applied to ASCII space units only.
  final bool justifyViaSpaces;

  const LineColumnResult(
    this.columns, {
    this.indentWidth = 0.0,
    this.justifyGap = 0.0,
    this.justifyViaSpaces = false,
  });
}

/// Whether a paragraph starts with indentation + an opening quote that
/// should hang into the indentation area. Ported from legado's
/// `HangingPunctuationRule`.
abstract final class HangingPunctuationRule {
  static const String hangingChars = '“‘「『﹁﹃"\'';

  static bool isHangingChar(String cluster) =>
      cluster.length == 1 && hangingChars.indexOf(cluster) >= 0;

  /// [words] are the paragraph units including the leading indent cells;
  /// [indentLength] is the number of indent cells.
  static bool shouldHang(List<String> words, int indentLength) {
    if (indentLength <= 0) return false;
    if (words.length <= indentLength) return false;
    if (!isHangingChar(words[indentLength])) return false;
    return !_isRightToLeft(words, indentLength + 1);
  }

  /// Whether the first strongly-directional unit after [start] is
  /// right-to-left. Neutral units (digits, punctuation, space) are
  /// skipped. Only the strong ranges actually reachable in this reader's
  /// content are handled; CJK ideographs and Latin are strong LTR.
  static bool _isRightToLeft(List<String> words, int start) {
    for (var i = start; i < words.length; i++) {
      final text = words[i];
      if (text.isEmpty) continue;
      final cu = text.codeUnitAt(0);
      final ltr = cu >= 0x41 && cu <= 0x5A || // A-Z
          cu >= 0x61 && cu <= 0x7A || // a-z
          cu >= 0x00C0 && cu <= 0x024F || // Latin extended
          cu >= 0x0370 && cu <= 0x03FF || // Greek
          cu >= 0x0400 && cu <= 0x04FF || // Cyrillic
          cu >= 0x4E00 && cu <= 0x9FFF || // CJK ideographs
          cu >= 0x3040 && cu <= 0x30FF || // Hiragana/Katakana
          cu >= 0xAC00 && cu <= 0xD7AF; // Hangul
      if (ltr) return false;
      final rtl = cu >= 0x0590 && cu <= 0x08FF || // Hebrew/Arabic blocks
          cu >= 0xFB1D && cu <= 0xFDFF ||
          cu >= 0xFE70 && cu <= 0xFEFF;
      if (rtl) return true;
    }
    return false;
  }
}

/// Pure floating-point column positioning ported from legado's
/// `LineColumnLayout`. No Flutter, no glyph objects — coordinates in,
/// coordinates out.
abstract final class LineColumnLayout {
  /// Width of a hung paragraph-start punctuation; 0 when nothing hangs.
  ///
  /// [indentLength] indent cells precede the candidate; under
  /// justification indent cells are laid out at [indentCharWidth], so the
  /// smaller of measured and laid-out indent width bounds the hang.
  static double hangingWidth({
    required List<double> widths,
    required int indentLength,
    required double indentCharWidth,
  }) {
    var indentWidth = 0.0;
    for (var i = 0; i < indentLength; i++) {
      indentWidth += widths[i];
    }
    indentWidth = _min(indentWidth, indentCharWidth * indentLength);
    final charWidth = widths[indentLength];
    return charWidth > 0 && charWidth <= indentWidth + 0.5 ? charWidth : 0.0;
  }

  /// Natural (ragged) placement: advances accumulate in order. When
  /// [hangingWidth] > 0, the first punctuation after the indent cells is
  /// placed inside the indentation area and the covered indent columns
  /// are clipped to avoid overlapping hit regions.
  static LineColumnResult natural({
    required List<double> widths,
    double startX = 0.0,
    bool hasIndent = false,
    int indentLength = 0,
    double hangingWidth = 0.0,
  }) {
    final hanging =
        hasIndent && hangingWidth > 0 && widths.length > indentLength;
    var hangingStart = double.infinity;
    if (hanging) {
      var indentEnd = startX;
      for (var i = 0; i < indentLength; i++) {
        indentEnd += widths[i];
      }
      // Natural placement uses measured widths; the hang width is the
      // candidate column's own width on this line.
      hangingStart = indentEnd - widths[indentLength];
    }
    final columns = <ColumnBox>[];
    var x = startX;
    var indentWidth = startX;
    for (var index = 0; index < widths.length; index++) {
      if (hanging && index == indentLength) {
        columns.add(ColumnBox(index, hangingStart, x,
            GlyphColumnKind.hanging));
        continue;
      }
      final x1 = x + widths[index];
      if (hasIndent && index < indentLength) {
        columns.add(ColumnBox(
            index, _min(x, hangingStart), _min(x1, hangingStart),
            GlyphColumnKind.indent));
      } else {
        columns.add(ColumnBox(index, x, x1, GlyphColumnKind.text));
      }
      x = x1;
      if (hasIndent && index == indentLength - 1) {
        indentWidth = hanging ? hangingStart : x;
      }
    }
    return LineColumnResult(columns, indentWidth: indentWidth);
  }

  /// Full justification without indentation: the residual width is
  /// distributed between non-trailing ASCII spaces when there are at
  /// least two of them, otherwise evenly between all inter-glyph gaps.
  static LineColumnResult justified({
    required List<String> words,
    required List<double> widths,
    required double visibleWidth,
    required double desiredWidth,
    double startX = 0.0,
  }) {
    final columns = <ColumnBox>[];
    final residualWidth = visibleWidth - desiredWidth;
    var spaceCount = 0;
    for (final w in words) {
      if (w == ' ') spaceCount++;
    }
    if (spaceCount > 1) {
      final d = residualWidth / spaceCount;
      var x = startX;
      for (var index = 0; index < words.length; index++) {
        final cw = widths[index];
        final x1 = (words[index] == ' ' && index != words.length - 1)
            ? x + cw + d
            : x + cw;
        columns.add(ColumnBox(index, x, x1, GlyphColumnKind.text));
        x = x1;
      }
      return LineColumnResult(columns,
          indentWidth: startX, justifyGap: d, justifyViaSpaces: true);
    } else {
      final gapCount = words.length - 1;
      final d = gapCount > 0 ? residualWidth / gapCount : 0.0;
      var x = startX;
      for (var index = 0; index < words.length; index++) {
        final cw = widths[index];
        final x1 =
            index != words.length - 1 ? x + cw + d : x + cw;
        columns.add(ColumnBox(index, x, x1, GlyphColumnKind.text));
        x = x1;
      }
      return LineColumnResult(columns,
          indentWidth: startX, justifyGap: d, justifyViaSpaces: false);
    }
  }

  /// Full justification of a paragraph's first line: indent cells are
  /// placed at fixed [indentCharWidth], an optional opening punctuation
  /// hangs into the indentation area, and the remaining body text is
  /// justified over [visibleWidth] with [hangingWidth] (0 when the mark
  /// does not hang) removed from its desired width.
  static LineColumnResult justifiedFirst({
    required List<String> words,
    required List<double> widths,
    required double visibleWidth,
    required double desiredWidth,
    required int indentLength,
    required double indentCharWidth,
    required double hangingWidth,
  }) {
    final columns = <ColumnBox>[];
    var indentEnd = 0.0;
    for (var i = 0; i < indentLength; i++) {
      indentEnd += indentCharWidth;
    }
    final hanging = hangingWidth > 0 && words.length > indentLength;
    final hangingStart =
        hanging ? indentEnd - hangingWidth : double.infinity;
    var x = 0.0;
    for (var index = 0; index < indentLength; index++) {
      final x1 = x + indentCharWidth;
      columns.add(ColumnBox(index, _min(x, hangingStart),
          _min(x1, hangingStart), GlyphColumnKind.indent));
      x = x1;
    }
    final indentWidth = hanging ? hangingStart : x;
    var wordStart = indentLength;
    if (hanging) {
      columns.add(ColumnBox(wordStart, hangingStart, x,
          GlyphColumnKind.hanging));
      wordStart++;
    }
    if (words.length <= wordStart) {
      return LineColumnResult(columns, indentWidth: indentWidth);
    }
    final body = justified(
      words: words.sublist(wordStart),
      widths: widths.sublist(wordStart),
      visibleWidth: visibleWidth,
      desiredWidth: desiredWidth - hangingWidth,
      startX: x,
    );
    for (final c in body.columns) {
      columns.add(ColumnBox(
          wordStart + c.index, c.xStart, c.xEnd, GlyphColumnKind.text));
    }
    return LineColumnResult(
      columns,
      indentWidth: indentWidth,
      justifyGap: body.justifyGap,
      justifyViaSpaces: body.justifyViaSpaces,
    );
  }

  static double _min(double a, double b) => a < b ? a : b;
}
