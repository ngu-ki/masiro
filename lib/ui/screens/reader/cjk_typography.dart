import 'package:flutter/widgets.dart';

/// Full-width CJK punctuation that can share an em square with an adjacent
/// punctuation, i.e. it is set at half-em advance ("标点压缩").
///
/// Opening brackets carry their blank half on the right, closing ones on
/// the left, so pulling the following character half an em in never
/// overlaps the glyph itself. The em dash (—) and ellipsis (…) are
/// intentionally excluded: their glyphs fill the whole square, so a
/// negative advance would overlap adjacent glyphs.
const String cjkCompressiblePunctuation =
    '，。、；：？！' // 句读类
    '‘’“”' // 弯引号
    '「」『』' // 直角引号
    '（）【】《》〈〉'; // 括号类

/// Whether [character] is a compressible full-width punctuation mark.
bool isCompressiblePunctuation(String character) =>
    character.length == 1 &&
    cjkCompressiblePunctuation.contains(character);

/// Splits [text] into inline spans where every compressible punctuation
/// mark carries a negative half-em [TextStyle.letterSpacing], so the next
/// character is pulled into the punctuation's blank half.
///
/// Two adjacent punctuation marks therefore occupy one em square instead
/// of two, matching the push-in punctuation handling used by grid-based
/// Chinese readers. The spans inherit every other property of the
/// surrounding text style, so [parentStyle] (including color) keeps
/// applying; the returned list is meant to be nested inside another
/// [TextSpan].
///
/// The same spans must be used both for pagination measurement and for
/// rendering, otherwise line breaks computed by the [TextPainter] would
/// not match what is shown.
List<InlineSpan> buildCompressedPunctuationSpans(
  String text, {
  required double fontSize,
}) {
  if (!text.runes.any(_isCompressibleCodePoint)) {
    return [TextSpan(text: text)];
  }

  final halfEmCompression = TextStyle(letterSpacing: -fontSize / 2);
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();

  void flushPlain() {
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }
  }

  for (final rune in text.runes) {
    if (_isCompressibleCodePoint(rune)) {
      flushPlain();
      spans.add(
        TextSpan(
          text: String.fromCharCode(rune),
          style: halfEmCompression,
        ),
      );
    } else {
      buffer.writeCharCode(rune);
    }
  }
  flushPlain();
  return spans;
}

bool _isCompressibleCodePoint(int rune) {
  if (rune < 0x2000) {
    return false;
  }
  return cjkCompressiblePunctuation.runes.contains(rune);
}
