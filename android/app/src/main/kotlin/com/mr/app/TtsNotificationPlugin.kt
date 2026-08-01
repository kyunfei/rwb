package com.mr.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 朗读前台通知与控制按钮（播放/暂停/停止）。
 * Dart 侧通过 [ReaderTtsNotificationBridge] 调用。
 */
class TtsNotificationPlugin(private val context: Context) {

    companion object {
        private const val CHANNEL = "com.mr.app/tts"
        private const val CALLBACK_CHANNEL = "com.mr.app/tts_callback"
        private const val NOTIFICATION_ID = 0x545453
        private const val CHANNEL_ID = "reader_tts"
        private const val ACTION_PAUSE = "com.mr.app.tts.PAUSE"
        private const val ACTION_RESUME = "com.mr.app.tts.RESUME"
        private const val ACTION_STOP = "com.mr.app.tts.STOP"

        fun register(flutterEngine: FlutterEngine, context: Context) {
            val plugin = TtsNotificationPlugin(context)
            MethodChannel(flutterEngine.dartExecutor as BinaryMessenger, CHANNEL)
                .setMethodCallHandler(plugin.handler)
            plugin.callbackChannel =
                MethodChannel(flutterEngine.dartExecutor as BinaryMessenger, CALLBACK_CHANNEL)
            plugin.ensureChannel()
            plugin.registerReceiver()
        }
    }

    private var callbackChannel: MethodChannel? = null
    private var lastTitle: String = "朗读中"
    private var lastBody: String = ""
    private var lastPaused: Boolean = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_PAUSE -> invokeDart("pause")
                ACTION_RESUME -> invokeDart("resume")
                ACTION_STOP -> invokeDart("stop")
            }
        }
    }

    private var receiverRegistered = false

    val handler = { call: MethodCall, result: MethodChannel.Result ->
        when (call.method) {
            "showTtsNotification" -> {
                val title = call.argument<String>("title") ?: "朗读中"
                val body = call.argument<String>("body") ?: ""
                val paused = call.argument<Boolean>("isPaused") ?: false
                showNotification(title, body, paused)
                result.success(null)
            }
            "dismissTtsNotification" -> {
                dismissNotification()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "朗读",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "小说朗读控制"
            mgr.createNotificationChannel(channel)
        }
    }

    private fun registerReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(ACTION_PAUSE)
            addAction(ACTION_RESUME)
            addAction(ACTION_STOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
        receiverRegistered = true
    }

    private fun showNotification(title: String, body: String, paused: Boolean) {
        lastTitle = title
        lastBody = body
        lastPaused = paused
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            context.packageManager.getLaunchIntentForPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val toggleAction = if (paused) ACTION_RESUME else ACTION_PAUSE
        val toggleLabel = if (paused) "继续" else "暂停"
        val toggleIcon =
            if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause

        val togglePending = PendingIntent.getBroadcast(
            context,
            1,
            Intent().setAction(toggleAction).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopPending = PendingIntent.getBroadcast(
            context,
            2,
            Intent().setAction(ACTION_STOP).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(toggleIcon, toggleLabel, togglePending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "停止", stopPending)
            .build()

        mgr.notify(NOTIFICATION_ID, notification)
    }

    private fun dismissNotification() {
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        mgr.cancel(NOTIFICATION_ID)
    }

    private fun invokeDart(method: String) {
        callbackChannel?.invokeMethod(method, null)
        when (method) {
            "pause" -> showNotification(lastTitle, lastBody, true)
            "resume" -> showNotification(lastTitle, lastBody, false)
            "stop" -> dismissNotification()
        }
    }
}
