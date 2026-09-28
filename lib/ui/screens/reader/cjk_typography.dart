import 'package:flutter/widgets.dart';

/// 开类标点：字形居左半、空白在右半。
/// 压缩方式：给标点自身加负 letterSpacing，让后一个字左移半格进入
/// 其右侧空白区，不会碰到字形。
const String cjkOpeningPunctuation = '‘“「『（【《〈';

/// 闭类与句读标点：字形居右半（句读类居左下）、空白在左半。
/// 压缩方式：给前一个字符加负 letterSpacing，让标点自身左移半格进入
/// 其左侧空白区。绝不能反向把后一个字拉近——那会撞进标点的字形区。
const String cjkClosingPunctuation = '’”」』）】》〉，。、；：？！';

/// 按中文网格排版规则压缩全角标点（“推入式”标点压缩）：
///
/// - 开类标点与其后字符各让出半格空白，合占空间缩小半格；
/// - 闭类/句读标点自身左移半格，贴近前一个字；
/// - 连续标点不会叠加压缩量（最多半格），因此任何标点的字形边缘
///   都不会与相邻汉字或其他标点的字形边缘重叠；
/// - 破折号 —— 与省略号 …… 字形占满全角，不在压缩范围内。
///
/// 分页测量与页面渲染必须使用同一套 span，否则断行位置不一致。
List<InlineSpan> buildCompressedPunctuationSpans(
  String text, {
  required double fontSize,
}) {
  final compressStyle = TextStyle(letterSpacing: -fontSize / 2);

  bool isOpening(int rune) => cjkOpeningPunctuation.runes.contains(rune);
  bool isClosing(int rune) => cjkClosingPunctuation.runes.contains(rune);

  if (!text.runes.any((r) => isOpening(r) || isClosing(r))) {
    return [TextSpan(text: text)];
  }

  final spans = <TextSpan>[];
  final buffer = StringBuffer();

  void flushBuffer() {
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }
  }

  /// 让即将写入的闭类/句读标点左移半格：把前一个字符拆出来，
  /// 单独加上负 letterSpacing。若前一个字符已是带压缩的开类标点，
  /// 其右侧压缩恰好等价于本标点的左移，不再叠加。
  void retractPreviousCharacter() {
    if (buffer.isNotEmpty) {
      final text = buffer.toString();
      final lastChar = String.fromCharCode(text.runes.last);
      final head = text.substring(0, text.length - lastChar.length);
      buffer.clear();
      if (head.isNotEmpty) {
        spans.add(TextSpan(text: head));
      }
      spans.add(TextSpan(text: lastChar, style: compressStyle));
      return;
    }
    if (spans.isEmpty) {
      // 片段开头就是闭类标点（跨页断行处），无法左移，跳过压缩。
      return;
    }
    final last = spans.last;
    if (last.style != null) {
      // 已是开类标点的压缩 span，右侧半格空白正好供本标点使用。
      return;
    }
    final text = last.text!;
    final lastChar = String.fromCharCode(text.runes.last);
    final head = text.substring(0, text.length - lastChar.length);
    spans.removeLast();
    if (head.isNotEmpty) {
      spans.add(TextSpan(text: head));
    }
    spans.add(TextSpan(text: lastChar, style: compressStyle));
  }

  var previousWasClosing = false;
  for (final rune in text.runes) {
    if (isOpening(rune)) {
      // 句读/闭类标点后紧跟开类标点（如 ：“）时，先让开类标点
      // 左移半格贴近前一个标点，两者合占一个字位。
      if (previousWasClosing) {
        retractPreviousCharacter();
      }
      flushBuffer();
      spans.add(
        TextSpan(text: String.fromCharCode(rune), style: compressStyle),
      );
      previousWasClosing = false;
    } else if (isClosing(rune)) {
      retractPreviousCharacter();
      buffer.writeCharCode(rune);
      previousWasClosing = true;
    } else {
      buffer.writeCharCode(rune);
      previousWasClosing = false;
    }
  }
  flushBuffer();
  return spans;
}
