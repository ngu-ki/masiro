/// How an over-full line was resolved, mirroring legado's
/// `ZhLayout.BreakMod`.
enum BreakMod {
  /// Break before the current unit.
  normal,

  /// The previous unit (an opening punctuation) is pulled down too.
  breakOneChar,

  /// Multiple units are pulled down after a re-check walk.
  breakMoreChar,

  /// Two trailing closing punctuation marks are compressed onto the line.
  cps1,

  /// Two leading opening punctuation marks are compressed onto the line.
  cps2,

  /// Opening mark + unit + closing mark compressed onto the line.
  cps3,
}

/// One broken line: the half-open unit range `[start, end)` plus its
/// natural (post-compression) width.
class ZhLineBreak {
  final int start;
  final int end;
  final double width;

  /// The break decision that ended this line; null for the paragraph's
  /// natural final line.
  final BreakMod? endMod;

  const ZhLineBreak({
    required this.start,
    required this.end,
    required this.width,
    this.endMod,
  });

  /// Whether this line was finalized by punctuation-compression tolerance
  /// rather than a hard break; its width may slightly exceed capacity.
  bool get isCompressionTolerated =>
      endMod == BreakMod.cps1 ||
      endMod == BreakMod.cps2 ||
      endMod == BreakMod.cps3;
}

/// Chinese line breaking with kinsoku rules, a port of legado's
/// `ZhLayout` init algorithm.
///
/// Inputs are pure data (unit texts, already-compressed widths) so the
/// whole decision table is unit-testable without Flutter. Unit indices
/// are used everywhere (legado mixed in string offsets, which only
/// happened to work for single-char CJK words).
class ZhLineBreaker {
  const ZhLineBreaker._();

  /// 后置标点: forbidden at line start.
  static final Set<String> postPunctuation = <String>{
    '，', '。', '：', '？', '！', '、', '”', '’', '）', '》', '}',
    '】', ')', '>', ']', ',', '.', '?', '!', ':', '」', '；', ';',
  };

  /// 前置标点: forbidden at line end.
  static final Set<String> prePunctuation = <String>{
    '“', '（', '《', '【', '‘', '(', '<', '[', '{', '「',
  };

  static bool _isPost(String unit) => postPunctuation.contains(unit);

  static bool _isPre(String unit) => prePunctuation.contains(unit);

  /// A unit narrower than a full em is treated as already compressed and
  /// therefore unable to give up more width; CPS decisions involving it
  /// fall back to a re-check.
  static bool _inCompressible(double width, double emWidth) =>
      width < emWidth;

  /// Breaks [words] into lines that fit [capacity].
  ///
  /// - [widths] must be the post-adjacent-compression advances.
  /// - [indentUnits] is the number of leading indentation columns on the
  ///   first line; the re-check walk never pulls those columns down.
  /// - [firstLineExtra] is the width freed by a hung opening punctuation;
  ///   the first line may use [capacity] + that amount.
  static List<ZhLineBreak> breakLines({
    required List<String> words,
    required List<double> widths,
    required double capacity,
    required double emWidth,
    int indentUnits = 0,
    double firstLineExtra = 0,
  }) {
    assert(words.length == widths.length);
    final result = <ZhLineBreak>[];
    if (words.isEmpty) return result;

    var currentStart = 0;
    var line = 0;
    var lineW = 0.0;
    var cwPre = 0.0;

    for (var index = 0; index < words.length; index++) {
      final cw = widths[index];
      lineW += cw;
      var breakLine = false;
      var offset = 0.0;
      var breakCharCnt = 0;
      var nextStart = 0;
      var mod = BreakMod.normal;

      final lineCapacity = line == 0 ? capacity + firstLineExtra : capacity;
      if (lineW > lineCapacity) {
        // Unit before the overflow is an opening punctuation that must
        // not end the line.
        if (index >= 1 && _isPre(words[index - 1])) {
          if (index >= 2 && _isPre(words[index - 2])) {
            mod = BreakMod.cps2;
          } else {
            mod = BreakMod.breakOneChar;
          }
        } else if (_isPost(words[index])) {
          // Current unit is a closing punctuation that must not start a
          // line.
          if (index >= 1 && _isPost(words[index - 1])) {
            mod = BreakMod.cps1;
          } else if (index >= 2 && _isPre(words[index - 2])) {
            mod = BreakMod.cps3;
          } else {
            mod = BreakMod.breakOneChar;
          }
        } else {
          mod = BreakMod.normal;
        }

        // Special punctuation sequences cannot be trusted to fit: walk
        // backwards until an ordinary break position is found.
        var reCheck = false;
        if (mod == BreakMod.cps1 &&
            (_inCompressible(widths[index], emWidth) ||
                _inCompressible(widths[index - 1], emWidth))) {
          reCheck = true;
        }
        if (mod == BreakMod.cps2 &&
            (index >= 1 && _inCompressible(widths[index - 1], emWidth) ||
                index >= 2 && _inCompressible(widths[index - 2], emWidth))) {
          reCheck = true;
        }
        if (mod == BreakMod.cps3 &&
            (_inCompressible(widths[index], emWidth) ||
                _inCompressible(widths[index - 2], emWidth))) {
          reCheck = true;
        }
        if ((mod == BreakMod.cps1 ||
                mod == BreakMod.cps2 ||
                mod == BreakMod.cps3) &&
            index < words.length - 1 &&
            _isPost(words[index + 1])) {
          reCheck = true;
        }

        if (reCheck && index > 2) {
          final startPos = line == 0 ? indentUnits : currentStart;
          mod = BreakMod.normal;
          var breakIndex = 0;
          var movedUnits = 0;
          cwPre = 0.0;
          for (var i = index; i >= 1 + startPos; i--) {
            if (i == index) {
              breakIndex = 0;
              cwPre = 0.0;
            } else {
              breakIndex++;
              movedUnits++;
              cwPre += widths[i];
            }
            if (!_isPost(words[i]) && !_isPre(words[i - 1])) {
              mod = BreakMod.breakMoreChar;
              break;
            }
          }
          if (mod == BreakMod.breakMoreChar) {
            offset = cw + cwPre;
            nextStart = index - movedUnits;
            breakCharCnt = breakIndex + 1;
          } else {
            // No valid position found: fall back to a normal break.
            offset = cw;
            nextStart = index;
            breakCharCnt = 1;
            mod = BreakMod.normal;
          }
        } else {
          switch (mod) {
            case BreakMod.normal:
              offset = cw;
              nextStart = index;
              breakCharCnt = 1;
            case BreakMod.breakOneChar:
              offset = cw + cwPre;
              nextStart = index - 1;
              breakCharCnt = 2;
            case BreakMod.breakMoreChar:
              throw StateError('unreachable');
            case BreakMod.cps1:
            case BreakMod.cps2:
            case BreakMod.cps3:
              offset = 0;
              nextStart = index + 1;
              breakCharCnt = 0;
          }
        }
        breakLine = true;
      }

      if (breakLine) {
        result.add(
          ZhLineBreak(
            start: currentStart,
            end: nextStart,
            width: lineW - offset,
            endMod: mod,
          ),
        );
        lineW = offset;
        currentStart = nextStart;
        line++;
      }

      if (index == words.length - 1) {
        if (!breakLine) {
          // Natural paragraph ending.
          result.add(
            ZhLineBreak(
              start: currentStart,
              end: words.length,
              width: lineW,
            ),
          );
        } else if (breakCharCnt > 0) {
          // The units pulled down by the final overflow form their own
          // trailing line.
          result.add(
            ZhLineBreak(
              start: currentStart,
              end: words.length,
              width: lineW,
            ),
          );
        }
      }

      cwPre = cw;
    }

    return result;
  }
}
