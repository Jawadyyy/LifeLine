package com.lifeline.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    // FCM-displayed notifications reference this channel id (see AndroidManifest
    // default_notification_channel_id). It must exist on Android O+.
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "lifeline_alerts",
                "Emergency & alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "SOS alerts, safe follow-ups and donation matches."
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
