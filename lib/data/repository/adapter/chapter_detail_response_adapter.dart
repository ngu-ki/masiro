import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:masiro/data/network/response/chapter_detail_response.dart';
import 'package:masiro/data/repository/adapter/volume_response_adapter.dart';
import 'package:masiro/data/repository/model/chapter_detail.dart';

ChapterDetail chapterDetailResponseToChapterDetail(ChapterDetailResponse d) {
  final volumes = volumeResponseToVolumeList(d.volumes, d.chapters);
  final chapterContent = _htmlToChapterContent(d.rawHtml);
  final paymentInfo = d.paymentInfo == null
      ? null
      : _paymentInfoResponseToPaymentInfo(d.paymentInfo!);
  return ChapterDetail(
    chapterId: d.chapterId,
    title: d.title,
    novelTitle: d.novelTitle,
    content: chapterContent,
    textContent: d.textContent,
    csrfToken: d.csrfToken,
    volumes: volumes,
    paymentInfo: paymentInfo,
  );
}

PaymentInfo _paymentInfoResponseToPaymentInfo(PaymentInfoResponse response) {
  return PaymentInfo(
    cost: response.cost,
    type: response.type,
    chapterId: response.chapterId,
  );
}

ChapterContent _htmlToChapterContent(String html) {
  final document = parse(html);
  final contentNode = document.querySelector('.nvl-content');
  final List<ChapterContentElement> elements = [];

  // Extract all text and images from the `contentNode`
  for (final node in contentNode?.nodes ?? []) {
    // Ignore blank text nodes that are children of `contentNode`
    if (node.nodeType == Node.TEXT_NODE &&
        (node.text?.trim().isEmpty ?? true)) {
      continue;
    }

    // Extract text from a text node child
    if (node.nodeType == Node.TEXT_NODE) {
      final text = node.text ?? '';
      elements.add(TextContent(text: text));
      continue;
    }

    // Extract image from an image node child
    if (node.nodeType == Node.ELEMENT_NODE &&
        (node as Element).localName == 'img') {
      final src = node.attributes['src'] ?? '';
      elements.add(ImageContent(src: src));
      continue;
    }

    // For non-text and non-image element nodes, traverse the node to extract its text and images
    if (node.nodeType == Node.ELEMENT_NODE &&
        (node as Element).localName != 'img') {
      final List<ChapterContentElement> elementsOfNode = [];
      _traverseNodeToExtractContent(node, elementsOfNode);
      elements.addAll(elementsOfNode);
    }
  }

  return ChapterContent(elements: elements);
}

/// Recursively traverses the given [node] to extract all text and image content.
/// Text nodes are combined with the previous text node if it exists to form a single `TextContent`.
/// Image nodes are extracted as `ImageContent`.
/// The extracted content is added to [contentElementList].
///
/// [muted] indicates that the node inherits a non-black inline color, in which
/// case its text ranges are recorded for muted (gray) rendering.
///
/// Example:
/// ```
/// input: '<p>he<span>llo</span> <img src="123"> <span>world</span></p>'
/// output: [TextContent(text: 'hello '), ImageContent(src: '123'), TextContent(text: ' world')]
/// ```
///
/// Parameters:
/// - [node]: The root node from which the content extraction begins.
/// - [contentElementList]: A list that will store the extracted `ChapterContentElement` objects.
void _traverseNodeToExtractContent(
  Node node,
  List<ChapterContentElement> contentElementList, {
  bool muted = false,
}) {
  final nodeType = node.nodeType;

  if (nodeType == Node.TEXT_NODE) {
    final text = node.text ?? '';
    if (contentElementList.isNotEmpty &&
        contentElementList.last is TextContent) {
      final last = contentElementList.removeLast() as TextContent;
      final mergedRanges = [...last.mutedRanges];
      if (muted && text.isNotEmpty) {
        mergedRanges.add(
          (start: last.text.length, end: last.text.length + text.length),
        );
      }
      contentElementList.add(
        last.copyWith(text: last.text + text, mutedRanges: mergedRanges),
      );
    } else {
      contentElementList.add(
        TextContent(
          text: text,
          mutedRanges: muted && text.isNotEmpty
              ? [(start: 0, end: text.length)]
              : const [],
        ),
      );
    }
    return;
  }

  // If the current leaf node is <br>, then create an empty `TextContent` instance immediately,
  // so that the following text content will be displayed in a new line.
  if (nodeType == Node.ELEMENT_NODE && (node as Element).localName == 'br') {
    contentElementList.add(TextContent(text: ''));
    return;
  }

  if (nodeType == Node.ELEMENT_NODE && (node as Element).localName == 'img') {
    final src = node.attributes['src'] ?? '';
    contentElementList.add(ImageContent(src: src));
    return;
  }

  var childMuted = muted;
  if (nodeType == Node.ELEMENT_NODE && _hasNonBlackColor(node as Element)) {
    childMuted = true;
  }

  for (final e in node.nodes) {
    _traverseNodeToExtractContent(e, contentElementList, muted: childMuted);
  }
}

/// Matches a CSS `color:` declaration inside an inline `style` attribute.
final _inlineColorRegExp = RegExp(r'color\s*:\s*([^;]+)', caseSensitive: false);

/// Whether [element] declares a non-black color via an inline `style` color or
/// a legacy `<font color>` attribute.
bool _hasNonBlackColor(Element element) {
  final fontColor = element.localName == 'font'
      ? element.attributes['color']
      : null;
  final style = element.attributes['style'] ?? '';
  final inlineColor = _inlineColorRegExp.firstMatch(style)?.group(1);
  final raw = (fontColor ?? inlineColor ?? '').trim().toLowerCase();
  if (raw.isEmpty) {
    return false;
  }
  final normalized = raw.replaceAll(RegExp(r'\s+'), '');
  const blackValues = {
    'black',
    '#000',
    '#000000',
    'rgb(0,0,0)',
    'rgba(0,0,0,1)',
    'rgba(0,0,0,1.0)',
  };
  return !blackValues.contains(normalized);
}
