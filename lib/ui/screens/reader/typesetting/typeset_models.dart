import 'package:masiro/data/repository/model/chapter_detail.dart';

/// Role of a glyph column inside a line, mirroring legado's
/// `LineColumnLayout.kindIndent / kindHanging / kindText`.
enum GlyphColumnKind {
  /// A fixed-width indentation cell at the start of a paragraph.
  indent,

  /// An opening punctuation hung into the indentation area.
  hanging,

  /// Ordinary body text.
  text,
}

/// One typesetting unit: a single grapheme cluster (possibly with merged
/// zero-width marks) plus the geometry shared by every pipeline stage.
///
/// The same instance flows through measurement -> punctuation compression
/// -> line breaking -> column positioning -> painting, so the coordinates
/// used to paint are exactly the coordinates produced by measurement.
/// This is the key invariant that previous attempts (WidgetSpan indentation
/// with a separate measurement tree) violated.
class GlyphUnit {
  /// The visible cluster text. Zero-width marks merged into a neighbour are
  /// appended/prepended to that neighbour's text, so source offset coverage
  /// stays contiguous.
  String text;

  /// Index of the source [ChapterContentElement] this unit belongs to.
  final int elementIndex;

  /// Inclusive start offset (UTF-16 code units) within the element text.
  int charStart;

  /// Exclusive end offset (UTF-16 code units) within the element text.
  int charEnd;

  /// Advance width of the unit, in logical pixels. Punctuation compression
  /// mutates this in place; every later stage reads the compressed value.
  double width;

  /// Intra-column paint shift applied after compression (negative shifts
  /// the glyph left). Zero for ordinary units and for right-side trims.
  double drawOffset;

  /// Whether punctuation compression narrowed this unit's advance. A
  /// right-side trim leaves [drawOffset] at zero, so this flag — not the
  /// offset — is the reliable marker for the per-glyph paint path.
  bool compressed;

  /// Column role assigned by the line column layout stage.
  GlyphColumnKind kind;

  /// Column start/end x relative to the line origin, assigned by the line
  /// column layout stage.
  double xStart;
  double xEnd;

  GlyphUnit({
    required this.text,
    required this.elementIndex,
    required this.charStart,
    required this.charEnd,
    required this.width,
    this.drawOffset = 0.0,
    this.compressed = false,
    this.kind = GlyphColumnKind.text,
    this.xStart = 0.0,
    this.xEnd = 0.0,
  });

  /// Appends a trailing zero-width cluster (its advance is zero, so the
  /// width is unchanged).
  void appendZeroWidth(String cluster, int end) {
    text = '$text$cluster';
    charEnd = end;
  }

  /// Prepends a leading zero-width cluster before the first visible cluster
  /// of a paragraph (its advance is zero, so the width is unchanged).
  void prependZeroWidth(String cluster, int start) {
    text = '$cluster$text';
    charStart = start;
  }

  @override
  String toString() => 'GlyphUnit($text @$elementIndex[$charStart,$charEnd) '
      'w=$width x=[$xStart,$xEnd] k=$kind)';
}

/// A block placed on a typeset page: either a laid-out text line or a
/// collapsed blank-line gap.
sealed class TypesetBlock {
  /// Enables const constructors in subclasses (on Dart 3.7 a sealed
  /// class's implicit constructor is not const).
  const TypesetBlock();

  /// Occupied height in logical pixels.
  double get height;

  /// Source element index this block belongs to.
  int get elementIndex;
}

/// A fully positioned line ready to paint.
class TypesetLine extends TypesetBlock {
  @override
  final int elementIndex;

  /// Positioned glyph units, in visual order.
  final List<GlyphUnit> glyphs;

  @override
  final double height;

  /// Extra paragraph spacing reserved above this line. Non-zero only for
  /// the first line of an element when the page already has content.
  final double topGap;

  /// Whether this is the first line of its paragraph (indentation and
  /// hanging apply to it).
  final bool isParagraphFirst;

  /// Whether this is the last line of its paragraph; such lines keep
  /// natural (ragged-right) alignment instead of being justified.
  final bool isParagraphLast;

  /// Sum of the (compressed) glyph advances before justification.
  final double naturalWidth;

  /// Extra width distributed to each inter-glyph gap (or to ASCII spaces,
  /// see [justifyViaSpaces]) for full justification; zero for natural
  /// lines.
  final double justifyGap;

  /// When true, [justifyGap] is added to ASCII space units only; otherwise
  /// it is added to every inter-glyph gap except after the final unit.
  final bool justifyViaSpaces;

  /// Whether legado's `exceed()` redistribution shifted the columns
  /// leftwards to keep a CPS-tolerated line inside the visible width.
  final bool isExceeded;

  const TypesetLine({
    required this.elementIndex,
    required this.glyphs,
    required this.height,
    this.topGap = 0.0,
    this.isParagraphFirst = false,
    this.isParagraphLast = false,
    this.naturalWidth = 0.0,
    this.justifyGap = 0.0,
    this.justifyViaSpaces = false,
    this.isExceeded = false,
  });

  int get startChar => glyphs.first.charStart;

  int get endChar => glyphs.last.charEnd;

  bool get hasHanging =>
      glyphs.any((g) => g.kind == GlyphColumnKind.hanging);

  /// Whether any glyph was narrowed by punctuation compression; such lines
  /// cannot use the uniform-letter-spacing fast paint path.
  bool get isCompressed => glyphs.any((g) => g.compressed);

  /// Whether the line needs the per-glyph paint path instead of one
  /// uniform TextPainter: compressed glyphs, a hung punctuation, or
  /// non-uniform shifts from exceed() redistribution.
  bool get hasIrregularGlyphs =>
      isCompressed || hasHanging || isExceeded;
}

/// A blank paragraph collapsed to a small gap.
class TypesetBlankGap extends TypesetBlock {
  @override
  final int elementIndex;

  @override
  final double height;

  const TypesetBlankGap({required this.elementIndex, required this.height});
}

/// One typeset page: either a list of blocks or a full-page image.
class TypesetPage {
  final List<TypesetBlock> blocks;

  /// Element index of the image when this page is a full-page image.
  final int? imageElementIndex;

  final ImageContent? image;

  const TypesetPage({
    this.blocks = const [],
    this.imageElementIndex,
    this.image,
  });

  bool isImagePage() => image != null;

  /// The first text line on this page, ignoring blank gaps.
  TypesetLine? get firstLine {
    for (final block in blocks) {
      if (block is TypesetLine) {
        return block;
      }
    }
    return null;
  }

  /// The last text line on this page, ignoring blank gaps.
  TypesetLine? get lastLine {
    for (var i = blocks.length - 1; i >= 0; i--) {
      final block = blocks[i];
      if (block is TypesetLine) {
        return block;
      }
    }
    return null;
  }

  /// Element index of the last piece of content on this page.
  int get lastElementIndex {
    if (isImagePage()) {
      return imageElementIndex!;
    }
    return blocks.last.elementIndex;
  }
}
