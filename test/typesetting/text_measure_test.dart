import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masiro/ui/screens/reader/typesetting/text_measure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextMeasure cluster splitting', () {
    test('TR-1.1 keeps emoji ZWJ sequences and combining marks intact', () {
      final measure = TextMeasure(const TextStyle(fontSize: 21.0));
      addTearDown(measure.dispose);

      // ASCII + CJK + emoji ZWJ family + e + combining acute + full-width
      // punctuation.
      const text = 'A中👨‍👩‍👧e\u0301，';
      final units = measure.measureUnits(text: text, elementIndex: 7);

      expect(units, hasLength(5));
      expect(units.map((u) => u.text), ['A', '中', '👨‍👩‍👧', 'e\u0301', '，']);
      expect(units.every((u) => u.elementIndex == 7), isTrue);

      // A width value exists for every unit.
      final widths = units.map((u) => u.width).toList();
      expect(widths, hasLength(units.length));
    });

    test('TR-1.3 zero-width chars merge into neighbouring units', () {
      final measure = TextMeasure(const TextStyle(fontSize: 22.0));
      addTearDown(measure.dispose);

      // ZWSP after A, ZWNJ after B: both merge backwards.
      final units = measure.measureUnits(text: 'A\u200BB\u200C中', elementIndex: 0);
      expect(units, hasLength(3));
      expect(units[0].text, 'A\u200B');
      expect(units[0].charStart, 0);
      expect(units[0].charEnd, 2);
      expect(units[1].text, 'B\u200C');
      expect(units[1].charStart, 2);
      expect(units[1].charEnd, 4);
      expect(units[2].text, '中');
      expect(units[2].charStart, 4);

      // Leading zero-width cluster merges forwards.
      final leading = measure.measureUnits(text: '\u200BA', elementIndex: 1);
      expect(leading, hasLength(1));
      expect(leading.single.text, '\u200BA');
      expect(leading.single.charStart, 0);
      expect(leading.single.charEnd, 2);

      // ZWJ outside an emoji sequence merges as well.
      final zwj = measure.measureUnits(text: 'A\u200DB', elementIndex: 2);
      expect(zwj, hasLength(2));
      expect(zwj[0].text, 'A\u200D');
    });

    test('UTF-16 offsets are correct across surrogate pairs', () {
      final measure = TextMeasure(const TextStyle(fontSize: 23.0));
      addTearDown(measure.dispose);

      final units = measure.measureUnits(text: 'A😀B', elementIndex: 3);
      expect(units, hasLength(3));
      expect(units[0].charStart, 0);
      expect(units[0].charEnd, 1);
      // 😀 occupies two UTF-16 code units.
      expect(units[1].charStart, 1);
      expect(units[1].charEnd, 3);
      expect(units[2].charStart, 3);
      expect(units[2].charEnd, 4);
    });
  });

  group('TextMeasure caching', () {
    test('TR-1.2 common CJK ideographs share the width of 一', () {
      // Distinctive font size so the assertions are independent of static
      // cache state left by other tests.
      final measure = TextMeasure(const TextStyle(fontSize: 18.5));
      addTearDown(measure.dispose);

      final yi = measure.measureCluster('一');
      expect(measure.measureCluster('我'), yi);
      expect(measure.measureCluster('汉'), yi);
      expect(measure.measureCluster('字'), yi);

      // indentCharWidth is the width of one full-width space, also an em.
      expect(measure.indentCharWidth, yi);
    });

    test('TR-1.2 repeated and shared measurements hit the cache', () {
      final measure = TextMeasure(const TextStyle(fontSize: 19.25));
      addTearDown(measure.dispose);

      measure.measureCluster('一');
      final hitsAfterYi = measure.cacheHits;

      // 我 reuses the shared CJK width: one hit.
      measure.measureCluster('我');
      expect(measure.cacheHits, hitsAfterYi + 1);

      // Second look-up of 我 is a plain cache hit.
      measure.measureCluster('我');
      expect(measure.cacheHits, hitsAfterYi + 2);

      // ASCII punctuation paints once, then hits the cache.
      measure.measureCluster(',');
      final hitsAfterComma = measure.cacheHits;
      measure.measureCluster(',');
      expect(measure.cacheHits, hitsAfterComma + 1);
    });

    test('different font sizes produce independent widths', () {
      final small = TextMeasure(const TextStyle(fontSize: 10.0));
      final large = TextMeasure(const TextStyle(fontSize: 30.0));
      addTearDown(small.dispose);
      addTearDown(large.dispose);

      expect(large.measureCluster('A') > small.measureCluster('A'), isTrue);
    });
  });
}
