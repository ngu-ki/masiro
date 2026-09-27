import 'package:equatable/equatable.dart';
import 'package:masiro/data/repository/model/volume.dart';

class ChapterDetail extends Equatable {
  final int chapterId;
  final String title;
  final ChapterContent content;
  final String textContent;
  final List<Volume> volumes;
  final String csrfToken;

  final PaymentInfo? paymentInfo;

  const ChapterDetail({
    required this.chapterId,
    required this.title,
    required this.content,
    required this.textContent,
    required this.csrfToken,
    required this.volumes,
    required this.paymentInfo,
  });

  @override
  List<Object?> get props => [
        chapterId,
        title,
        content,
        textContent,
        volumes,
        csrfToken,
      ];
}

class ChapterContent extends Equatable {
  final List<ChapterContentElement> elements;

  const ChapterContent({required this.elements});

  @override
  List<Object?> get props => [elements];
}

sealed class ChapterContentElement extends Equatable {}

/// A half-open character range `[start, end)` within [TextContent.text]
/// carrying the color (ARGB value) declared by the source markup.
typedef ColoredRange = ({int start, int end, int color});

class TextContent extends ChapterContentElement {
  final String text;

  /// Ranges of [text] that carry an explicitly declared source color (e.g.
  /// inline colored spans or `<font color>` tags), each with its ARGB
  /// value. How they are rendered depends on the reader's text color mode.
  final List<ColoredRange> coloredRanges;

  TextContent({required this.text, this.coloredRanges = const []});

  TextContent copyWith({String? text, List<ColoredRange>? coloredRanges}) {
    return TextContent(
      text: text ?? this.text,
      coloredRanges: coloredRanges ?? this.coloredRanges,
    );
  }

  @override
  List<Object?> get props => [text, coloredRanges];
}

class ImageContent extends ChapterContentElement {
  final String src;

  ImageContent({required this.src});

  @override
  List<Object?> get props => [src];
}

class PaymentInfo extends Equatable {
  final int cost;
  final int type;
  final int chapterId;

  const PaymentInfo({
    required this.cost,
    required this.type,
    required this.chapterId,
  });

  @override
  List<Object?> get props => [
        cost,
        type,
        chapterId,
      ];
}
