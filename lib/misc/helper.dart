/// Returns a function which caches the result of the execution of [fn].
/// The returned function ensures that [fn] is executed only during the first call.
/// For all subsequent calls to the returned function, it returns the cached result directly.
ReturnType Function() onceFn<ReturnType>(ReturnType Function() fn) {
  dynamic result;
  bool isFirstTimeRun = true;

  return () {
    if (!isFirstTimeRun) {
      return result;
    }
    result = fn();
    isFirstTimeRun = false;
    return result;
  };
}

final _htmlEntityPattern = RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);');

/// Named entities produced by typical server-side escapers, plus a few common
/// punctuation marks. Numeric references cover everything else.
const _namedHtmlEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'copy': '©',
  'reg': '®',
  'deg': '°',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'middot': '·',
  'times': '×',
  'divide': '÷',
  'plusmn': '±',
};

/// Decodes HTML entities (e.g. `&amp;`, `&#039;`, `&#x27;`) in [text]
/// without interpreting any markup, so plain text containing `<` stays
/// intact. Text without entities is returned unchanged.
String unescapeHtmlEntities(String text) {
  return text.replaceAllMapped(_htmlEntityPattern, (match) {
    final body = match.group(1)!;
    if (body.startsWith('#')) {
      final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final code = int.tryParse(
        body.substring(isHex ? 2 : 1),
        radix: isHex ? 16 : 10,
      );
      if (code == null) return match.group(0)!;
      try {
        return String.fromCharCode(code);
      } on RangeError {
        return match.group(0)!;
      }
    }
    return _namedHtmlEntities[body] ?? match.group(0)!;
  });
}
