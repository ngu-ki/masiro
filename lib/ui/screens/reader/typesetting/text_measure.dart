import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_models.dart';

/// Code points with no ink and no advance that must never form a unit of
/// their own: they merge into the neighbouring unit (U+200D ZWJ inside an
/// emoji sequence is already glued by grapheme cluster segmentation, but
/// U+200B/U+200C/U+2060 create boundaries and therefore need an explicit
/// merge, matching legado's `measureTextSplit` zero-width handling).
const Set<int> zeroWidthCodePoints = {
  0x200B, // zero width space
  0x200C, // zero width non-joiner
  0x200D, // zero width joiner
  0x2060, // word joiner
  0xFEFF, // zero width no-break space
};

/// Per-cluster advance-width measurement for a fixed text style.
///
/// Port of legado's `TextMeasure` strategy:
/// - text is split into grapheme clusters (emoji ZWJ sequences and
///   combining marks stay intact);
/// - common CJK ideographs (U+4E00–U+9FA5) share the measured width of
///   `一`, so a 3000-glyph chapter needs only a handful of real paints;
/// - other widths are cached per font configuration.
///
/// Widths are raw logical-pixel doubles (no rounding): the column layout
/// sums them sub-pixel exactly, mirroring legado's `getTextWidths` path.
class TextMeasure {
  TextMeasure(this.style);

  final TextStyle style;

  late final TextPainter _painter = TextPainter(textDirection: TextDirection.ltr);

  /// Number of measurements served without painting during this
  /// instance's lifetime (observable for tests/performance checks).
  int cacheHits = 0;

  String get _fontKey => [
        style.fontFamily,
        style.fontSize,
        style.fontWeight?.index,
        style.fontStyle?.index,
        style.fontFamilyFallback?.join(','),
      ].join('|');

  /// Advance width shared by common CJK ideographs for [style].
  double get cjkCharWidth =>
      _cjkCommonWidths.putIfAbsent(_fontKey, () => _paintWidth('一'));

  /// Advance width of one full-width ideographic space, the unit used for
  /// fixed indentation columns.
  double get indentCharWidth =>
      _indentWidths.putIfAbsent(_fontKey, () => _paintWidth('\u3000'));

  /// Measures the advance width of one grapheme [cluster].
  double measureCluster(String cluster) {
    final key = '$_fontKey|$cluster';
    final cached = _clusterWidths[key];
    if (cached != null) {
      cacheHits++;
      return cached;
    }
    final runes = cluster.runes;
    if (runes.length == 1) {
      final codePoint = runes.first;
      // 中文 Unicode 范围 U+4E00 - U+9FA5: every common ideograph shares
      // the width of 一 in the same font.
      if (codePoint >= 0x4E00 && codePoint <= 0x9FA5) {
        final width = cjkCharWidth;
        _clusterWidths[key] = width;
        cacheHits++;
        return width;
      }
    }
    final width = _paintWidth(cluster);
    _clusterWidths[key] = width;
    return width;
  }

  /// Splits [text] into measured glyph units.
  ///
  /// [elementIndex] tags every unit with its source element; offsets are
  /// UTF-16 code units within [text], matching the offsets used by
  /// `coloredRanges` and read positions.
  List<GlyphUnit> measureUnits({
    required String text,
    required int elementIndex,
  }) {
    final units = <GlyphUnit>[];

    // Zero-width clusters before the first visible unit wait and are
    // prepended to it.
    var leadingText = '';
    int? leadingStart;
    var offset = 0;
    for (final cluster in text.characters) {
      final start = offset;
      final end = start + cluster.length;
      offset = end;
      if (isZeroWidthCluster(cluster)) {
        if (units.isNotEmpty) {
          units.last.appendZeroWidth(cluster, end);
        } else {
          leadingText = '$leadingText$cluster';
          leadingStart ??= start;
        }
        continue;
      }
      final unit = GlyphUnit(
        text: cluster,
        elementIndex: elementIndex,
        charStart: start,
        charEnd: end,
        width: measureCluster(cluster),
      );
      if (leadingText.isNotEmpty) {
        unit.prependZeroWidth(leadingText, leadingStart!);
        leadingText = '';
        leadingStart = null;
      }
      units.add(unit);
    }
    return units;
  }

  /// Measures the blank portions on either side of the glyph ink inside
  /// the advance box of [cluster]. Used to decide how much adjacent
  /// punctuation can be squeezed without moving ink over a neighbour.
  ({double left, double right}) inkSideSpaces(String cluster) {
    final key = '$_fontKey>$cluster';
    final cached = _inkSpaces[key];
    if (cached != null) {
      cacheHits++;
      return cached;
    }
    _painter.text = TextSpan(text: cluster, style: style);
    _painter.layout();
    // TextPainter only exposes the tight-box query via selections on
    // Flutter 3.29; getBoxesForRange was added on a later stable.
    final boxes = _painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: cluster.length),
      boxHeightStyle: ui.BoxHeightStyle.tight,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );
    final result = boxes.isEmpty
        ? (left: 0.0, right: 0.0)
        : (
            left: math.max(0.0, boxes.first.left),
            right: math.max(0.0, _painter.width - boxes.first.right),
          );
    _inkSpaces[key] = result;
    return result;
  }

  double _paintWidth(String cluster) {
    _painter.text = TextSpan(text: cluster, style: style);
    _painter.layout();
    return _painter.width;
  }

  void dispose() {
    _painter.dispose();
  }

  static bool isZeroWidthCluster(String cluster) {
    for (final codePoint in cluster.runes) {
      if (!zeroWidthCodePoints.contains(codePoint)) {
        return false;
      }
    }
    return true;
  }

  // Shared across chapters: font signature + cluster text uniquely
  // identify a width, so repeat chapters and page re-layouts paint nothing.
  static final Map<String, double> _clusterWidths = {};
  static final Map<String, double> _cjkCommonWidths = {};
  static final Map<String, double> _indentWidths = {};
  static final Map<String, ({double left, double right})> _inkSpaces = {};
}
