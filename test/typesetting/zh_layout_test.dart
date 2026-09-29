import 'package:flutter_test/flutter_test.dart';
import 'package:masiro/ui/screens/reader/typesetting/zh_layout.dart';

void main() {
  const capacity = 300.0;
  const em = 100.0;

  List<ZhLineBreak> run(List<String> words, List<double> widths,
          {double firstLineExtra = 0, int indentUnits = 0}) =>
      ZhLineBreaker.breakLines(
        words: words,
        widths: widths,
        capacity: capacity,
        emWidth: em,
        firstLineExtra: firstLineExtra,
        indentUnits: indentUnits,
      );

  void expectRange(ZhLineBreak b, int start, int end, double width) {
    expect(b.start, start);
    expect(b.end, end);
    expect(b.width, closeTo(width, epsilon));
  }

  group('TR-3.1 six BreakMod decisions', () {
    test('NORMAL breaks before the overflowing unit', () {
      final lines = run('字字字字'.split(''), [100, 100, 100, 100]);
      expect(lines, hasLength(2));
      expectRange(lines[0], 0, 3, 300);
      expect(lines[0].endMod, BreakMod.normal);
      expectRange(lines[1], 3, 4, 100);
      expect(lines[1].endMod, isNull);
    });

    test('BREAK_ONE_CHAR pulls the opening punctuation down', () {
      final lines = run('字字“字'.split(''), [100, 100, 100, 100]);
      expect(lines, hasLength(2));
      expectRange(lines[0], 0, 2, 200);
      expect(lines[0].endMod, BreakMod.breakOneChar);
      expectRange(lines[1], 2, 4, 200);
    });

    test('CPS_1 keeps two closing marks via compression tolerance', () {
      // Three narrow units + two full-em close marks: 150 + 200 = 350,
      // i.e. capacity + 0.5em.
      final lines =
          run('aaa。。'.split(''), [50, 50, 50, 100, 100]);
      expect(lines, hasLength(1));
      expectRange(lines[0], 0, 5, 350);
      expect(lines[0].endMod, BreakMod.cps1);
    });

    test('CPS_2 keeps two opening marks via compression tolerance', () {
      final lines = run('a“““'.split(''), [50, 100, 100, 100]);
      expect(lines, hasLength(1));
      expectRange(lines[0], 0, 4, 350);
      expect(lines[0].endMod, BreakMod.cps2);
    });

    test('CPS_3 keeps open + unit + close via compression tolerance', () {
      final lines = run('a“字。'.split(''), [50, 100, 100, 100]);
      expect(lines, hasLength(1));
      expectRange(lines[0], 0, 4, 350);
      expect(lines[0].endMod, BreakMod.cps3);
    });

    test('BREAK_MORE_CHAR walks back over compressed punctuation', () {
      // Two close marks already compressed to 80 (< em) cannot give up
      // more width: the re-check walk pulls them and the preceding narrow
      // unit down together.
      final lines = run(
        'aaaa。。'.split(''),
        [50, 50, 50, 50, 80, 80],
      );
      expect(lines, hasLength(2));
      expectRange(lines[0], 0, 3, 150);
      expect(lines[0].endMod, BreakMod.breakMoreChar);
      expectRange(lines[1], 3, 6, 210);
    });
  });

  group('TR-3.2 kinsoku invariants (exhaustive short sequences)', () {
    // Ordinary em unit, narrow ASCII-like unit, one opening and one
    // closing mark. Every sequence up to length 6 is enumerated.
    const alphabet = <(String, double)>[
      ('字', 100),
      ('a', 50),
      ('“', 100),
      ('。', 100),
    ];

    Iterable<List<int>> sequences(int length, int radix) sync* {
      if (length == 0) {
        yield <int>[];
        return;
      }
      for (final rest in sequences(length - 1, radix)) {
        for (var i = 0; i < radix; i++) {
          yield [...rest, i];
        }
      }
    }

    test('no close at line start / open at line end outside CPS', () {
      for (var length = 1; length <= 6; length++) {
        for (final picks in sequences(length, alphabet.length)) {
          final words = [for (final i in picks) alphabet[i].$1];
          final widths = [for (final i in picks) alphabet[i].$2];
          final lines = run(words, widths);

          // Ranges tile the whole paragraph.
          expect(lines.first.start, 0);
          for (var i = 1; i < lines.length; i++) {
            expect(lines[i].start, lines[i - 1].end);
          }
          expect(lines.last.end, length);

          for (var li = 0; li < lines.length; li++) {
            final line = lines[li];
            final isNaturalLast = li == lines.length - 1 &&
                line.endMod == null;
            if (line.isCompressionTolerated) {
              // The overflow added at most one em to a previously full
              // line; real absorption to within +0.5em happens at the
              // line-end compression stage.
              expect(
                line.width,
                lessThanOrEqualTo(capacity + em + epsilon),
                reason: 'CPS line exceeds capacity + em: '
                    '$words -> $line',
              );
              continue;
            }
            if (isNaturalLast) continue;
            expect(
              ZhLineBreaker.postPunctuation.contains(words[line.start]),
              isFalse,
              reason: 'line starts with a closing mark in $words: '
                  '$line',
            );
            expect(
              ZhLineBreaker.prePunctuation
                  .contains(words[line.end - 1]),
              isFalse,
              reason: 'line ends with an opening mark in $words: '
                  '$line',
            );
            expect(
              line.width,
              lessThanOrEqualTo(capacity + epsilon),
              reason: 'hard-broken line over capacity in $words: $line',
            );
          }
        }
      }
    });
  });

  group('TR-3.3 width capacity', () {
    test('hard-broken lines never exceed capacity', () {
      const words = ['字', '。', 'a', '“', '字', '，', '字', '字', '”'];
      const widths = [100.0, 100, 50, 100, 100, 100, 100, 100, 80];
      final lines = run(words, widths);
      for (final line in lines) {
        final tolerance = line.isCompressionTolerated ? em / 2 : 0.0;
        expect(
          line.width,
          lessThanOrEqualTo(capacity + tolerance + epsilon),
          reason: 'line $line over capacity',
        );
      }
    });

    test('first line uses the hanging extra width', () {
      // 4 em units fit exactly once the hung punctuation frees one em.
      final lines = run(
        '字字字字'.split(''),
        [100, 100, 100, 100],
        firstLineExtra: 100,
      );
      expect(lines, hasLength(1));
      expectRange(lines[0], 0, 4, 400);
    });

    test('ranges cover every unit exactly once', () {
      final lines = run(
        '字。字“字，字'.split(''),
        [100, 100, 100, 100, 100, 100, 100],
      );
      var cursor = 0;
      for (final line in lines) {
        expect(line.start, cursor);
        cursor = line.end;
      }
      expect(cursor, 7);
    });
  });
}
