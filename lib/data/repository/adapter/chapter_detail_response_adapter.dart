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
/// [color] is the ARGB value of the color inherited from the nearest
/// ancestor markup (an inline `color` style or a `<font color>` tag). When
/// non-null, the text ranges are recorded together with the value so the
/// reader can render them in the original color, in a muted gray or in the
/// uniform body color depending on the text color mode.
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
  int? color,
}) {
  final nodeType = node.nodeType;

  if (nodeType == Node.TEXT_NODE) {
    final text = node.text ?? '';
    if (contentElementList.isNotEmpty &&
        contentElementList.last is TextContent) {
      final last = contentElementList.removeLast() as TextContent;
      final mergedRanges = [...last.coloredRanges];
      if (color != null && text.isNotEmpty) {
        mergedRanges.add(
          (
            start: last.text.length,
            end: last.text.length + text.length,
            color: color,
          ),
        );
      }
      contentElementList.add(
        last.copyWith(text: last.text + text, coloredRanges: mergedRanges),
      );
    } else {
      contentElementList.add(
        TextContent(
          text: text,
          coloredRanges: color != null && text.isNotEmpty
              ? [(start: 0, end: text.length, color: color)]
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

  var childColor = color;
  if (nodeType == Node.ELEMENT_NODE) {
    final ownColor = _declaredColor(node as Element);
    if (ownColor != null) {
      childColor = ownColor;
    }
  }

  for (final e in node.nodes) {
    _traverseNodeToExtractContent(e, contentElementList, color: childColor);
  }
}

/// The color explicitly declared on [element] itself (not inherited), if
/// any. An inline `style` color wins over the legacy `<font color>`
/// presentational attribute, following CSS precedence.
int? _declaredColor(Element element) {
  final style = element.attributes['style'];
  if (style != null) {
    for (final declaration in style.split(';')) {
      final separator = declaration.indexOf(':');
      if (separator < 0) {
        continue;
      }
      final property =
          declaration.substring(0, separator).trim().toLowerCase();
      if (property == 'color') {
        final value = declaration.substring(separator + 1);
        final parsed = _parseCssColor(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
  }
  if (element.localName == 'font') {
    final fontColor = element.attributes['color'];
    if (fontColor != null) {
      return _parseCssColor(fontColor);
    }
  }
  return null;
}

final _hexColorRegExp = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$');

/// Parses a CSS color value into an ARGB value.
///
/// Supported syntaxes: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`,
/// `rgb()/rgba()` (comma or space separated, with number or percentage
/// channels), `hsl()/hsla()`, and the CSS named colors. Empty values
/// resolve to `null` (no explicit color). `transparent` resolves to the
/// fully transparent color `0x00000000` so it is still tracked as a
/// declared color (the simplified mode mutes it like any other non-black
/// color, and the original mode renders it invisible, as on the website).
///
/// If the value is an unrecognized named keyword, the closest CSS named
/// color (by spelling distance) is used so something is still shown.
int? _parseCssColor(String input) {
  final raw = input
      .trim()
      .toLowerCase()
      .replaceAll('!important', '')
      .trim();
  if (raw.isEmpty) {
    return null;
  }
  if (raw == 'transparent') {
    return 0x00000000;
  }

  final hex = _hexColorRegExp.firstMatch(raw)?.group(1);
  if (hex != null) {
    String r;
    String g;
    String b;
    String a;
    String doubled(String value) =>
        value.split('').map((c) => '$c$c').join();
    switch (hex.length) {
      case 3:
        r = doubled(hex.substring(0, 1));
        g = doubled(hex.substring(1, 2));
        b = doubled(hex.substring(2, 3));
        a = 'ff';
      case 4:
        r = doubled(hex.substring(0, 1));
        g = doubled(hex.substring(1, 2));
        b = doubled(hex.substring(2, 3));
        a = doubled(hex.substring(3, 4));
      case 6:
        r = hex.substring(0, 2);
        g = hex.substring(2, 4);
        b = hex.substring(4, 6);
        a = 'ff';
      default:
        r = hex.substring(0, 2);
        g = hex.substring(2, 4);
        b = hex.substring(4, 6);
        a = hex.substring(6, 8);
    }
    final value = int.tryParse('$a$r$g$b', radix: 16);
    if (value == null) {
      return null;
    }
    // Hex colors without an explicit alpha channel are fully opaque.
    return hex.length == 3 || hex.length == 6
        ? value | 0xFF000000
        : value;
  }

  if (raw.startsWith('rgb')) {
    final components = _parseFunctionalColorComponents(raw);
    if (components.length >= 3) {
      final r = _colorChannel(components[0]);
      final g = _colorChannel(components[1]);
      final b = _colorChannel(components[2]);
      final alpha =
          components.length > 3 ? _alphaChannel(components[3]) : 1.0;
      return _argbFrom(r, g, b, alpha);
    }
  }

  if (raw.startsWith('hsl')) {
    final components = _parseFunctionalColorComponents(raw);
    if (components.length >= 3) {
      final h = _hueChannel(components[0]);
      final s = _percentageChannel(components[1]);
      final l = _percentageChannel(components[2]);
      final alpha =
          components.length > 3 ? _alphaChannel(components[3]) : 1.0;
      return _hslaToArgb(h, s, l, alpha);
    }
  }

  final named = _cssNamedColors[raw];
  if (named != null) {
    return named;
  }

  return _closestNamedColor(raw);
}

/// Splits the body of an `rgb()/hsl()` function into its components,
/// accepting both the legacy comma syntax (`rgb(1, 2, 3, 0.5)`) and the
/// modern space/slash syntax (`rgb(1 2 3 / 50%)`).
List<String> _parseFunctionalColorComponents(String raw) {
  final open = raw.indexOf('(');
  final close = raw.lastIndexOf(')');
  if (open < 0 || close <= open) {
    return const [];
  }
  final body = raw.substring(open + 1, close).replaceAll('/', ' ');
  return body
      .split(RegExp(r'[\s,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

int _colorChannel(String component) {
  if (component.endsWith('%')) {
    final value = double.tryParse(component.substring(0, component.length - 1));
    if (value == null) {
      return 0;
    }
    return (value * 255 / 100).round().clamp(0, 255);
  }
  return (double.tryParse(component) ?? 0).round().clamp(0, 255);
}

double _percentageChannel(String component) {
  final value = component.endsWith('%')
      ? double.tryParse(component.substring(0, component.length - 1))
      : double.tryParse(component);
  return ((value ?? 0) / 100).clamp(0.0, 1.0);
}

double _alphaChannel(String component) {
  if (component.endsWith('%')) {
    final value = double.tryParse(component.substring(0, component.length - 1));
    return ((value ?? 0) / 100).clamp(0.0, 1.0);
  }
  return (double.tryParse(component) ?? 1.0).clamp(0.0, 1.0);
}

double _hueChannel(String component) {
  final match = RegExp(r'^(-?[\d.]+)([a-z]*)$').firstMatch(component);
  if (match == null) {
    return 0;
  }
  final value = double.tryParse(match.group(1) ?? '0') ?? 0;
  final unit = match.group(2) ?? 'deg';
  switch (unit) {
    case 'rad':
      return value * 180 / 3.1415926535897932;
    case 'turn':
      return value * 360;
    case 'grad':
      return value * 0.9;
    default:
      return value;
  }
}

int _argbFrom(int r, int g, int b, double alpha) {
  return ((alpha * 255).round() << 24) |
      (r << 16) |
      (g << 8) |
      b;
}

/// Converts HSL (hue in degrees, saturation/lightness in 0..1) plus alpha
/// into an ARGB value.
int _hslaToArgb(double h, double s, double l, double alpha) {
  var hue = h % 360;
  if (hue < 0) {
    hue += 360;
  }
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - (((hue / 60) % 2) - 1).abs());
  final m = l - c / 2;
  double r;
  double g;
  double b;
  if (hue < 60) {
    r = c;
    g = x;
    b = 0;
  } else if (hue < 120) {
    r = x;
    g = c;
    b = 0;
  } else if (hue < 180) {
    r = 0;
    g = c;
    b = x;
  } else if (hue < 240) {
    r = 0;
    g = x;
    b = c;
  } else if (hue < 300) {
    r = x;
    g = 0;
    b = c;
  } else {
    r = c;
    g = 0;
    b = x;
  }
  return _argbFrom(
    ((r + m) * 255).round().clamp(0, 255),
    ((g + m) * 255).round().clamp(0, 255),
    ((b + m) * 255).round().clamp(0, 255),
    alpha,
  );
}

/// Returns the CSS named color closest (by spelling) to [name], or `null`
/// when no keyword is within a small edit distance.
int? _closestNamedColor(String name) {
  String? best;
  var bestDistance = 4;
  for (final key in _cssNamedColors.keys) {
    final distance = _levenshteinDistance(name, key);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = key;
    }
  }
  return best == null ? null : _cssNamedColors[best];
}

int _levenshteinDistance(String a, String b) {
  final costs = List<int>.generate(b.length + 1, (index) => index);
  for (var i = 1; i <= a.length; i++) {
    var previousDiagonal = costs[0];
    costs[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final previousCost = costs[j];
      if (a[i - 1] == b[j - 1]) {
        costs[j] = previousDiagonal;
      } else {
        costs[j] =
            1 + [costs[j - 1], costs[j], previousDiagonal].reduce(
                  (x, y) => x < y ? x : y,
                );
      }
      previousDiagonal = previousCost;
    }
  }
  return costs[b.length];
}

/// CSS Color Module Level 4 named colors, stored as ARGB values.
const _cssNamedColors = <String, int>{
  'black': 0xFF000000,
  'silver': 0xFFC0C0C0,
  'gray': 0xFF808080,
  'grey': 0xFF808080,
  'white': 0xFFFFFFFF,
  'maroon': 0xFF800000,
  'red': 0xFFFF0000,
  'purple': 0xFF800080,
  'fuchsia': 0xFFFF00FF,
  'magenta': 0xFFFF00FF,
  'green': 0xFF008000,
  'lime': 0xFF00FF00,
  'olive': 0xFF808000,
  'yellow': 0xFFFFFF00,
  'navy': 0xFF000080,
  'blue': 0xFF0000FF,
  'teal': 0xFF008080,
  'aqua': 0xFF00FFFF,
  'cyan': 0xFF00FFFF,
  'orange': 0xFFFFA500,
  'aliceblue': 0xFFF0F8FF,
  'antiquewhite': 0xFFFAEBD7,
  'aquamarine': 0xFF7FFFD4,
  'azure': 0xFFF0FFFF,
  'beige': 0xFFF5F5DC,
  'bisque': 0xFFFFE4C4,
  'blanchedalmond': 0xFFFFEBCD,
  'blueviolet': 0xFF8A2BE2,
  'brown': 0xFFA52A2A,
  'burlywood': 0xFFDEB887,
  'cadetblue': 0xFF5F9EA0,
  'chartreuse': 0xFF7FFF00,
  'chocolate': 0xFFD2691E,
  'coral': 0xFFFF7F50,
  'cornflowerblue': 0xFF6495ED,
  'cornsilk': 0xFFFFF8DC,
  'crimson': 0xFFDC143C,
  'darkblue': 0xFF00008B,
  'darkcyan': 0xFF008B8B,
  'darkgoldenrod': 0xFFB8860B,
  'darkgray': 0xFFA9A9A9,
  'darkgrey': 0xFFA9A9A9,
  'darkgreen': 0xFF006400,
  'darkkhaki': 0xFFBDB76B,
  'darkmagenta': 0xFF8B008B,
  'darkolivegreen': 0xFF556B2F,
  'darkorange': 0xFFFF8C00,
  'darkorchid': 0xFF9932CC,
  'darkred': 0xFF8B0000,
  'darksalmon': 0xFFE9967A,
  'darkseagreen': 0xFF8FBC8F,
  'darkslateblue': 0xFF483D8B,
  'darkslategray': 0xFF2F4F4F,
  'darkslategrey': 0xFF2F4F4F,
  'darkturquoise': 0xFF00CED1,
  'darkviolet': 0xFF9400D3,
  'deeppink': 0xFFFF1493,
  'deepskyblue': 0xFF00BFFF,
  'dimgray': 0xFF696969,
  'dimgrey': 0xFF696969,
  'dodgerblue': 0xFF1E90FF,
  'firebrick': 0xFFB22222,
  'floralwhite': 0xFFFFFAF0,
  'forestgreen': 0xFF228B22,
  'gainsboro': 0xFFDCDCDC,
  'ghostwhite': 0xFFF8F8FF,
  'gold': 0xFFFFD700,
  'goldenrod': 0xFFDAA520,
  'greenyellow': 0xFFADFF2F,
  'honeydew': 0xFFF0FFF0,
  'hotpink': 0xFFFF69B4,
  'indianred': 0xFFCD5C5C,
  'indigo': 0xFF4B0082,
  'ivory': 0xFFFFFFF0,
  'khaki': 0xFFF0E68C,
  'lavender': 0xFFE6E6FA,
  'lavenderblush': 0xFFFFF0F5,
  'lawngreen': 0xFF7CFC00,
  'lemonchiffon': 0xFFFFFACD,
  'lightblue': 0xFFADD8E6,
  'lightcoral': 0xFFF08080,
  'lightcyan': 0xFFE0FFFF,
  'lightgoldenrodyellow': 0xFFFAFAD2,
  'lightgray': 0xFFD3D3D3,
  'lightgrey': 0xFFD3D3D3,
  'lightgreen': 0xFF90EE90,
  'lightpink': 0xFFFFB6C1,
  'lightsalmon': 0xFFFFA07A,
  'lightseagreen': 0xFF20B2AA,
  'lightskyblue': 0xFF87CEFA,
  'lightslategray': 0xFF778899,
  'lightslategrey': 0xFF778899,
  'lightsteelblue': 0xFFB0C4DE,
  'lightyellow': 0xFFFFFFE0,
  'limegreen': 0xFF32CD32,
  'linen': 0xFFFAF0E6,
  'mediumaquamarine': 0xFF66CDAA,
  'mediumblue': 0xFF0000CD,
  'mediumorchid': 0xFFBA55D3,
  'mediumpurple': 0xFF9370DB,
  'mediumseagreen': 0xFF3CB371,
  'mediumslateblue': 0xFF7B68EE,
  'mediumspringgreen': 0xFF00FA9A,
  'mediumturquoise': 0xFF48D1CC,
  'mediumvioletred': 0xFFC71585,
  'midnightblue': 0xFF191970,
  'mintcream': 0xFFF5FFFA,
  'mistyrose': 0xFFFFE4E1,
  'moccasin': 0xFFFFE4B5,
  'navajowhite': 0xFFFFDEAD,
  'oldlace': 0xFFFDF5E6,
  'olivedrab': 0xFF6B8E23,
  'orangered': 0xFFFF4500,
  'orchid': 0xFFDA70D6,
  'palegoldenrod': 0xFFEEE8AA,
  'palegreen': 0xFF98FB98,
  'paleturquoise': 0xFFAFEEEE,
  'palevioletred': 0xFFDB7093,
  'papayawhip': 0xFFFFEFD5,
  'peachpuff': 0xFFFFDAB9,
  'peru': 0xFFCD853F,
  'pink': 0xFFFFC0CB,
  'plum': 0xFFDDA0DD,
  'powderblue': 0xFFB0E0E6,
  'rebeccapurple': 0xFF663399,
  'rosybrown': 0xFFBC8F8F,
  'royalblue': 0xFF4169E1,
  'saddlebrown': 0xFF8B4513,
  'salmon': 0xFFFA8072,
  'sandybrown': 0xFFF4A460,
  'seagreen': 0xFF2E8B57,
  'seashell': 0xFFFFF5EE,
  'sienna': 0xFFA0522D,
  'skyblue': 0xFF87CEEB,
  'slateblue': 0xFF6A5ACD,
  'slategray': 0xFF708090,
  'slategrey': 0xFF708090,
  'snow': 0xFFFFFAFA,
  'springgreen': 0xFF00FF7F,
  'steelblue': 0xFF4682B4,
  'tan': 0xFFD2B48C,
  'thistle': 0xFFD8BFD8,
  'tomato': 0xFFFF6347,
  'turquoise': 0xFF40E0D0,
  'violet': 0xFFEE82EE,
  'wheat': 0xFFF5DEB3,
  'whitesmoke': 0xFFF5F5F5,
  'yellowgreen': 0xFF9ACD32,
};
