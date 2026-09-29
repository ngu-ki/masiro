import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masiro/data/repository/model/chapter_detail.dart';
import 'package:masiro/data/repository/model/text_color_mode.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_models.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_page_painter.dart';

const _red = 0xFFFF0000;
const _black = 0xFF000000;
const _transparent = 0x00000000;

GlyphUnit unit(
  String text, {
  int elementIndex = 0,
  int charStart = 0,
  int charEnd = 1,
  double width = 100,
  double xStart = 0,
  double xEnd = 100,
  GlyphColumnKind kind = GlyphColumnKind.text,
  bool compressed = false,
  double drawOffset = 0,
}) {
  return GlyphUnit(
    text: text,
    elementIndex: elementIndex,
    charStart: charStart,
    charEnd: charEnd,
    width: width,
    xStart: xStart,
    xEnd: xEnd,
    kind: kind,
    compressed: compressed,
    drawOffset: drawOffset,
  );
}

TypesetLine line(
  List<GlyphUnit> glyphs, {
  double topGap = 0,
  double height = 30,
  double justifyGap = 0,
  bool justifyViaSpaces = false,
}) {
  return TypesetLine(
    elementIndex: 0,
    glyphs: glyphs,
    height: height,
    topGap: topGap,
    justifyGap: justifyGap,
    justifyViaSpaces: justifyViaSpaces,
  );
}

TypesetPaintPlan planOf(
  TypesetPage page, {
  Map<int, List<ColoredRange>> ranges = const {},
  TextColorMode mode = TextColorMode.uniform,
  bool reveal = false,
}) {
  return buildTypesetPaintPlan(
    page,
    rangesByElement: ranges,
    mode: mode,
    bodyColor: const Color(0xFF262626),
    revealTransparent: reveal,
  );
}

void main() {
  group('TR-6.1 draw commands use stored geometry', () {
    test('uniform justified line is painted per glyph at stored columns',
        () {
      // Regression for an em-wide hole in justified CJK lines: a uniform
      // line must be drawn glyph-by-glyph at the measured columns. A single
      // TextPainter + letterSpacing lets font shaping (e.g. the ellipsis
      // '……') drift from the stored columns, so the extra justify space
      // must never be handed to the painter as letterSpacing.
      final glyphs = [
        unit('能', xStart: 0, xEnd: 60),
        unit('…', xStart: 60, xEnd: 120),
        unit('…', xStart: 120, xEnd: 180),
        unit('有', xStart: 180, xEnd: 240),
      ];
      final page = TypesetPage(blocks: [
        line(glyphs, justifyGap: 12),
      ]);
      final plan = planOf(page);
      expect(plan.commands, hasLength(4));
      expect(plan.perGlyphPaints, 4);
      expect(plan.groupPaints, 0);
      expect(plan.fastPathRatio, closeTo(0.0, epsilon));
      for (var i = 0; i < 4; i++) {
        expect(plan.commands[i].text, glyphs[i].text);
        expect(plan.commands[i].x, closeTo(i * 60.0, epsilon));
        expect(plan.commands[i].letterSpacing, 0);
      }
    });

    test('compressed/hung line is painted per glyph with draw offset', () {
      final glyphs = [
        unit('字', xStart: 0, xEnd: 100),
        unit('。',
            xStart: 100, xEnd: 160, compressed: true, drawOffset: -20),
      ];
      final page = TypesetPage(blocks: [
        line(glyphs, height: 30),
        TypesetBlankGap(elementIndex: 0, height: 5),
        line([
          unit('字', xStart: 0, xEnd: 100),
        ], topGap: 7),
      ]);
      final plan = planOf(page);
      // Two per-glyph commands for the irregular line and one for the
      // uniform line after the blank gap (uniform lines are also drawn
      // per glyph now).
      expect(plan.perGlyphPaints, 3);
      expect(plan.groupPaints, 0);
      expect(plan.commands[0].x, closeTo(0, epsilon));
      expect(plan.commands[1].x, closeTo(80, epsilon)); // 100 - 20
      expect(plan.commands[1].text, '。');
      // y: 30 (first line) + 5 (blank gap) + 7 (top gap) = 42.
      expect(plan.commands[2].y, closeTo(42, epsilon));
      expect(plan.commands[2].x, closeTo(0, epsilon));
    });

    test('justifyViaSpaces splits groups at spaces', () {
      final glyphs = [
        unit('a', width: 50, xStart: 0, xEnd: 50),
        unit(' ', width: 50, xStart: 50, xEnd: 125),
        unit('b', width: 50, xStart: 125, xEnd: 175),
      ];
      final page = TypesetPage(blocks: [
        line(glyphs, justifyGap: 25, justifyViaSpaces: true),
      ]);
      final plan = planOf(page);
      expect(plan.commands, hasLength(2));
      expect(plan.commands[0].text, 'a');
      expect(plan.commands[0].x, 0);
      expect(plan.commands[1].text, 'b');
      expect(plan.commands[1].x, closeTo(125, epsilon));
      expect(plan.commands.every((c) => c.letterSpacing == 0), isTrue);
    });

    test('color is resolved per glyph on a uniform line', () {
      final glyphs = [
        unit('字', charStart: 0, xStart: 0, xEnd: 100),
        unit('字', charStart: 1, xStart: 100, xEnd: 200),
        unit('字', charStart: 2, xStart: 200, xEnd: 300),
      ];
      final page = TypesetPage(blocks: [line(glyphs)]);
      final plan = planOf(page, ranges: {
        0: [(start: 1, end: 2, color: _red)],
      }, mode: TextColorMode.original);
      expect(plan.commands, hasLength(3));
      expect(plan.commands[0].text, '字');
      expect(plan.commands[1].color, const Color(_red));
      expect(plan.commands[2].color, isNull);
    });
  });

  group('TR-6.2 color modes', () {
    final ranges = <int, List<ColoredRange>>{
      0: [
        (start: 0, end: 3, color: _red),
        (start: 3, end: 6, color: _black),
        (start: 6, end: 9, color: _transparent),
      ],
    };

    TypesetColorResolver resolver(TextColorMode mode, {bool reveal = false}) {
      return TypesetColorResolver(
        rangesByElement: ranges,
        mode: mode,
        bodyColor: const Color(0xFF262626),
        revealTransparent: reveal,
      );
    }

    GlyphUnit at(int offset) =>
        unit('字', charStart: offset, charEnd: offset + 1);

    test('uniform mode always uses the body color', () {
      final r = resolver(TextColorMode.uniform);
      for (final offset in [0, 3, 6]) {
        expect(r.resolve(at(offset)), isNull);
      }
    });

    test('original mode keeps declared colors verbatim', () {
      final r = resolver(TextColorMode.original);
      expect(r.resolve(at(0)), const Color(_red));
      expect(r.resolve(at(3)), const Color(_black));
      expect(r.resolve(at(6)), const Color(_transparent));
    });

    test('original reveal turns transparent text muted', () {
      final r = resolver(TextColorMode.original, reveal: true);
      final muted = r.resolve(at(6));
      expect(muted, const Color(0xFF262626).withValues(alpha: 0.45));
      // Non-transparent colors are unaffected by the reveal flag.
      expect(r.resolve(at(0)), const Color(_red));
    });

    test('simplified mode mutes colors but keeps black as body', () {
      final r = resolver(TextColorMode.simplified);
      final muted = const Color(0xFF262626).withValues(alpha: 0.45);
      expect(r.resolve(at(0)), muted);
      expect(r.resolve(at(3)), isNull);
      // Transparent declarations are also muted so the text is visible.
      expect(r.resolve(at(6)), muted);
    });

    test('indent units and uncolored elements use the body color', () {
      final r = resolver(TextColorMode.original);
      final indent = unit('　',
          charStart: 0, charEnd: 0, kind: GlyphColumnKind.indent);
      expect(r.resolve(indent), isNull);
      expect(r.resolve(unit('字', elementIndex: 9, charStart: 0)), isNull);
    });
  });
}
