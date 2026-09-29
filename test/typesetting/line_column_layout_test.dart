import 'package:flutter_test/flutter_test.dart';
import 'package:masiro/ui/screens/reader/typesetting/line_column_layout.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_models.dart';

void main() {
  group('TR-4.1 justified vs natural placement', () {
    test('justified distributes residual over inter-glyph gaps', () {
      final r = LineColumnLayout.justified(
        words: ['字', '字', '字'],
        widths: [100, 100, 100],
        visibleWidth: 330,
        desiredWidth: 300,
      );
      expect(r.columns, hasLength(3));
      expect(r.columns[0].xStart, closeTo(0, epsilon));
      expect(r.columns[0].xEnd, closeTo(115, epsilon));
      expect(r.columns[1].xStart, closeTo(115, epsilon));
      expect(r.columns[1].xEnd, closeTo(230, epsilon));
      // The last unit reaches the right edge; no gap after it.
      expect(r.columns[2].xEnd, closeTo(330, epsilon));
      expect(r.justifyGap, closeTo(15, epsilon));
      expect(r.justifyViaSpaces, isFalse);
      expect(r.columns.every((c) => c.kind == GlyphColumnKind.text),
          isTrue);
    });

    test('natural keeps trailing blank at the right edge', () {
      final r = LineColumnLayout.natural(
        widths: [100, 100, 100],
      );
      expect(r.columns[2].xStart, closeTo(200, epsilon));
      expect(r.columns[2].xEnd, closeTo(300, epsilon));
      expect(r.justifyGap, 0);
    });
  });

  group('exceed() overflow redistribution', () {
    test('shifts columns left so the last column ends at visibleWidth',
        () {
      final natural = LineColumnLayout.natural(
        widths: [100, 100, 100],
      );
      final r = LineColumnLayout.exceed(
        natural.columns,
        words: ['字', '字', '字'],
        visibleWidth: 250,
      );
      expect(r.exceeded, isTrue);
      // overflow 50 / size 3: shifts are 50, 33.33, 16.67.
      expect(r.columns[2].xEnd, closeTo(250, epsilon));
      expect(r.columns[2].xStart, closeTo(150, epsilon));
      expect(r.columns[1].xStart, closeTo(66.6667, 1e-3));
      expect(r.columns[0].xStart, closeTo(-16.6667, 1e-3));
      // Every column keeps its width.
      for (var i = 0; i < 3; i++) {
        expect(
          r.columns[i].xEnd - r.columns[i].xStart,
          closeTo(100, epsilon),
        );
      }
    });

    test('no-op when the line fits', () {
      final natural = LineColumnLayout.natural(
        widths: [100, 100],
      );
      final r = LineColumnLayout.exceed(
        natural.columns,
        words: ['字', '字'],
        visibleWidth: 300,
      );
      expect(r.exceeded, isFalse);
      expect(identical(r.columns, natural.columns), isTrue);
    });

    test('single column is never redistributed', () {
      final natural = LineColumnLayout.natural(widths: [400]);
      final r = LineColumnLayout.exceed(
        natural.columns,
        words: ['宽'],
        visibleWidth: 300,
      );
      expect(r.exceeded, isFalse);
    });

    test('a trailing ASCII space is excluded and left in place', () {
      final natural = LineColumnLayout.natural(
        widths: [100, 100, 50],
      );
      final r = LineColumnLayout.exceed(
        natural.columns,
        words: ['字', '字', ' '],
        visibleWidth: 180,
      );
      expect(r.exceeded, isTrue);
      // overflow 20 distributed over 2 body columns; the end column is
      // the second one and lands exactly on visibleWidth.
      expect(r.columns[1].xEnd, closeTo(180, epsilon));
      // The trailing space column itself is untouched.
      expect(r.columns[2].xStart, closeTo(200, epsilon));
      expect(r.columns[2].xEnd, closeTo(250, epsilon));
    });

    test('skipLeading excludes indent and hanging columns', () {
      final columns = [
        ColumnBox(0, 0, 100, GlyphColumnKind.indent),
        ColumnBox(1, 0, 100, GlyphColumnKind.hanging),
        ColumnBox(2, 100, 200, GlyphColumnKind.text),
        ColumnBox(3, 200, 350, GlyphColumnKind.text),
      ];
      final r = LineColumnLayout.exceed(
        columns,
        words: ['　', '“', '字', '。'],
        visibleWidth: 300,
        skipLeading: 2,
      );
      expect(r.exceeded, isTrue);
      // Fixed columns untouched; overflow 50 spread over 2 body columns.
      expect(r.columns[0].xStart, closeTo(0, epsilon));
      expect(r.columns[1].xStart, closeTo(0, epsilon));
      expect(r.columns[3].xEnd, closeTo(300, epsilon));
      expect(r.columns[2].xStart, closeTo(75, epsilon));
    });
  });

  group('TR-4.2 justify via ASCII spaces', () {
    test('residual goes to non-trailing spaces only', () {
      final r = LineColumnLayout.justified(
        words: ['a', ' ', 'b', ' ', 'c'],
        widths: [50, 50, 50, 50, 50],
        visibleWidth: 300,
        desiredWidth: 250,
      );
      expect(r.justifyViaSpaces, isTrue);
      expect(r.justifyGap, closeTo(25, epsilon));
      // a: 0..50; space: 50..125; b: 125..175; space: 175..250;
      // c: 250..300 (final unit gets no extra gap).
      final starts = [0.0, 50, 125, 175, 250];
      final ends = [50.0, 125, 175, 250, 300];
      for (var i = 0; i < 5; i++) {
        expect(r.columns[i].xStart, closeTo(starts[i], epsilon));
        expect(r.columns[i].xEnd, closeTo(ends[i], epsilon));
      }
    });

    test('one space falls back to inter-glyph distribution', () {
      final r = LineColumnLayout.justified(
        words: ['a', ' ', 'b'],
        widths: [50, 50, 50],
        visibleWidth: 250,
        desiredWidth: 150,
      );
      expect(r.justifyViaSpaces, isFalse);
      expect(r.justifyGap, closeTo(50, epsilon));
      expect(r.columns[2].xEnd, closeTo(250, epsilon));
    });
  });

  group('TR-4.3 justified first line with hanging punctuation', () {
    test('quote hangs into the two-cell indent', () {
      final r = LineColumnLayout.justifiedFirst(
        words: ['　', '　', '“', '字', '字'],
        widths: [100, 100, 100, 100, 100],
        visibleWidth: 500,
        desiredWidth: 500,
        indentLength: 2,
        indentCharWidth: 100,
        hangingWidth: 100,
      );
      expect(r.columns[0].kind, GlyphColumnKind.indent);
      expect(r.columns[1].kind, GlyphColumnKind.indent);
      expect(r.columns[0].xStart, closeTo(0, epsilon));
      expect(r.columns[1].xEnd, closeTo(200, epsilon));
      // The hung quote occupies [100, 200), inside the indent area.
      final hang = r.columns[2];
      expect(hang.kind, GlyphColumnKind.hanging);
      expect(hang.xStart, closeTo(100, epsilon));
      expect(hang.xEnd, closeTo(200, epsilon));
      // Body starts at x=200: the text origin matches non-indented
      // paragraphs' first glyph.
      expect(r.indentWidth, closeTo(100, epsilon));
      expect(r.columns[3].xStart, closeTo(200, epsilon));
    });

    test('no hanging: indent fixed, body starts after indent cells', () {
      final r = LineColumnLayout.justifiedFirst(
        words: ['　', '　', '字', '字'],
        widths: [100, 100, 100, 100],
        visibleWidth: 400,
        desiredWidth: 400,
        indentLength: 2,
        indentCharWidth: 100,
        hangingWidth: 0,
      );
      expect(r.columns.where((c) => c.kind == GlyphColumnKind.hanging),
          isEmpty);
      expect(r.indentWidth, closeTo(200, epsilon));
      expect(r.columns[2].xStart, closeTo(200, epsilon));
    });
  });

  group('TR-4.4 natural first line with hanging', () {
    test('natural layout also hangs the quote and clips indent', () {
      final r = LineColumnLayout.natural(
        widths: [100, 100, 100, 100],
        hasIndent: true,
        indentLength: 2,
        hangingWidth: 100,
      );
      // indentEnd = 200; hangingStart = 200 - 100 = 100.
      expect(r.columns[0].xStart, closeTo(0, epsilon));
      expect(r.columns[0].xEnd, closeTo(100, epsilon));
      // Second indent cell is clipped by the hung quote's start.
      expect(r.columns[1].xStart, closeTo(100, epsilon));
      expect(r.columns[1].xEnd, closeTo(100, epsilon));
      final hang = r.columns[2];
      expect(hang.kind, GlyphColumnKind.hanging);
      expect(hang.xStart, closeTo(100, epsilon));
      expect(hang.xEnd, closeTo(200, epsilon));
      expect(r.columns[3].xStart, closeTo(200, epsilon));
      expect(r.indentWidth, closeTo(100, epsilon));
    });

    test('no indent means no hanging columns', () {
      final r = LineColumnLayout.natural(widths: [100, 100]);
      expect(r.columns.every((c) => c.kind == GlyphColumnKind.text),
          isTrue);
      expect(r.indentWidth, 0);
    });
  });

  group('hangingWidth', () {
    test('fits when the candidate is no wider than the indent area', () {
      final w = LineColumnLayout.hangingWidth(
        widths: [100, 100, 100],
        indentLength: 2,
        indentCharWidth: 100,
      );
      expect(w, closeTo(100, epsilon));
    });

    test('oversized candidate does not hang', () {
      final w = LineColumnLayout.hangingWidth(
        widths: [100, 100, 250],
        indentLength: 2,
        indentCharWidth: 100,
      );
      expect(w, 0);
    });

    test('uses the smaller of measured and laid-out indent width', () {
      // Measured indent cells are slightly wider than the fixed layout
      // width; the bound must be 2 * 98 = 196.
      final w = LineColumnLayout.hangingWidth(
        widths: [101, 101, 196.2],
        indentLength: 2,
        indentCharWidth: 98,
      );
      expect(w, closeTo(196.2, epsilon));
    });
  });

  group('HangingPunctuationRule', () {
    test('opening quote after indent hangs', () {
      expect(
        HangingPunctuationRule.shouldHang(
          ['　', '　', '“', '字'].toList(),
          2,
        ),
        isTrue,
      );
    });

    test('ordinary char after indent does not hang', () {
      expect(
        HangingPunctuationRule.shouldHang(
          ['　', '　', '字'],
          2,
        ),
        isFalse,
      );
    });

    test('no indent never hangs', () {
      expect(
        HangingPunctuationRule.shouldHang(['“', '字'], 0),
        isFalse,
      );
    });

    test('closing punctuation does not hang', () {
      expect(
        HangingPunctuationRule.shouldHang(['　', '　', '”'], 2),
        isFalse,
      );
    });

    test('RTL paragraph does not hang', () {
      expect(
        HangingPunctuationRule.shouldHang(
          ['　', '　', '“', 'ا', 'ب'],
          2,
        ),
        isFalse,
      );
    });

    test('neutral chars before the first strong LTR still hang', () {
      expect(
        HangingPunctuationRule.shouldHang(
          ['　', '　', '“', '1', '2', '字'],
          2,
        ),
        isTrue,
      );
    });
  });
}
