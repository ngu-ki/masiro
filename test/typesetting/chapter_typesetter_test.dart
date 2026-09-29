import 'package:flutter_test/flutter_test.dart';
import 'package:masiro/data/repository/model/chapter_detail.dart';
import 'package:masiro/data/repository/model/read_position.dart';
import 'package:masiro/ui/screens/reader/typesetting/chapter_typesetter.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_models.dart';

/// Deterministic engine: every BMP character gets a fixed advance, the
/// last closing punctuation of a non-final line can be trimmed by a
/// fixed amount, no font pipeline involved.
class _FixedEngine implements ChapterTextEngine {
  _FixedEngine({
    required this.emWidth,
    double? indentCharWidth,
    this.widths = const {},
    this.lineEndTrim = 0.0,
  }) : _indentCharWidth = indentCharWidth;

  @override
  final double emWidth;
  final double? _indentCharWidth;
  final Map<String, double> widths;
  final double lineEndTrim;

  static const _close = '。，、！？”';

  @override
  double get indentCharWidth => _indentCharWidth ?? emWidth;

  @override
  List<GlyphUnit> buildParagraphUnits({
    required String text,
    required int elementIndex,
    required int indentCells,
    int charOffset = 0,
  }) {
    final body = <GlyphUnit>[
      for (var i = 0; i < text.length; i++)
        GlyphUnit(
          text: text[i],
          elementIndex: elementIndex,
          charStart: i + charOffset,
          charEnd: i + charOffset + 1,
          width: widths[text[i]] ?? emWidth,
        ),
    ];
    return [
      for (var i = 0; i < indentCells; i++)
        GlyphUnit(
          text: '　',
          elementIndex: elementIndex,
          charStart: 0,
          charEnd: 0,
          width: indentCharWidth,
          kind: GlyphColumnKind.indent,
        ),
      ...body,
    ];
  }

  @override
  bool compressLineEnd(
    List<GlyphUnit> lineUnits, {
    required bool isParagraphLast,
  }) {
    if (isParagraphLast || lineEndTrim <= 0) return false;
    for (var i = lineUnits.length - 1; i >= 0; i--) {
      final unit = lineUnits[i];
      if (unit.text.trim().isEmpty) continue;
      if (!_close.contains(unit.text)) return false;
      unit
        ..width -= lineEndTrim
        ..compressed = true;
      return true;
    }
    return false;
  }
}

ChapterTypesetter makeTypesetter(
  _FixedEngine engine, {
  int indentCells = 0,
  double maxWidth = 300,
  double maxHeight = 35,
  double lineHeight = 10,
  double paragraphGap = 5,
  double blankGap = 4,
  bool shrinkEmptyLines = false,
  bool hangOpeningPunctuation = true,
  double header = 0,
}) {
  return ChapterTypesetter(
    engine: engine,
    indentCells: indentCells,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    lineHeight: lineHeight,
    paragraphGap: paragraphGap,
    blankGap: blankGap,
    shrinkEmptyLines: shrinkEmptyLines,
    hangOpeningPunctuation: hangOpeningPunctuation,
    firstPageHeaderHeight: header,
  );
}

TextContent text(String s) => TextContent(text: s);

List<TypesetLine> linesOf(TypesetPage page) =>
    page.blocks.whereType<TypesetLine>().toList();

void main() {
  group('TR-5.1 page packing', () {
    test('lines pack with the header reservation', () {
      final engine = _FixedEngine(emWidth: 100);
      // 7 chars at 3 per line (capacity 300): 3 + 3 + 1 lines.
      final pages = makeTypesetter(engine, header: 15)
          .layout([text('字字字字字字字')]);
      expect(pages, hasLength(2));
      expect(linesOf(pages[0]), hasLength(2)); // 15 + 10 + 10 = 35
      expect(linesOf(pages[1]), hasLength(1));
      // The first body line starts after the (invisible) header block.
      expect(linesOf(pages[0]).first.topGap, 0);
    });

    test('without the header three lines fill the page', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine).layout([text('字字字字字字字字字')]);
      // 9 chars: 3 + 3 + 3 lines, exactly one page.
      expect(pages, hasLength(1));
      expect(linesOf(pages[0]), hasLength(3));
    });

    test('paragraph gap is added inside a page and dropped on flush', () {
      final engine = _FixedEngine(emWidth: 100);

      // Fits together: gap is recorded on the second paragraph's line.
      final together = makeTypesetter(engine).layout([
        text('字'),
        text('字'),
      ]);
      expect(together, hasLength(1));
      final p1lines = linesOf(together[0]);
      expect(p1lines[0].topGap, 0);
      expect(p1lines[1].topGap, closeTo(5, epsilon));

      // First paragraph fills the page (3 lines = 30); the next
      // paragraph must start a fresh page with no top gap.
      final split = makeTypesetter(engine).layout([
        text('字字字字字字字字字'),
        text('字'),
      ]);
      expect(split, hasLength(2));
      expect(linesOf(split[1]).single.topGap, 0);
    });

    test('blank gaps are placed, collapsed and dropped at page top', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine, shrinkEmptyLines: true).layout([
        text('字'),
        text('　'),
        text('　'), // consecutive blank collapses
        text('字'),
      ]);
      expect(pages, hasLength(1));
      final blocks = pages[0].blocks;
      expect(blocks, hasLength(3));
      expect(blocks[1], isA<TypesetBlankGap>());
      expect((blocks[1] as TypesetBlankGap).height, closeTo(4, epsilon));

      // A blank element at the very start is dropped.
      final leading = makeTypesetter(engine, shrinkEmptyLines: true).layout([
        text('　'),
        text('字'),
      ]);
      expect(leading, hasLength(1));
      expect(leading[0].blocks, hasLength(1));
      expect(leading[0].blocks.first, isA<TypesetLine>());
    });

    test('line-end compression feeds the justified columns', () {
      // 字 字 。 fill the first line; trimming the close mark by 40 leaves
      // a residual of 40 spread over the two inter-glyph gaps.
      final engine = _FixedEngine(emWidth: 100, lineEndTrim: 40);
      final pages = makeTypesetter(engine).layout([text('字字。字字')]);
      expect(pages, hasLength(1));
      final pageLines = linesOf(pages[0]);
      expect(pageLines, hasLength(2));
      final first = pageLines.first;
      expect(first.naturalWidth, closeTo(260, epsilon));
      expect(first.justifyGap, closeTo(20, epsilon));
      expect(first.justifyViaSpaces, isFalse);
      expect(first.glyphs.last.xEnd, closeTo(300, epsilon));
      expect(first.glyphs.last.compressed, isTrue);
    });

    test('empty chapter yields one empty page', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine).layout([]);
      expect(pages, hasLength(1));
      expect(pages[0].blocks, isEmpty);
    });
  });

  group('TR-5.2 full-page images', () {
    test('image occupies its own page and flushes surrounding text', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine).layout([
        text('字字字字字字字字字'), // 3 lines
        ImageContent(src: 'x.png'),
        text('字'),
      ]);
      expect(pages, hasLength(3));
      expect(linesOf(pages[0]), hasLength(3));
      expect(pages[1].isImagePage(), isTrue);
      expect(pages[1].imageElementIndex, 1);
      expect(pages[1].blocks, isEmpty);
      expect(linesOf(pages[2]), hasLength(1));
    });

    test('leading image drops the header reservation', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine, header: 15).layout([
        ImageContent(src: 'cover.png'),
        text('字字字字字字字字字'), // 3 lines fit only without header
      ]);
      expect(pages[0].isImagePage(), isTrue);
      expect(linesOf(pages[1]), hasLength(3));
    });
  });

  group('TR-5.3 offsets and position lookup', () {
    test('glyph units retain source element and character offsets', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine).layout([text('字字字字字字字')]);
      final allGlyphs = [
        for (final p in pages)
          for (final l in linesOf(p)) ...l.glyphs,
      ];
      expect(allGlyphs, hasLength(7));
      expect(allGlyphs.every((g) => g.elementIndex == 0), isTrue);
      for (var i = 0; i < 7; i++) {
        expect(allGlyphs[i].charStart, i);
        expect(allGlyphs[i].charEnd, i + 1);
      }
    });

    test('pageIndexOfPosition maps character offsets to pages', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages =
          makeTypesetter(engine, header: 15).layout([text('字字字字字字字')]);
      // Page 0 carries chars [0, 6); page 1 carries [6, 7).
      ReadPosition pos(int char) => ReadPosition(
            elementIndex: 0,
            elementTopOffset: 0,
            elementCharacterIndex: char,
            articleCharacterIndex: char,
          );
      expect(typesetPageIndexOfPosition(pages, pos(0)), 0);
      expect(typesetPageIndexOfPosition(pages, pos(5)), 0);
      expect(typesetPageIndexOfPosition(pages, pos(6)), 1);
      expect(typesetPageIndexOfPosition(pages, pos(100)), 1);
    });

    test('pageIndexOfPosition stops at the image page', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine).layout([
        text('字'),
        ImageContent(src: 'x.png'),
      ]);
      const position = ReadPosition(
        elementIndex: 1,
        elementTopOffset: 0,
        elementCharacterIndex: 0,
        articleCharacterIndex: 0,
      );
      expect(typesetPageIndexOfPosition(pages, position), 1);
    });
  });

  group('TR-5.4 indentation', () {
    test('fixed indent columns precede body units with zero source span', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages =
          makeTypesetter(engine, indentCells: 2).layout([text('字字字字字')]);
      // First line: 2 indent + 1 body (300); then 3 body; then 1 body.
      final firstLine = linesOf(pages[0]).first;
      expect(firstLine.glyphs[0].kind, GlyphColumnKind.indent);
      expect(firstLine.glyphs[1].kind, GlyphColumnKind.indent);
      expect(firstLine.glyphs[0].xStart, closeTo(0, epsilon));
      expect(firstLine.glyphs[1].xEnd, closeTo(200, epsilon));
      final firstBody = firstLine.glyphs[2];
      expect(firstBody.kind, GlyphColumnKind.text);
      expect(firstBody.xStart, closeTo(200, epsilon));
      expect(firstBody.charStart, 0);
      expect(firstBody.charEnd, 1);
    });

    test('a single-line paragraph keeps natural placement with indent', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine,
              indentCells: 2, maxWidth: 400)
          .layout([text('字')]);
      expect(pages, hasLength(1));
      final line = linesOf(pages[0]).single;
      expect(line.isParagraphLast, isTrue);
      expect(line.justifyGap, 0);
      expect(line.glyphs.last.xStart, closeTo(200, epsilon));
    });

    test('source indentation is laid out as ordinary body units', () {
      // Mode "two" without adaptive normalization: the source already
      // contains one leading full-width space; it is measured as a body
      // unit after the two fixed indent cells.
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine,
              indentCells: 2, maxWidth: 500)
          .layout([text('　字')]);
      final line = linesOf(pages[0]).single;
      expect(line.glyphs, hasLength(4));
      // The real body character starts at x = 3 * 100.
      expect(line.glyphs.last.text, '字');
      expect(line.glyphs.last.xStart, closeTo(300, epsilon));
      expect(line.glyphs[2].kind, GlyphColumnKind.text);
    });

    test('hard line breaks split segments without extra paragraph gap', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine,
              indentCells: 2, maxWidth: 500)
          .layout([text('字\n字')]);
      expect(pages, hasLength(1));
      final pageLines = linesOf(pages[0]);
      expect(pageLines, hasLength(2));
      // First segment carries indent...
      expect(pageLines[0].glyphs.first.kind, GlyphColumnKind.indent);
      // ...the continuation segment starts flush left.
      expect(pageLines[1].glyphs.first.kind, GlyphColumnKind.text);
      expect(pageLines[1].glyphs.first.xStart, closeTo(0, epsilon));
      expect(pageLines[1].topGap, 0);
      // Source offsets survive the split: the second segment starts at 2
      // (index 1 is the '\n').
      expect(pageLines[1].glyphs.first.charStart, 2);
    });

    test('consecutive hard breaks produce a blank-line gap, trailing '
        'break produces none', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine,
              indentCells: 2, maxWidth: 500)
          .layout([text('字\n\n字\n')]);
      expect(pages, hasLength(1));
      final blocks = pages[0].blocks;
      expect(blocks, hasLength(3));
      expect(blocks[0], isA<TypesetLine>());
      expect(blocks[1], isA<TypesetBlankGap>()
          .having((g) => g.height, 'height', closeTo(10, epsilon)));
      expect(blocks[2], isA<TypesetLine>());
    });

    test('CPS-tolerated single-line paragraph is pulled back inside '
        'the visible width (exceed)', () {
      // Same input as the zh_layout CPS_3 case: natural width 350 vs
      // capacity 300. compressLineEnd never trims a paragraph-last line,
      // so exceed() must absorb the overflow.
      final engine = _FixedEngine(
        emWidth: 100,
        widths: const {'a': 50},
      );
      final pages = makeTypesetter(engine,
              indentCells: 0, maxWidth: 300, maxHeight: 10000)
          .layout([text('a“字。')]);
      expect(pages, hasLength(1));
      final line = linesOf(pages[0]).single;
      expect(line.isExceeded, isTrue);
      expect(line.hasIrregularGlyphs, isTrue);
      expect(line.glyphs.last.xEnd, closeTo(300, epsilon));
      for (final unit in line.glyphs) {
        expect(unit.xEnd, lessThanOrEqualTo(300 + epsilon));
      }
    });

    test('every painted line stays inside the visible width '
        '(exhaustive short sequences)', () {
      const alphabet = ['字', 'a', '“', '。'];
      final engine = _FixedEngine(
        emWidth: 100,
        widths: const {'a': 50},
      );
      Iterable<List<int>> sequences(int length) sync* {
        if (length == 0) {
          yield <int>[];
          return;
        }
        for (final rest in sequences(length - 1)) {
          for (var i = 0; i < alphabet.length; i++) {
            yield [...rest, i];
          }
        }
      }

      for (var length = 1; length <= 6; length++) {
        for (final picks in sequences(length)) {
          final content = picks.map((i) => alphabet[i]).join();
          final pages = makeTypesetter(engine,
                  maxWidth: 300, maxHeight: 100000)
              .layout([text(content)]);
          for (final page in pages) {
            for (final block in page.blocks) {
              if (block is! TypesetLine) continue;
              for (final unit in block.glyphs) {
                expect(
                  unit.xEnd,
                  lessThanOrEqualTo(300 + epsilon),
                  reason: 'right edge clipped for "$content": '
                      'unit ${unit.text} xEnd=${unit.xEnd}',
                );
                expect(unit.xStart, greaterThanOrEqualTo(-100 - epsilon),
                    reason: 'unexpected left overshoot for "$content"');
              }
            }
          }
        }
      }
    });

    test('opening quote hangs into the indent area', () {
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(engine,
              indentCells: 2, maxWidth: 300)
          .layout([text('“字')]);
      // The hung mark frees one em, so the whole paragraph is one line.
      final line = linesOf(pages[0]).single;
      expect(line.hasHanging, isTrue);
      final hang =
          line.glyphs.firstWhere((g) => g.kind == GlyphColumnKind.hanging);
      expect(hang.text, '“');
      expect(hang.xStart, closeTo(100, epsilon));
      expect(hang.xEnd, closeTo(200, epsilon));
      expect(line.glyphs.last.xStart, closeTo(200, epsilon));
    });

    test('forced indent keeps the opening quote after the indent cells',
        () {
      // The forced indent mode disables hanging: every paragraph's first
      // glyph (opening quote included) starts after both indent cells.
      final engine = _FixedEngine(emWidth: 100);
      final pages = makeTypesetter(
        engine,
        indentCells: 2,
        maxWidth: 400,
        maxHeight: 10000,
        hangOpeningPunctuation: false,
      ).layout([text('“字字')]);
      final firstLine = linesOf(pages[0]).first;
      expect(firstLine.hasHanging, isFalse);
      expect(
        firstLine.glyphs.any((g) => g.kind == GlyphColumnKind.hanging),
        isFalse,
      );
      // First body unit is the quote itself, placed right after the two
      // indent cells rather than hung into them.
      final quote = firstLine.glyphs[2];
      expect(quote.text, '“');
      expect(quote.kind, GlyphColumnKind.text);
      expect(quote.xStart, closeTo(200, epsilon));
    });
  });
}
