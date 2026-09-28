import 'package:flutter/material.dart';

/// Background colors of the reader, inspired by the tomato-novel style:
/// white, light gray, paper yellow, eye-care green, sky blue, peach pink
/// and dark night.
const readerBackgroundColors = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFEFEFEF),
  Color(0xFFF5EFDE),
  Color(0xFFC7EDCC),
  Color(0xFFD6E8FA),
  Color(0xFFF8E2E4),
  Color(0xFF1A1A1A),
];

/// Returns the readable content color for the given reader background color.
Color readerContentColor(Color background) {
  return background.computeLuminance() > 0.5
      ? const Color(0xFF262626)
      : const Color(0xFFBFBFBF);
}
