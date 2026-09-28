package com.example.masiro

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var volumeKeyEvents: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "masiro/volume_keys")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeKeyEvents = events
                }

                override fun onCancel(arguments: Any?) {
                    volumeKeyEvents = null
                }
            })
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val events = volumeKeyEvents
        if (events != null) {
            when (keyCode) {
                // Consume the volume keys so the system volume panel does not
                // show while the reader is listening; events are forwarded to
                // Flutter for page turning.
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    events.success("up")
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    events.success("down")
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
