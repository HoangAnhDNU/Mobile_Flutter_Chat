package com.example.mobile_flutter_chat

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity

class KeepAliveService : Service() {
    private val TAG = "KeepAliveService"
    private val CHANNEL_ID = "app_keep_alive_channel"
    private val NOTIFICATION_ID = 9999
    private val WAKELOCK_TAG = "AppChat:KeepAlive"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        try {
            super.onCreate()
            Log.d(TAG, "onCreate - Starting foreground service")
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildNotification())
            acquireWakeLock()
            Log.d(TAG, "Foreground service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error in onCreate: ${e.message}", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        releaseWakeLock()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Ứng dụng đang chạy",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Giữ kết nối để nhận thông báo"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, FlutterActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AppChat đang chạy")
            .setContentText("Đang kết nối để nhận tin nhắn")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKELOCK_TAG
        ).apply {
            acquire(10 * 60 * 1000L) // 10 minutes max, will be re-acquired
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }
}
