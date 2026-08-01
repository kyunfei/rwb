package com.mr.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * TTS 通知 / 前台服务 MethodChannel 桥接。
 *
 * Dart 侧通过 [ReaderTtsNotificationBridge] 调用；
 * 真正的 [startForeground] 与音频焦点由 [TtsService] 承担。
 */
class TtsNotificationPlugin(
    private val context: Context,
    private val callbackChannel: MethodChannel,
) {

    companion object {
        private const val CHANNEL = "com.mr.app/tts"
        private const val CALLBACK_CHANNEL = "com.mr.app/tts_callback"

        fun register(flutterEngine: FlutterEngine, context: Context) {
            val messenger: BinaryMessenger = flutterEngine.dartExecutor
            val callback = MethodChannel(messenger, CALLBACK_CHANNEL)
            val plugin = TtsNotificationPlugin(context, callback)
            MethodChannel(messenger, CHANNEL).setMethodCallHandler(plugin.handler)

            val mainHandler = Handler(Looper.getMainLooper())
            TtsService.eventSink = { method ->
                mainHandler.post {
                    callback.invokeMethod(method, null)
                }
            }
        }
    }

    val handler = { call: MethodCall, result: MethodChannel.Result ->
        when (call.method) {
            "showTtsNotification" -> {
                val title = call.argument<String>("title") ?: "朗读中"
                val body = call.argument<String>("body") ?: ""
                val paused = call.argument<Boolean>("isPaused") ?: false
                TtsService.startOrUpdate(context, title, body, paused)
                result.success(null)
            }
            "dismissTtsNotification" -> {
                TtsService.dismiss(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
