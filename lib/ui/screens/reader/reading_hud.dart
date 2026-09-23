import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The persistent reader HUD shown while the menu is hidden:
/// the chapter title at the top left, the reading progress at the bottom
/// left and the clock with the battery level at the bottom right.
class ReadingHud extends StatefulWidget {
  final String title;
  final ValueListenable<double> progress;
  final Color color;
  final bool isVisible;

  const ReadingHud({
    super.key,
    required this.title,
    required this.progress,
    required this.color,
    required this.isVisible,
  });

  @override
  State<ReadingHud> createState() => _ReadingHudState();
}

class _ReadingHudState extends State<ReadingHud> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final hudStyle = TextStyle(
      fontSize: 12,
      color: widget.color.withOpacity(0.55),
    );

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: mediaQuery.padding.top + 10,
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hudStyle,
              ),
            ),
            Positioned(
              left: 16,
              bottom: mediaQuery.padding.bottom + 10,
              child: ValueListenableBuilder<double>(
                valueListenable: widget.progress,
                builder: (context, value, _) {
                  return Text(
                    '${(value * 100).toStringAsFixed(1)}%',
                    style: hudStyle,
                  );
                },
              ),
            ),
            Positioned(
              right: 16,
              bottom: mediaQuery.padding.bottom + 10,
              child: _ClockBatteryText(style: hudStyle),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockBatteryText extends StatefulWidget {
  final TextStyle style;

  const _ClockBatteryText({required this.style});

  @override
  State<_ClockBatteryText> createState() => _ClockBatteryTextState();
}

class _ClockBatteryTextState extends State<_ClockBatteryText> {
  final _battery = Battery();
  Timer? _timer;
  StreamSubscription<BatteryState>? _batterySubscription;
  int? _batteryLevel;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _fetchBatteryLevel();
    _batterySubscription = _battery.onBatteryStateChanged.listen((_) {
      _fetchBatteryLevel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _batterySubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() => _batteryLevel = level);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _batteryLevel = null);
      }
    }
  }

  String _formatClock() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final batteryText = _batteryLevel != null ? '  $_batteryLevel%' : '';
    return Text(
      '${_formatClock()}$batteryText',
      style: widget.style,
    );
  }
}
