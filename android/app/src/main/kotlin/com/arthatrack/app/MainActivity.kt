package com.arthatrack.app

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val EVENT_CHANNEL = "com.arthatrack.app/notifications"
    private val METHOD_CHANNEL = "com.arthatrack.app/notification_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for streaming notifications in real-time
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationListener.setSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    NotificationListener.setSink(null)
                }
            }
        )

        // MethodChannel for permission check and launching settings
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerGranted" -> {
                    val isGranted = isNotificationServiceEnabled()
                    result.success(isGranted)
                }
                "openNotificationListenerSettings" -> {
                    openNotificationAccessSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (flat != null && flat.isNotEmpty()) {
            val names = flat.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && cn.packageName == pkgName) {
                    return true
                }
            }
        }
        return NotificationManagerCompat.getEnabledListenerPackages(this).contains(pkgName)
    }

    private fun openNotificationAccessSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val componentName = ComponentName(this, NotificationListener::class.java).flattenToString()
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                    putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, componentName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return
            }
        } catch (e: Exception) {
            // Fall back to general notification listener settings
        }

        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }
}
