package com.mr.app

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * 占位前台服务声明（Manifest 历史遗留）。
 * 实际朗读控制由 [TtsNotificationPlugin] 通知栏完成。
 */
class TtsService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
}
