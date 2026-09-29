import 'package:masiro/data/repository/model/chapter_detail.dart';
import 'package:masiro/data/repository/model/read_position.dart';
import 'package:masiro/ui/screens/reader/typesetting/line_column_layout.dart';
import 'package:masiro/ui/screens/reader/typesetting/punctuation_compress.dart';
import 'package:masiro/ui/screens/reader/typesetting/text_measure.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_models.dart';
import 'package:masiro/ui/screens/reader/typesetting/zh_layout.dart';

/// Whether [text] consists solely of white space, including no-break
/// spaces (`&nbsp;`) and full-width spaces used by some sources.
bool isTypesetBlankText(String text) => text
    .replaceAll('\u00A0', '')
    .replaceAll('\u3000', '')
    .trim()
    .isEmpty;

/// Measures paragraphs and applies paragraph-level / line-end
/// punctuation compression. Abstracted so [ChapterTypesetter] can be
/// unit-tested with deterministic unit widths instead of font metrics.
abstract class ChapterTextEngine {
  /// Advance width of one standard CJK ideograph.
  double get emWidth;

  /// Advance width of one full-width ideographic space; fixed indent
  /// columns are laid out at this width.
  double get indentCharWidth;

  /// Builds the measured unit list of one paragraph segment:
  /// [indentCells] synthetic indent units (zero source coverage)
  /// followed by the measured body units of [text], with adjacent
  /// punctuation already compressed. [charOffset] is the segment's
  /// start offset inside its source element. An element split on '\n'
  /// becomes several segments; only the first carries indentation.
  List<GlyphUnit> buildParagraphUnits({
    required String text,
    required int elementIndex,
    required int indentCells,
    int charOffset = 0,
  });

  /// Squeezes the trailing closing punctuation of a non-final line.
  /// Returns whether a unit was compressed.
  bool compressLineEnd(
    List<GlyphUnit> lineUnits, {
    required bool isParagraphLast,
  });
}

/// Production engine backed by [TextMeasure] and [PunctuationCompressor].
class TextMeasureTypesetEngine implements ChapterTextEngine {
  TextMeasureTypesetEngine(this._measure)
      : _compressor = PunctuationCompressor(measure: _measure);

  final TextMeasure _measure;
  final PunctuationCompressor _compressor;

  @override
  double get emWidth => _measure.cjkCharWidth;

  @override
  double get indentCharWidth => _measure.indentCharWidth;

  @override
  List<GlyphUnit> buildParagraphUnits({
    required String text,
    required int elementIndex,
    required int indentCells,
    int charOffset = 0,
  }) {
    final body = _measure.measureUnits(text: text, elementIndex: elementIndex);
    if (charOffset != 0) {
      for (final unit in body) {
        unit
          ..charStart += charOffset
          ..charEnd += charOffset;
      }
    }
    final units = <GlyphUnit>[
      for (var i = 0; i < indentCells; i++)
        // Indent cells are synthetic: they occupy columns but cover no
        // source characters, so read positions and colored ranges keep
        // using offsets inside the original text.
        GlyphUnit(
          text: '　',
          elementIndex: elementIndex,
          charStart: 0,
          charEnd: 0,
          width: _measure.indentCharWidth,
          kind: GlyphColumnKind.indent,
        ),
      ...body,
    ];
    // Full-width spaces are not squeezable punctuation, so including the
    // indent cells is harmless and keeps the body's first-punctuation
    // context identical to legado's `paragraphIndent + text`.
    _compressor.beginParagraph(units);
    return units;
  }

  @override
  bool compressLineEnd(
    List<GlyphUnit> lineUnits, {
    required bool isParagraphLast,
  }) {
    return _compressor.compressLineEnd(
      lineUnits,
      isParagraphLast: isParagraphLast,
    );
  }
}

/// Orchestrates measurement -> punctuation compression -> kinsoku line
/// breaking -> column positioning -> page packing, ported from legado's
/// `TextChapterLayout` per-paragraph loop. All geometry produced here is
/// painted verbatim (the measure-equals-paint invariant).
class ChapterTypesetter {
  ChapterTypesetter({
    required this.engine,
    required this.indentCells,
    required this.maxWidth,
    required this.maxHeight,
    required this.lineHeight,
    required this.paragraphGap,
    required this.blankGap,
    required this.shrinkEmptyLines,
    this.firstPageHeaderHeight = 0.0,
  });

  final ChapterTextEngine engine;

  /// Number of fixed indent columns on the first line of every
  /// paragraph (0/1/2).
  final int indentCells;
  final double maxWidth;
  final double maxHeight;
  final double lineHeight;
  final double paragraphGap;
  final double blankGap;
  final bool shrinkEmptyLines;
  final double firstPageHeaderHeight;

  List<TypesetPage> layout(List<ChapterContentElement> elements) {
    final state = _PackingState(firstPageHeaderHeight: firstPageHeaderHeight);

    for (var elementIndex = 0;
        elementIndex < elements.length;
        elementIndex++) {
      final element = elements[elementIndex];

      if (element is ImageContent) {
        state.flushPage();
        // A chapter starting with a full-page image has no room for the
        // chapter title header; drop the reservation to avoid a gap.
        state.pendingHeaderHeight = 0.0;
        state.pages.add(TypesetPage(
          image: element,
          imageElementIndex: elementIndex,
        ));
        continue;
      }

      final text = (element as TextContent).text;
      if (text.isEmpty) {
        continue;
      }

      // Blank paragraphs collapse to a small gap; blanks at the top of a
      // page and consecutive blanks are dropped.
      if (shrinkEmptyLines && isTypesetBlankText(text)) {
        if (state.blocks.isEmpty ||
            state.blocks.last is TypesetBlankGap) {
          continue;
        }
        if (state.usedHeight + blankGap > maxHeight) {
          state.flushPage();
        } else {
          state.blocks.add(TypesetBlankGap(
            elementIndex: elementIndex,
            height: blankGap,
          ));
          state.usedHeight += blankGap;
        }
        continue;
      }

      // An element may contain hard line breaks ('\n'); each segment is
      // broken and laid out independently. Only the first segment carries
      // the first-line indentation (matching the old TextPainter prefix
      // behavior) and the paragraph gap.
      var segmentStart = 0;
      var isFirstSegment = true;
      while (true) {
        final nl = text.indexOf('\n', segmentStart);
        final segmentText = nl < 0
            ? text.substring(segmentStart)
            : text.substring(segmentStart, nl);
        final hasMore = nl >= 0;
        if (segmentText.isNotEmpty) {
          _layoutSegment(
            state,
            elementIndex: elementIndex,
            segmentText: segmentText,
            charOffset: segmentStart,
            segmentIndentCells: isFirstSegment ? indentCells : 0,
            isElementStart: isFirstSegment,
          );
        } else if (hasMore) {
          // A consecutive hard line break ('\n\n') renders as an empty
          // line. A trailing '\n' is not a segment here (hasMore is
          // false), matching the old renderer that stripped it.
          state.addBlankLine(elementIndex, lineHeight, maxHeight);
        }
        if (!hasMore) {
          break;
        }
        segmentStart = nl + 1;
        isFirstSegment = false;
      }
    }

    state.flushPage();

    if (state.pages.isEmpty) {
      state.pages.add(const TypesetPage());
    }
    return state.pages;
  }

  /// Measures, breaks and positions one paragraph segment, packing its
  /// lines into [state]'s current page.
  void _layoutSegment(
    _PackingState state, {
    required int elementIndex,
    required String segmentText,
    required int charOffset,
    required int segmentIndentCells,
    required bool isElementStart,
  }) {
    final units = engine.buildParagraphUnits(
      text: segmentText,
      elementIndex: elementIndex,
      indentCells: segmentIndentCells,
      charOffset: charOffset,
    );
    final words = [for (final u in units) u.text];
    final widths = [for (final u in units) u.width];

    final hanging =
        HangingPunctuationRule.shouldHang(words, segmentIndentCells)
            ? LineColumnLayout.hangingWidth(
                widths: widths,
                indentLength: segmentIndentCells,
                indentCharWidth: engine.indentCharWidth,
              )
            : 0.0;

    final breaks = ZhLineBreaker.breakLines(
      words: words,
      widths: widths,
      capacity: maxWidth,
      emWidth: engine.emWidth,
      indentUnits: segmentIndentCells,
      firstLineExtra: hanging,
    );

    for (var lineIndex = 0; lineIndex < breaks.length; lineIndex++) {
      final br = breaks[lineIndex];
      // A break can cover zero units only when a single glyph is wider
      // than the whole line; such a line paints nothing and must not be
      // packed (its empty glyph list would also break position getters).
      if (br.end <= br.start) {
        continue;
      }
      final lineUnits = units.sublist(br.start, br.end);
      final isFirstLine = lineIndex == 0;
      final isLastLine = lineIndex == breaks.length - 1;

      engine.compressLineEnd(
        lineUnits,
        isParagraphLast: isLastLine,
      );

      final desiredWidth =
          lineUnits.fold(0.0, (sum, u) => sum + u.width);
      final lineWords = words.sublist(br.start, br.end);
      final lineWidths = [for (final u in lineUnits) u.width];

      final LineColumnResult columns;
      var exceedSkipLeading = 0;
      if (isFirstLine && breaks.length > 1) {
        // Multi-line paragraph first line: fixed indent, optional hung
        // quote, justified body.
        columns = LineColumnLayout.justifiedFirst(
          words: lineWords,
          widths: lineWidths,
          visibleWidth: maxWidth,
          desiredWidth: desiredWidth,
          indentLength: segmentIndentCells,
          indentCharWidth: engine.indentCharWidth,
          hangingWidth: hanging,
        );
        // exceed() redistributes body columns only; the fixed indent
        // (and a hung quote) live inside the indent area.
        exceedSkipLeading =
            segmentIndentCells + (hanging > 0.0 ? 1 : 0);
      } else if (isLastLine) {
        // Last line (and single-line paragraphs) stay natural. Only the
        // first line of the element carries indent/hanging.
        columns = LineColumnLayout.natural(
          widths: lineWidths,
          hasIndent: isFirstLine && segmentIndentCells > 0,
          indentLength: segmentIndentCells,
          hangingWidth: isFirstLine ? hanging : 0.0,
        );
      } else {
        columns = LineColumnLayout.justified(
          words: lineWords,
          widths: lineWidths,
          visibleWidth: maxWidth,
          desiredWidth: desiredWidth,
        );
      }

      // legado's exceed(): a CPS-tolerated break can leave the final
      // column past the visible right edge; pull the line leftwards so
      // no glyph is clipped. Regular justified lines never overflow.
      final exceedResult = LineColumnLayout.exceed(
        columns.columns,
        words: lineWords,
        visibleWidth: maxWidth,
        skipLeading: exceedSkipLeading,
      );

      for (final c in exceedResult.columns) {
        final unit = lineUnits[c.index];
        unit
          ..kind = c.kind
          ..xStart = c.xStart
          ..xEnd = c.xEnd;
      }

      var topGap = 0.0;
      // Reserve paragraph spacing when an element starts on a page that
      // already has content. Continuation segments (after '\n') add none.
      if (isElementStart && isFirstLine && state.blocks.isNotEmpty) {
        if (state.usedHeight + paragraphGap + lineHeight > maxHeight) {
          state.flushPage();
        } else {
          state.usedHeight += paragraphGap;
          topGap = paragraphGap;
        }
      }

      // Consume the chapter title reservation before the first line of
      // the first page.
      state.consumeHeader();

      if (state.blocks.isNotEmpty &&
          state.usedHeight + lineHeight > maxHeight) {
        state.flushPage();
        topGap = 0.0;
      }

      state.blocks.add(TypesetLine(
        elementIndex: elementIndex,
        glyphs: lineUnits,
        height: lineHeight,
        topGap: topGap,
        isParagraphFirst: isElementStart && isFirstLine,
        isParagraphLast: isLastLine,
        naturalWidth: desiredWidth,
        justifyGap: columns.justifyGap,
        justifyViaSpaces: columns.justifyViaSpaces,
        isExceeded: exceedResult.exceeded,
      ));
      state.usedHeight += lineHeight;
    }
  }
}

/// Mutable page-packing state shared across elements.
class _PackingState {
  _PackingState({required double firstPageHeaderHeight})
      : pendingHeaderHeight = firstPageHeaderHeight;

  final List<TypesetPage> pages = [];
  List<TypesetBlock> blocks = [];
  double usedHeight = 0.0;

  /// Space reserved on the first page for the chapter title; consumed
  /// before the first line is placed.
  double pendingHeaderHeight;

  void flushPage() {
    if (blocks.isNotEmpty) {
      pages.add(TypesetPage(blocks: List.of(blocks)));
      blocks = <TypesetBlock>[];
      usedHeight = 0.0;
    }
  }

  void consumeHeader() {
    if (pendingHeaderHeight > 0.0 && blocks.isEmpty) {
      usedHeight += pendingHeaderHeight;
      pendingHeaderHeight = 0.0;
    }
  }

  /// Packs an empty line produced by a consecutive hard break. It is
  /// dropped at the top of a page (no dangling blank line) and never
  /// forces a new page on its own when it does not fit.
  void addBlankLine(int elementIndex, double height, double maxHeight) {
    if (blocks.isEmpty || usedHeight + height > maxHeight) {
      return;
    }
    blocks.add(TypesetBlankGap(elementIndex: elementIndex, height: height));
    usedHeight += height;
  }
}

/// Finds the page containing [position], with the same semantics as the
/// old `pageIndexOfPosition` but using source offsets: synthetic indent
/// units cover no characters, so [TypesetLine.endChar] is an offset in
/// the original element text.
int typesetPageIndexOfPosition(
  List<TypesetPage> pages,
  ReadPosition position,
) {
  final elementIndex = position.elementIndex;
  final characterIndex = position.elementCharacterIndex ?? 0;

  for (var i = 0; i < pages.length; i++) {
    final page = pages[i];
    if (page.isImagePage()) {
      if (page.imageElementIndex! >= elementIndex) {
        return i;
      }
      continue;
    }
    final lastLine = page.lastLine;
    if (lastLine == null) {
      // A page holding only collapsed blank gaps cannot contain a text
      // position.
      continue;
    }
    final isAfterPosition =
        lastLine.elementIndex > elementIndex ||
            (lastLine.elementIndex == elementIndex &&
                lastLine.endChar > characterIndex);
    if (isAfterPosition) {
      return i;
    }
  }
  return pages.isEmpty ? 0 : pages.length - 1;
}
