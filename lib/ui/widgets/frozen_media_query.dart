import 'package:flutter/material.dart';

/// Signals that a reader route transition is in progress. While the value
/// is true, pages *below* the reader keep reporting the window insets they
/// had in regular edge-to-edge mode, so hiding/showing the status bar for
/// the immersive reader does not relayout (and visibly shift) them while
/// they are still on screen.
///
/// The reader route itself is a sibling route and is intentionally not
/// wrapped by [FrozenInsets], so it always receives the real (immersive)
/// insets.
class ReaderTransitionInsets extends ValueNotifier<bool> {
  ReaderTransitionInsets._() : super(false);

  static final ReaderTransitionInsets instance = ReaderTransitionInsets._();
}

/// Holds [MediaQuery.padding]/[MediaQuery.viewPadding] constant for its
/// subtree while [ReaderTransitionInsets] is active. The insets are
/// captured at the moment freezing starts (still edge-to-edge) and resume
/// following the live values as soon as it ends, at which point the reader
/// is fully opaque and any relayout happens off screen.
class FrozenInsets extends StatefulWidget {
  final Widget child;

  const FrozenInsets({super.key, required this.child});

  @override
  State<FrozenInsets> createState() => _FrozenInsetsState();
}

class _FrozenInsetsState extends State<FrozenInsets> {
  EdgeInsets? _frozenPadding;
  EdgeInsets? _frozenViewPadding;

  @override
  void initState() {
    super.initState();
    ReaderTransitionInsets.instance.addListener(_onTransitionFlagChanged);
  }

  @override
  void dispose() {
    ReaderTransitionInsets.instance.removeListener(_onTransitionFlagChanged);
    super.dispose();
  }

  void _onTransitionFlagChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (!ReaderTransitionInsets.instance.value) {
      _frozenPadding = null;
      _frozenViewPadding = null;
      return widget.child;
    }
    _frozenPadding ??= mediaQuery.padding;
    _frozenViewPadding ??= mediaQuery.viewPadding;
    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: _frozenPadding,
        viewPadding: _frozenViewPadding,
      ),
      child: widget.child,
    );
  }
}
