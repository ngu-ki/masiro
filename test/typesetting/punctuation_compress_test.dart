import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masiro/ui/screens/reader/typesetting/punctuation_compress.dart';
import 'package:masiro/ui/screens/reader/typesetting/text_measure.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_models.dart';

class _FakeInk implements PunctuationInkProvider {
  _FakeInk(this.spaces, {this.fallbackLeft = 0, this.fallbackRight = 0});

  /// char -> (leftSpace, rightSpace) inside the em box.
  final Map<String, (double, double)> spaces;
  final double fallbackLeft;
  final double fallbackRight;

  @override
  PunctuationInk sideSpaces(String char) {
    final value = spaces[char];
    return (
      leftSpace: value?.$1 ?? fallbackLeft,
      rightSpace: value?.$2 ?? fallbackRight,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ahem makes every glyph exactly the font size wide: em == 20 here.
  const em = 20.0;
  late TextMeasure measure;

  GlyphUnit g(String ch, {double? width, int start = 0}) {
    return GlyphUnit(
      text: ch,
      elementIndex: 0,
      charStart: start,
      charEnd: start + ch.length,
      width: width ?? em,
    );
  }

  setUp(() {
    measure = TextMeasure(const TextStyle(fontSize: em));
  });

  tearDown(() => measure.dispose());

  group('TR-2.1 adjacent compression', () {
    test('：“ squeezes both marks by their blank side', () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({
          '：': (1, 6), // blank on the right -> trim right
          '“': (6, 1), // blank on the left -> trim left
        }),
      );
      final units = [g('字'), g('：'), g('“'), g('字')];
      compressor.beginParagraph(units);

      expect(units[1].compressed, isTrue);
      expect(units[2].compressed, isTrue);
      expect(units[1].width, closeTo(em - 6, epsilon));
      expect(units[2].width, closeTo(em - 6, epsilon));
      // Right trim keeps the glyph put; left trim shifts it left.
      expect(units[1].drawOffset, 0);
      expect(units[2].drawOffset, closeTo(-6, epsilon));
      for (final u in [units[1], units[2]]) {
        expect(em - u.width, greaterThan(0));
        expect(em - u.width, lessThanOrEqualTo(em / 2));
      }
    });

    test('。” compresses the period but not the final quote', () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({'。': (1, 5), '”': (5, 1)}),
      );
      final units = [g('字'), g('。'), g('”')];
      compressor.beginParagraph(units);

      expect(units[1].compressed, isTrue);
      expect(units[2].compressed, isFalse);
      expect(units[1].width, closeTo(em - 5, epsilon));
      expect(units[2].width, em);
    });

    test('》（ squeezes both, trim is clamped to 0.5em', () {
      final compressor = PunctuationCompressor(
        measure: measure,
        // Blank space larger than the box: only half an em may be trimmed.
        ink: _FakeInk({
          '》': (2, 18),
          '（': (18, 2),
        }),
      );
      final units = [g('》'), g('（')];
      compressor.beginParagraph(units);

      expect(units[0].width, closeTo(em / 2, epsilon));
      expect(units[1].width, closeTo(em / 2, epsilon));
    });

    test('balanced margins trim both sides and centre the glyph', () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({
          '：': (5, 5),
          '“': (5, 5),
        }),
      );
      final units = [g('：'), g('“')];
      compressor.beginParagraph(units);

      expect(units[0].compressed, isTrue);
      expect(units[0].drawOffset, closeTo(-5, epsilon));
      expect(units[0].width, closeTo(em - 10, epsilon));
    });

    test('narrow punctuation is left untouched', () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({}, fallbackLeft: 8, fallbackRight: 8),
      );
      // Width below 0.9em: compressing would push ink onto a neighbour.
      final units = [g('，', width: em * 0.8), g('“', width: em * 0.8)];
      compressor.beginParagraph(units);

      expect(units[0].compressed, isFalse);
      expect(units[1].compressed, isFalse);
      expect(units[0].width, em * 0.8);
    });

    test('dashes and ellipses are never compressed', () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({}, fallbackLeft: 9, fallbackRight: 9),
      );

      final dash = [g('—'), g('—')];
      compressor.beginParagraph(dash);
      expect(dash.every((u) => !u.compressed), isTrue);

      // Not eligible for line-end compression either.
      expect(
        compressor.compressLineEnd([g('字'), g('—')],
            isParagraphLast: false),
        isFalse,
      );

      final ellipsis = [g('…'), g('…')];
      compressor.beginParagraph(ellipsis);
      expect(ellipsis.every((u) => !u.compressed), isTrue);
    });
  });

  group('TR-2.2 ink boxes never overlap', () {
    test('adjacent-squeezed line: every ink box stays inside its column',
        () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({
          '：': (1, 6),
          '“': (6, 1),
          '。': (1, 5),
          '”': (5, 1),
        }),
      );
      const text = '字：“字。”字';
      final units = [
        for (var i = 0; i < text.length; i++) g(text[i], start: i),
      ];
      compressor.beginParagraph(units);

      final inkSpaces = {
        '：': (1.0, 6.0),
        '“': (6.0, 1.0),
        '。': (1.0, 5.0),
        '”': (5.0, 1.0),
      };

      // Lay columns out naturally using the compressed advances.
      final left = List<double>.filled(units.length, 0);
      var x = 0.0;
      for (var i = 0; i < units.length; i++) {
        left[i] = x;
        x += units[i].width;
      }

      for (var i = 0; i + 1 < units.length; i++) {
        final originalWidth = em;
        final (l0, r0) = inkSpaces[units[i].text] ?? (0.0, 0.0);
        final (l1, _) = inkSpaces[units[i + 1].text] ?? (0.0, 0.0);
        final inkRight =
            left[i] + units[i].drawOffset + originalWidth - r0;
        final nextInkLeft = left[i + 1] + units[i + 1].drawOffset + l1;
        expect(
          inkRight,
          lessThanOrEqualTo(nextInkLeft + 0.001),
          reason: 'ink of ${units[i].text} overlaps ${units[i + 1].text}',
        );
      }
    });
  });

  group('TR-2.3 line-end compression', () {
    test('only non-final lines get their trailing close mark squeezed', () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({'。': (1, 6)}),
      );
      final paragraph = [g('字'), g('。'), g('字'), g('。')];
      compressor.beginParagraph(paragraph);

      final line1 = [paragraph[0], paragraph[1]];
      final line2 = [paragraph[2], paragraph[3]];

      expect(
        compressor.compressLineEnd(line1, isParagraphLast: false),
        isTrue,
      );
      expect(line1[1].compressed, isTrue);

      final lastWidth = line2[1].width;
      expect(
        compressor.compressLineEnd(line2, isParagraphLast: true),
        isFalse,
      );
      expect(line2[1].width, lastWidth);
      expect(line2[1].compressed, isFalse);
    });

    test('a mark already squeezed in-paragraph is not squeezed again', () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({'。': (1, 6), '“': (6, 1)}),
      );
      // Line ends in 。 and the next (visual) line starts with “: the
      // period was already squeezed by the adjacent-pass across the break.
      final paragraph = [g('字'), g('。'), g('“'), g('字')];
      compressor.beginParagraph(paragraph);
      expect(paragraph[1].compressed, isTrue);

      final line = [paragraph[0], paragraph[1]];
      final widthAfterAdjacent = line[1].width;
      expect(
        compressor.compressLineEnd(line, isParagraphLast: false),
        isFalse,
      );
      expect(line[1].width, widthAfterAdjacent);
    });

    test('trailing spaces are skipped when finding the last visible unit',
        () {
      final compressor = PunctuationCompressor(
        measure: measure,
        ink: _FakeInk({'。': (1, 6)}),
      );
      final units = [g('字'), g('。'), g(' ')];
      compressor.beginParagraph(units);

      expect(
        compressor.compressLineEnd(units, isParagraphLast: false),
        isTrue,
      );
      expect(units[1].compressed, isTrue);
    });
  });
}
