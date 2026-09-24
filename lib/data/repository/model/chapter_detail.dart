import 'package:equatable/equatable.dart';
import 'package:masiro/data/repository/model/volume.dart';

class ChapterDetail extends Equatable {
  final int chapterId;
  final String title;
  final String? novelTitle;
  final ChapterContent content;
  final String textContent;
  final List<Volume> volumes;
  final String csrfToken;

  final PaymentInfo? paymentInfo;

  const ChapterDetail({
    required this.chapterId,
    required this.title,
    this.novelTitle,
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
        novelTitle,
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

/// A half-open character range `[start, end)` within [TextContent.text].
typedef MutedRange = ({int start, int end});

class TextContent extends ChapterContentElement {
  final String text;

  /// Ranges of [text] whose source color is non-black (e.g. inline colored
  /// spans). They are rendered in a muted gray instead of the body color.
  final List<MutedRange> mutedRanges;

  TextContent({required this.text, this.mutedRanges = const []});

  TextContent copyWith({String? text, List<MutedRange>? mutedRanges}) {
    return TextContent(
      text: text ?? this.text,
      mutedRanges: mutedRanges ?? this.mutedRanges,
    );
  }

  @override
  List<Object?> get props => [text, mutedRanges];
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
