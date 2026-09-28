import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Hardware volume key direction.
enum VolumeKey {
  /// KEYCODE_VOLUME_UP: turn to the previous page.
  up,

  /// KEYCODE_VOLUME_DOWN: turn to the next page.
  down,
}

/// Hardware volume key events intercepted natively on Android.
///
/// Subscribing starts interception (the system volume panel is suppressed
/// and the keys are forwarded instead); cancelling the subscription restores
/// normal system volume behavior. On non-Android platforms [stream] is empty.
class VolumeKeyEvents {
  static const EventChannel _channel = EventChannel('masiro/volume_keys');

  /// A fresh event stream for each access: the native interception starts on
  /// listen and stops (restoring system volume) on cancel, so it must be
  /// possible to subscribe again after a previous subscription was cancelled.
  static Stream<VolumeKey> get stream {
    if (!Platform.isAndroid) {
      return const Stream<VolumeKey>.empty();
    }
    return _channel.receiveBroadcastStream().map(
          (event) => event == 'up' ? VolumeKey.up : VolumeKey.down,
        );
  }
}
