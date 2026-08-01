package com.mr.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * TTS 朗读前台服务。
 *
 * 通过 [startForeground] + `mediaPlayback` 类型维持进程，避免锁屏/后台时被系统回收。
 * 同时持有音频焦点，并在来电、其他 App 抢占音频、耳机拔出时通知 Dart 侧暂停。
 *
 * 实际发音仍由 Dart 侧 `flutter_tts` 完成；本服务只负责保活、通知栏与音频焦点。
 */
class TtsService : Service(), AudioManager.OnAudioFocusChangeListener {

    companion object {
        private const val TAG = "TtsService"

        const val ACTION_START = "com.mr.app.tts.START"
        const val ACTION_UPDATE = "com.mr.app.tts.UPDATE"
        const val ACTION_DISMISS = "com.mr.app.tts.DISMISS"
        const val ACTION_PAUSE = "com.mr.app.tts.PAUSE"
        const val ACTION_RESUME = "com.mr.app.tts.RESUME"
        const val ACTION_STOP = "com.mr.app.tts.STOP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_PAUSED = "paused"

        const val NOTIFICATION_ID = 0x545453
        const val CHANNEL_ID = "reader_tts"

        /** 由 [TtsNotificationPlugin] 注入，用于把通知栏/焦点事件回传 Dart。 */
        @Volatile
        var eventSink: ((String) -> Unit)? = null

        fun startOrUpdate(
            context: Context,
            title: String,
            body: String,
            paused: Boolean,
        ) {
            val intent = Intent(context, TtsService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_PAUSED, paused)
            }
            context.startForegroundService(intent)
        }

        fun dismiss(context: Context) {
            context.stopService(Intent(context, TtsService::class.java))
        }
    }

    private lateinit var audioManager: AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    private var noisyReceiverRegistered = false

    private var title: String = "朗读中"
    private var body: String = ""
    private var paused: Boolean = false
    private var running = false

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                // 耳机拔出：与短暂失焦同等处理，暂停且不自动恢复
                handleSystemPause("audioBecomingNoisy")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        ensureChannel()
        registerNoisyReceiver()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START, ACTION_UPDATE, null -> {
                title = intent?.getStringExtra(EXTRA_TITLE) ?: title
                body = intent?.getStringExtra(EXTRA_BODY) ?: body
                val wantPaused = intent?.getBooleanExtra(EXTRA_PAUSED, paused) ?: paused
                applyPlaybackState(wantPaused, fromUserOrDart = true)
                promoteForeground()
                // 想播放但焦点申请失败：通知 Dart 回到暂停，避免无声假播放
                if (!wantPaused && paused) {
                    emit("audioFocusLost")
                }
            }
            ACTION_PAUSE -> {
                applyPlaybackState(paused = true, fromUserOrDart = true)
                promoteForeground()
                emit("pause")
            }
            ACTION_RESUME -> {
                if (requestAudioFocus()) {
                    applyPlaybackState(paused = false, fromUserOrDart = true)
                    promoteForeground()
                    emit("resume")
                } else {
                    // 拿不到焦点则保持暂停，避免无声「假播放」
                    applyPlaybackState(paused = true, fromUserOrDart = true)
                    promoteForeground()
                    emit("audioFocusLost")
                }
            }
            ACTION_STOP -> {
                // 先回调 Dart 停朗读，再拆掉前台服务
                emit("stop")
                shutdown()
                return START_NOT_STICKY
            }
            ACTION_DISMISS -> {
                // Dart 侧已自行 stop，只需拆除服务
                shutdown()
                return START_NOT_STICKY
            }
            else -> {
                promoteForeground()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        unregisterNoisyReceiver()
        abandonAudioFocus()
        running = false
        super.onDestroy()
    }

    override fun onAudioFocusChange(focusChange: Int) {
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                // 来电 / 其他 App 播放：一律暂停。语音朗读不适合 duck。
                // 暂停时会 abandon 焦点，因此不依赖后续 GAIN 自动恢复。
                handleSystemPause("audioFocusLost")
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                hasAudioFocus = true
                // 不自动恢复朗读：避免来电结束后突然出声打扰用户。
                emit("audioFocusGained")
            }
        }
    }

    private fun handleSystemPause(reason: String) {
        if (!running) return
        if (paused) {
            // 已暂停时仍告知 Dart（幂等），便于状态对齐
            emit(reason)
            return
        }
        paused = true
        abandonAudioFocus()
        promoteForeground()
        emit(reason)
        Log.i(TAG, "system pause: $reason")
    }

    /**
     * @param fromUserOrDart true 表示来自 Dart/通知栏的主动状态同步；
     *   会据此申请或释放音频焦点。
     */
    private fun applyPlaybackState(paused: Boolean, fromUserOrDart: Boolean) {
        this.paused = paused
        running = true
        if (!fromUserOrDart) return
        if (paused) {
            abandonAudioFocus()
        } else {
            if (!requestAudioFocus()) {
                // 申请失败则退回暂停态，由调用方决定是否提示
                this.paused = true
            }
        }
    }

    private fun promoteForeground() {
        val notification = buildNotification()
        startForeground(
            NOTIFICATION_ID,
            notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
        )
        running = true
    }

    private fun shutdown() {
        abandonAudioFocus()
        running = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val toggleAction = if (paused) ACTION_RESUME else ACTION_PAUSE
        val toggleLabel = if (paused) "继续" else "暂停"
        val toggleIcon =
            if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause

        val togglePending = PendingIntent.getService(
            this,
            1,
            Intent(this, TtsService::class.java).setAction(toggleAction),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopPending = PendingIntent.getService(
            this,
            2,
            Intent(this, TtsService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(toggleIcon, toggleLabel, togglePending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "停止", stopPending)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "朗读",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "小说朗读控制"
        channel.setSound(null, null)
        mgr.createNotificationChannel(channel)
    }

    private fun requestAudioFocus(): Boolean {
        if (hasAudioFocus) return true
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(attrs)
            .setOnAudioFocusChangeListener(this)
            .setAcceptsDelayedFocusGain(false)
            .build()
        focusRequest = request
        val result = audioManager.requestAudioFocus(request)
        hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        if (!hasAudioFocus) {
            Log.w(TAG, "requestAudioFocus failed: $result")
        }
        return hasAudioFocus
    }

    private fun abandonAudioFocus() {
        val request = focusRequest
        if (request != null) {
            audioManager.abandonAudioFocusRequest(request)
            focusRequest = null
        }
        hasAudioFocus = false
    }

    private fun registerNoisyReceiver() {
        if (noisyReceiverRegistered) return
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(noisyReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(noisyReceiver, filter)
        }
        noisyReceiverRegistered = true
    }

    private fun unregisterNoisyReceiver() {
        if (!noisyReceiverRegistered) return
        try {
            unregisterReceiver(noisyReceiver)
        } catch (_: Exception) {
            // 已注销则忽略
        }
        noisyReceiverRegistered = false
    }

    private fun emit(method: String) {
        try {
            eventSink?.invoke(method)
        } catch (e: Exception) {
            Log.w(TAG, "emit $method failed: ${e.message}")
        }
    }
}
