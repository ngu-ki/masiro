import 'package:flutter/material.dart';
import 'package:masiro/data/repository/model/chapter_detail.dart';
import 'package:masiro/data/repository/model/text_color_mode.dart';
import 'package:masiro/ui/screens/reader/typesetting/typeset_models.dart';

/// Source-declared solid black; in simplified mode it is treated as
/// ordinary body text.
const int _sourceBlack = 0xFF000000;

/// Source-declared transparent text; invisible unless long-press
/// revealed in original mode. In simplified mode it is shown muted.
const int _transparentColor = 0x00000000;

/// Resolves the paint color of one glyph unit from its source element's
/// [ColoredRange]s. Pure logic (no Canvas, no TextPainter) so the three
/// text-color modes are unit-testable.
///
/// - [TextColorMode.uniform]: always null (the adaptive body color).
/// - [TextColorMode.original]: the declared color verbatim, except
///   transparent text which renders muted while [revealTransparent].
/// - [TextColorMode.simplified]: black declarations become body color;
///   every other declared color (including transparent) is muted.
class TypesetColorResolver {
  TypesetColorResolver({
    required this.rangesByElement,
    required this.mode,
    required this.bodyColor,
    required this.revealTransparent,
  });

  /// Element index -> its source colored ranges.
  final Map<int, List<ColoredRange>> rangesByElement;
  final TextColorMode mode;
  final Color bodyColor;
  final bool revealTransparent;

  late final Color _mutedColor = bodyColor.withValues(alpha: 0.45);

  /// Returns the explicit color for [unit], or null when the body color
  /// applies.
  Color? resolve(GlyphUnit unit) {
    if (mode == TextColorMode.uniform) {
      return null;
    }
    // Synthetic indent units cover no source characters.
    if (unit.charStart >= unit.charEnd) {
      return null;
    }
    final ranges = rangesByElement[unit.elementIndex];
    if (ranges == null || ranges.isEmpty) {
      return null;
    }
    for (final range in ranges) {
      // Half-overlapping ranges (a cluster straddles a boundary) keeps
      // the color under its start offset.
      if (unit.charStart >= range.start && unit.charStart < range.end) {
        return _resolveValue(range.color);
      }
    }
    return null;
  }

  Color? _resolveValue(int value) {
    switch (mode) {
      case TextColorMode.original:
        if (value == _transparentColor && revealTransparent) {
          return _mutedColor;
        }
        return Color(value);
      case TextColorMode.simplified:
        if (value == _sourceBlack) {
          return null;
        }
        return _mutedColor;
      case TextColorMode.uniform:
        return null;
    }
  }
}

/// One text draw at ([x], [y]) top-left. [letterSpacing] mirrors the
/// justified inter-glyph gap so a group of equally spaced units is
/// painted with one TextPainter instead of one per glyph.
class TypesetDrawCommand {
  final String text;
  final double x;
  final double y;
  final Color? color;
  final double letterSpacing;

  const TypesetDrawCommand({
    required this.text,
    required this.x,
    required this.y,
    this.color,
    this.letterSpacing = 0.0,
  });
}

/// The paint plan of one page: draw commands plus fast/slow path stats.
class TypesetPaintPlan {
  final List<TypesetDrawCommand> commands;

  /// Commands painting a grouped regular line (fast path).
  final int groupPaints;

  /// Commands painting a single glyph on a compressed/hung line.
  final int perGlyphPaints;

  const TypesetPaintPlan(
    this.commands, {
    required this.groupPaints,
    required this.perGlyphPaints,
  });

  /// Fraction of paints served by the grouped fast path. Only
  /// compressed/hung paragraphs should fall back to per-glyph paints.
  double get fastPathRatio =>
      groupPaints + perGlyphPaints == 0
          ? 1
          : groupPaints / (groupPaints + perGlyphPaints);
}

bool _colorSame(Color? a, Color? b) => a == b;

/// Builds the paint plan of [page] using only the geometry stored on the
/// glyph units — painting never re-measures or re-breaks anything.
TypesetPaintPlan buildTypesetPaintPlan(
  TypesetPage page, {
  required Map<int, List<ColoredRange>> rangesByElement,
  required TextColorMode mode,
  required Color bodyColor,
  required bool revealTransparent,
}) {
  final resolver = TypesetColorResolver(
    rangesByElement: rangesByElement,
    mode: mode,
    bodyColor: bodyColor,
    revealTransparent: revealTransparent,
  );
  return buildTypesetPaintPlanWithResolver(page, resolver);
}

/// Variant with an injected resolver (used by tests and by painters that
/// share one resolver across pages).
TypesetPaintPlan buildTypesetPaintPlanWithResolver(
  TypesetPage page,
  TypesetColorResolver resolver,
) {
  final commands = <TypesetDrawCommand>[];
  var groupPaints = 0;
  var perGlyphPaints = 0;
  var y = 0.0;

  void emitGroup(String text, double x, Color? color, double gap) {
    commands.add(TypesetDrawCommand(
      text: text,
      x: x,
      y: y,
      color: color,
      letterSpacing: gap,
    ));
    groupPaints++;
  }

  for (final block in page.blocks) {
    if (block is TypesetBlankGap) {
      y += block.height;
      continue;
    }
    if (block is! TypesetLine) {
      continue;
    }
    y += block.topGap;
    final lineY = y;
    final glyphs = block.glyphs;

    if (block.hasIrregularGlyphs) {
      // Compressed or hung punctuation: each glyph is painted at its own
      // stored column and paint offset.
      for (final unit in glyphs) {
        commands.add(TypesetDrawCommand(
          text: unit.text,
          x: unit.xStart + unit.drawOffset,
          y: lineY,
          color: resolver.resolve(unit),
        ));
        perGlyphPaints++;
      }
    } else {
      // Regular line: merge consecutive glyphs laid out at a constant
      // inter-glyph advance into one painter. justifyViaSpaces splits
      // groups at ASCII spaces (the inflated space advance already
      // shows up in the next glyph's xStart); otherwise the line's
      // justifyGap is the constant extra advance.
      final gap = block.justifyViaSpaces ? 0.0 : block.justifyGap;
      var groupStart = 0;

      void flushGroup(int end) {
        if (end <= groupStart) {
          return;
        }
        final first = glyphs[groupStart];
        final buffer = StringBuffer();
        for (var i = groupStart; i < end; i++) {
          buffer.write(glyphs[i].text);
        }
        emitGroup(
          buffer.toString(),
          first.xStart,
          resolver.resolve(first),
          gap,
        );
        groupStart = end;
      }

      for (var i = 0; i < glyphs.length; i++) {
        final unit = glyphs[i];
        final color = resolver.resolve(unit);
        final startNewGroup = i == 0 ||
            !_colorSame(color, resolver.resolve(glyphs[i - 1])) ||
            (block.justifyViaSpaces && glyphs[i - 1].text == ' ') ||
            unit.xStart - glyphs[i - 1].xStart !=
                glyphs[i - 1].width + gap;
        if (startNewGroup && i > groupStart) {
          flushGroup(i);
        }
        if (startNewGroup) {
          groupStart = i;
        }
      }
      flushGroup(glyphs.length);
    }

    y += block.height;
  }

  return TypesetPaintPlan(
    commands,
    groupPaints: groupPaints,
    perGlyphPaints: perGlyphPaints,
  );
}

/// Reuses laid-out [TextPainter]s across repaints. Owned by the pager
/// state, which must call [dispose] when the reader leaves the screen.
class TypesetTextPainterPool {
  final Map<String, TextPainter> _cache = {};

  TextPainter painterFor(
    String text,
    TextStyle style, {
    Color? color,
    double letterSpacing = 0.0,
  }) {
    final colorValue = color?.toARGB32() ?? 0;
    final key = '$text|$colorValue|$letterSpacing';
    return _cache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: color == null
              ? style
              : style.copyWith(
                  color: color,
                  letterSpacing: letterSpacing == 0 ? null : letterSpacing,
                ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  /// Drops cached painters; call when the text style changes so stale
  /// glyph metrics (font size, family...) are never reused.
  void clear() {
    for (final painter in _cache.values) {
      painter.dispose();
    }
    _cache.clear();
  }

  void dispose() {
    clear();
  }
}

/// Paints one typeset text page. Image pages stay on the existing widget
/// path and are never wrapped in this painter.
class TypesetPagePainter extends CustomPainter {
  TypesetPagePainter({
    required this.page,
    required this.resolver,
    required this.style,
    this.pool,
  });

  final TypesetPage page;
  final TypesetColorResolver resolver;
  final TextStyle style;

  /// Optional shared painter cache. When null, painters are laid out and
  /// disposed during the paint pass itself.
  final TypesetTextPainterPool? pool;

  TextPainter _painterFor(TypesetDrawCommand command) {
    final pool = this.pool;
    if (pool != null) {
      return pool.painterFor(
        command.text,
        style,
        color: command.color,
        letterSpacing: command.letterSpacing,
      );
    }
    return TextPainter(
      text: TextSpan(
        text: command.text,
        style: command.color == null
            ? style
            : style.copyWith(
                color: command.color,
                letterSpacing:
                    command.letterSpacing == 0 ? null : command.letterSpacing,
              ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plan = buildTypesetPaintPlanWithResolver(page, resolver);
    final localPainters = <TextPainter>[];
    for (final command in plan.commands) {
      final painter = _painterFor(command);
      if (pool == null) {
        localPainters.add(painter);
      }
      // The uniform-gap fast path applies the gap via letterSpacing; the
      // trailing blank after the final glyph must not overdraw the edge.
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, command.y, size.width,
          size.height - command.y));
      painter.paint(canvas, Offset(command.x, command.y));
      canvas.restore();
    }
    for (final painter in localPainters) {
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant TypesetPagePainter oldDelegate) {
    return oldDelegate.page != page ||
        oldDelegate.style != style ||
        oldDelegate.resolver.mode != resolver.mode ||
        oldDelegate.resolver.bodyColor != resolver.bodyColor ||
        oldDelegate.resolver.revealTransparent !=
            resolver.revealTransparent;
  }
}
