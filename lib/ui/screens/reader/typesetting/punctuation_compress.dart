import 'dart:math' as math;

import 'package:masiro/ui/screens/reader/typesetting/text_measure.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_models.dart';

/// Punctuation class for line-start/line-end prohibition rules.
enum PunctuationClass {
  /// Not a squeezable punctuation mark.
  none,

  /// Opening mark (前置标点): must not end a line.
  open,

  /// Closing mark (后置标点): must not start a line.
  close,
}

/// Which side(s) of the em box the trim is taken from.
enum TrimSide {
  /// Trim from the right; the glyph sits left.
  right,

  /// Trim from the left; the glyph sits right.
  left,

  /// Trim from both sides; the glyph stays centred.
  both,
}

/// Pure punctuation squeezing rules, a direct port of legado's
/// `PunctuationCompressRule` object: only character classification and
/// floating-point decisions, no Flutter dependency.
class PunctuationCompressRule {
  const PunctuationCompressRule._();

  /// Opening punctuation: 前置标点, forbidden at line end.
  static const String openChars = '“‘（〔［｛〈《「『【〖〝﹁﹃';

  /// Closing punctuation: 后置标点, forbidden at line start.
  static const String closeChars =
      '”’）〕］｝〉》」』】〗〞﹂﹄。，、；：！？．';

  /// Compression table: opening marks followed by closing marks.
  static final String chars = openChars + closeChars;

  /// Index in [chars], -1 when not a squeezable punctuation. Only a
  /// single UTF-16 unit cluster qualifies: a multi-unit cluster may have
  /// different metrics and must reuse nothing from the base-character
  /// cache.
  static int indexOfCluster(String cluster) {
    if (cluster.length != 1) return -1;
    return chars.indexOf(cluster);
  }

  static PunctuationClass classOf(int index) {
    if (index < 0) return PunctuationClass.none;
    if (index < openChars.length) return PunctuationClass.open;
    return PunctuationClass.close;
  }

  static PunctuationClass charClass(String cluster) =>
      classOf(indexOfCluster(cluster));

  /// Whether the current punctuation of [charClass] is squeezed given its
  /// neighbours. A closing mark squeezes whenever a punctuation follows;
  /// an opening mark squeezes after a closing mark or before another
  /// opening mark. Together adjacent marks give up roughly one em.
  static bool compressAdjacent(
    PunctuationClass charClass,
    PunctuationClass prevClass,
    PunctuationClass nextClass,
  ) {
    switch (charClass) {
      case PunctuationClass.close:
        return nextClass != PunctuationClass.none;
      case PunctuationClass.open:
        return prevClass == PunctuationClass.close ||
            nextClass == PunctuationClass.open;
      case PunctuationClass.none:
        return false;
    }
  }

  static TrimSide trimSide(double leftSpace, double rightSpace) {
    if (rightSpace >= leftSpace * 2) return TrimSide.right;
    if (leftSpace >= rightSpace * 2) return TrimSide.left;
    return TrimSide.both;
  }

  /// Width that can be trimmed off the advance box.
  ///
  /// Already-half-width or narrow punctuation is left untouched; the
  /// trim never exceeds half the advance (0.5em) and never exceeds the
  /// available blank space, so ink never collides with a neighbour.
  static double trimWidth(
    double width,
    double em,
    double leftSpace,
    double rightSpace,
  ) {
    if (width < em * 0.9) return 0;
    // Use 2.0 (not 2): int * double has static type num on Dart 3.7.
    final double space = switch (trimSide(leftSpace, rightSpace)) {
      TrimSide.right => rightSpace,
      TrimSide.left => leftSpace,
      TrimSide.both => 2.0 * math.min(leftSpace, rightSpace),
    };
    return math.min(width / 2, math.max(0.0, space));
  }

  /// Paint offset of the glyph after trimming; the column origin does not
  /// move, the glyph shifts into the trimmed blank side.
  static double drawOffset(TrimSide side, double trim) {
    if (trim <= 0) return 0;
    return switch (side) {
      TrimSide.left => -trim,
      TrimSide.both => -trim / 2,
      TrimSide.right => 0,
    };
  }
}

/// Glyph blank-space metrics for one punctuation mark.
typedef PunctuationInk = ({double leftSpace, double rightSpace});

/// Supplies the left/right blank space of a punctuation glyph inside its
/// advance box. Abstracted so the pure compression rules can be unit
/// tested with deterministic margins instead of font metrics.
abstract class PunctuationInkProvider {
  PunctuationInk sideSpaces(String char);
}

/// Default ink provider backed by [TextMeasure]'s tight glyph boxes.
class TextMeasureInk implements PunctuationInkProvider {
  TextMeasureInk(this.measure);

  final TextMeasure measure;

  @override
  PunctuationInk sideSpaces(String char) {
    final spaces = measure.inkSideSpaces(char);
    return (leftSpace: spaces.left, rightSpace: spaces.right);
  }
}

/// Per-paragraph punctuation compressor, port of legado's
/// `PunctuationCompressor`. One instance per paragraph; it mutates the
/// [GlyphUnit.width] values in place and records which units were
/// squeezed.
class PunctuationCompressor {
  PunctuationCompressor({
    required TextMeasure measure,
    PunctuationInkProvider? ink,
  })  : _measure = measure,
        _ink = ink ?? TextMeasureInk(measure);

  final TextMeasure _measure;
  final PunctuationInkProvider _ink;

  /// Trim amounts smaller than this are not worth applying; also used to
  /// decide whether a column is already compressed.
  static const double minTrim = 0.5;

  late final List<double> _trims =
      List.filled(PunctuationCompressRule.chars.length, 0);
  late final List<TrimSide> _sides =
      List.filled(PunctuationCompressRule.chars.length, TrimSide.right);
  late final List<bool> _measured =
      List.filled(PunctuationCompressRule.chars.length, false);

  /// Identity set of units already squeezed in the current paragraph; a
  /// unit is compressed at most once.
  final Set<GlyphUnit> _compressed = <GlyphUnit>{};

  /// Begins a paragraph: applies line-position-independent adjacent
  /// punctuation compression to [units]. Compressed widths are used by
  /// both line breaking and later column layout.
  void beginParagraph(List<GlyphUnit> units) {
    _compressed.clear();
    for (var i = 0; i < units.length; i++) {
      final charClass = PunctuationCompressRule.charClass(units[i].text);
      if (charClass == PunctuationClass.none) continue;
      final prevClass = i > 0
          ? PunctuationCompressRule.charClass(units[i - 1].text)
          : PunctuationClass.none;
      final nextClass = i + 1 < units.length
          ? PunctuationCompressRule.charClass(units[i + 1].text)
          : PunctuationClass.none;
      if (PunctuationCompressRule.compressAdjacent(
          charClass, prevClass, nextClass)) {
        _compress(units[i]);
      }
    }
  }

  /// Squeezes the single trailing closing punctuation of a non-final
  /// line (called after line breaking). A paragraph's last line is never
  /// squeezed, so its ragged right edge stays intentional.
  ///
  /// Returns whether a unit was compressed.
  bool compressLineEnd(
    List<GlyphUnit> lineUnits, {
    required bool isParagraphLast,
  }) {
    if (isParagraphLast) return false;
    for (var i = lineUnits.length - 1; i >= 0; i--) {
      final unit = lineUnits[i];
      // Trailing spaces do not count; keep walking back to the last
      // visible unit.
      if (unit.text.trim().isEmpty) continue;
      final index = PunctuationCompressRule.indexOfCluster(unit.text);
      if (PunctuationCompressRule.classOf(index) !=
          PunctuationClass.close) {
        return false;
      }
      _measureChar(index);
      if (_trims[index] <= minTrim) return false;
      // Already squeezed inside the paragraph: do not squeeze twice.
      if (_compressed.contains(unit)) return false;
      _applyTrim(unit, index);
      return true;
    }
    return false;
  }

  void _compress(GlyphUnit unit) {
    final index = PunctuationCompressRule.indexOfCluster(unit.text);
    if (index < 0) return;
    _measureChar(index);
    if (_trims[index] <= minTrim) return;
    if (_compressed.contains(unit)) return;
    _applyTrim(unit, index);
  }

  void _applyTrim(GlyphUnit unit, int index) {
    unit.width -= _trims[index];
    unit.drawOffset =
        PunctuationCompressRule.drawOffset(_sides[index], _trims[index]);
    unit.compressed = true;
    _compressed.add(unit);
  }

  void _measureChar(int index) {
    if (_measured[index]) return;
    _measured[index] = true;
    final char = PunctuationCompressRule.chars[index];
    final em = _measure.cjkCharWidth;
    final width = _measure.measureCluster(char);
    final ink = _ink.sideSpaces(char);
    _sides[index] =
        PunctuationCompressRule.trimSide(ink.leftSpace, ink.rightSpace);
    _trims[index] = PunctuationCompressRule.trimWidth(
      width,
      em,
      ink.leftSpace,
      ink.rightSpace,
    );
  }
}
