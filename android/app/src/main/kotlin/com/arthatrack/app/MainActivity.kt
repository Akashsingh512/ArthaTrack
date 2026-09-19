package com.arthatrack.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.MediaStore
import android.provider.Settings
import android.view.HapticFeedbackConstants
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.database.Cursor
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val EVENT_CHANNEL = "com.arthatrack.app/notifications"
    private val METHOD_CHANNEL = "com.arthatrack.app/notification_control"
    private val SMS_CHANNEL = "com.arthatrack.app/sms_reader"
    private val HAPTICS_CHANNEL = "com.arthatrack.app/haptics"
    private val UPDATER_CHANNEL = "com.arthatrack.app/updater"
    private val SMS_PERMISSION_REQ_CODE = 2002

    private var pendingSmsResult: MethodChannel.Result? = null

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
                "showCategorizationNotification" -> {
                    val title = call.argument<String>("title") ?: "Categorize Transaction"
                    val body = call.argument<String>("body") ?: "Tap to add details"
                    val txId = call.argument<Int>("transactionId") ?: 0
                    showLocalNotification(title, body, txId)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // MethodChannel for SMS inbox access & runtime permissions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingSmsResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                            SMS_PERMISSION_REQ_CODE
                        )
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "readInboxSms" -> {
                    val rawLimit = (call.argument<Any>("limit") as? Number)?.toInt() ?: 0
                    val limit = if (rawLimit <= 0) 0 else rawLimit
                    val startDate = (call.argument<Any>("startDate") as? Number)?.toLong()
                    val endDate = (call.argument<Any>("endDate") as? Number)?.toLong()
                    try {
                        val messages = readSmsMessages(limit, startDate, endDate)
                        result.success(messages)
                    } catch (e: Exception) {
                        result.error("SMS_READ_ERROR", e.message, null)
                    }
                }
                "saveFileToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: "arthatrack_transactions.csv"
                    val content = call.argument<String>("content") ?: ""
                    try {
                        val savedPath = saveToDownloads(fileName, content)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                "updateSyncNotification" -> {
                    val title = call.argument<String>("title") ?: "ArthaTrack SMS Sync"
                    val message = call.argument<String>("message") ?: "Scanning messages..."
                    val progress = (call.argument<Any>("progress") as? Number)?.toInt() ?: 0
                    val max = (call.argument<Any>("max") as? Number)?.toInt() ?: 100
                    val isOngoing = call.argument<Boolean>("isOngoing") ?: true
                    showSyncNotification(title, message, progress, max, isOngoing)
                    result.success(true)
                }
                "finishSyncNotification" -> {
                    val title = call.argument<String>("title") ?: "SMS Sync Complete"
                    val message = call.argument<String>("message") ?: "Transactions are up to date."
                    finishSyncNotification(title, message)
                    result.success(true)
                }
                "cancelSyncNotification" -> {
                    cancelSyncNotification()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // MethodChannel for Direct Native Tactile Micro-Haptics
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTICS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "haptic" -> {
                    val type = call.argument<String>("type") ?: "light"
                    triggerHaptic(type)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // MethodChannel for In-App Auto-Update & APK Installation
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath must not be null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                            return@setMethodCallHandler
                        }

                        val authority = "${applicationContext.packageName}.fileprovider"
                        val apkUri = FileProvider.getUriForFile(this, authority, file)

                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "openBrowser" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BROWSER_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "url must not be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun triggerHaptic(type: String) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator ?: (getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val effectId = when (type) {
                        "selection" -> VibrationEffect.EFFECT_CLICK
                        "light" -> VibrationEffect.EFFECT_CLICK
                        "medium" -> VibrationEffect.EFFECT_CLICK
                        "heavy" -> VibrationEffect.EFFECT_HEAVY_CLICK
                        "error" -> VibrationEffect.EFFECT_DOUBLE_CLICK
                        else -> VibrationEffect.EFFECT_CLICK
                    }
                    val effect = VibrationEffect.createPredefined(effectId)
                    vibrator.vibrate(effect)
                    return
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val (durationMs, amplitude) = when (type) {
                        "selection" -> Pair(15L, 150)
                        "light" -> Pair(20L, 190)
                        "medium" -> Pair(35L, 220)
                        "heavy" -> Pair(50L, 255)
                        "error" -> Pair(80L, 255)
                        else -> Pair(20L, 180)
                    }
                    val effect = VibrationEffect.createOneShot(durationMs, amplitude)
                    vibrator.vibrate(effect)
                    return
                } else {
                    @Suppress("DEPRECATION")
                    val durationMs = when (type) {
                        "selection" -> 18L
                        "light" -> 22L
                        "medium" -> 35L
                        "heavy" -> 50L
                        "error" -> 80L
                        else -> 22L
                    }
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(durationMs)
                    return
                }
            }
        } catch (_: Exception) {}

        // Fallback: Perform haptic feedback directly on window decorView with IGNORE flags
        try {
            val feedbackConstant = when (type) {
                "selection" -> HapticFeedbackConstants.KEYBOARD_TAP
                "light" -> HapticFeedbackConstants.VIRTUAL_KEY
                "medium" -> HapticFeedbackConstants.KEYBOARD_TAP
                "heavy" -> HapticFeedbackConstants.LONG_PRESS
                else -> HapticFeedbackConstants.KEYBOARD_TAP
            }
            window?.decorView?.performHapticFeedback(
                feedbackConstant,
                HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING or
                    HapticFeedbackConstants.FLAG_IGNORE_VIEW_SETTING
            )
        } catch (_: Exception) {}
    }

    private fun saveToDownloads(fileName: String, content: String): String {
        val bytes = content.toByteArray(Charsets.UTF_8)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to allocate MediaStore entry in Downloads")
            contentResolver.openOutputStream(uri)?.use { os ->
                os.write(bytes)
                os.flush()
            }
            return "/storage/emulated/0/Download/$fileName"
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            val targetFile = File(downloadsDir, fileName)
            targetFile.writeBytes(bytes)
            return targetFile.absolutePath
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQ_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingSmsResult?.success(granted)
            pendingSmsResult = null
        }
    }

    private fun readSmsMessages(limit: Int, startDate: Long? = null, endDate: Long? = null): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val seenIds = mutableSetOf<Long>()
        val projection = arrayOf("_id", "address", "body", "date")
        // Batch page size — smaller batches work around OEM ContentProvider limits (Samsung, Xiaomi, etc.)
        val PAGE_SIZE = 200

        val dateWhereClauses = mutableListOf<String>()
        val dateWhereArgs = mutableListOf<String>()

        if (startDate != null && startDate > 0) {
            dateWhereClauses.add("date >= ?")
            dateWhereArgs.add(startDate.toString())
        }
        if (endDate != null && endDate > 0) {
            dateWhereClauses.add("date <= ?")
            dateWhereArgs.add(endDate.toString())
        }

        // Read messages in pages using date-based cursor pagination
        // Each page fetches the next PAGE_SIZE messages older than the last seen date
        fun readAllFromUri(baseUri: Uri, typeFilter: String? = null): Boolean {
            var lastDate: Long? = null
            var pagesFetched = 0
            var gotAny = false

            while (true) {
                if (limit > 0 && list.size >= limit) break

                val whereParts = mutableListOf<String>()
                val whereArgsList = mutableListOf<String>()

                // Date range filters
                whereParts.addAll(dateWhereClauses)
                whereArgsList.addAll(dateWhereArgs)

                // OEM type filter (for content://sms fallback)
                if (typeFilter != null) {
                    whereParts.add(typeFilter)
                }

                // Cursor pagination: fetch next page older than last fetched date
                if (lastDate != null) {
                    whereParts.add("date < ?")
                    whereArgsList.add(lastDate.toString())
                }

                // Per-page LIMIT via sortOrder — use URI param or LIMIT in sort depending on ROM
                val pageSortOrder = "date DESC"
                val pageUri = try {
                    // Many Android devices support limit/offset via URI query parameters
                    baseUri.buildUpon()
                        .appendQueryParameter("limit", PAGE_SIZE.toString())
                        .appendQueryParameter("offset", "0")
                        .build()
                } catch (_: Exception) {
                    baseUri
                }

                val selection = if (whereParts.isNotEmpty()) whereParts.joinToString(" AND ") else null
                val selectionArgs = if (whereArgsList.isNotEmpty()) whereArgsList.toTypedArray() else null

                var cursor: Cursor? = null
                try {
                    cursor = contentResolver.query(pageUri, projection, selection, selectionArgs, pageSortOrder)
                } catch (_: Exception) {
                    try {
                        // Fallback: plain URI without query params
                        cursor = contentResolver.query(baseUri, projection, selection, selectionArgs, pageSortOrder)
                    } catch (_: Exception) {}
                }

                var pageCount = 0
                var pageDone = false

                cursor?.use {
                    val idIdx = it.getColumnIndex("_id")
                    val addressIdx = it.getColumnIndex("address")
                    val bodyIdx = it.getColumnIndex("body")
                    val dateIdx = it.getColumnIndex("date")

                    while (it.moveToNext()) {
                        if (limit > 0 && list.size >= limit) { pageDone = true; break }
                        if (pageCount >= PAGE_SIZE) { pageDone = false; break }

                        val id = if (idIdx >= 0) it.getLong(idIdx) else -1L
                        val address = if (addressIdx >= 0) it.getString(addressIdx) ?: "" else ""
                        val body = if (bodyIdx >= 0) it.getString(bodyIdx) ?: "" else ""
                        val date = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()

                        lastDate = date

                        if (id >= 0 && seenIds.contains(id)) { pageCount++; continue }
                        if (id >= 0) seenIds.add(id)
                        pageCount++

                        if (body.isNotBlank()) {
                            gotAny = true
                            list.add(mapOf("sender" to address, "body" to body, "date" to date))
                        }
                    }
                    pageDone = pageDone || (it.count < PAGE_SIZE)
                }

                pagesFetched++

                // Stop if we got fewer results than page size (no more data) or hit limit
                if (pageDone || pageCount < PAGE_SIZE || (limit > 0 && list.size >= limit)) break
                // Safety: max 500 pages = up to 100,000 messages
                if (pagesFetched >= 500) break
            }
            return gotAny
        }

        // 1. Primary: content://sms/inbox (paginated)
        val primaryGotData = readAllFromUri(Uri.parse("content://sms/inbox"))

        // 2. Fallback: content://sms with type=1 (inbox) if primary returned nothing
        if (!primaryGotData) {
            readAllFromUri(Uri.parse("content://sms"), "type = 1")
        }

        return list
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Channel 1: High/Default Priority for User Action Alerts (e.g. Categorization)
            val alertChannel = NotificationChannel(
                "arthatrack_alerts",
                "Transaction Alerts",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Alerts to review and categorize new transactions"
            }
            notificationManager.createNotificationChannel(alertChannel)

            // Channel 2: Silent Low Priority for Background Sync Progress
            val syncChannel = NotificationChannel(
                "arthatrack_sync",
                "SMS Sync Progress",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "SMS inbox synchronization progress"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(syncChannel)
        }
    }

    private fun showLocalNotification(title: String, body: String, txId: Int) {
        try {
            createNotificationChannel()

            val intent = Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_transaction_id", txId)
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                if (txId > 0) txId else 1001,
                intent,
                pendingIntentFlags
            )

            val builder = NotificationCompat.Builder(this, "arthatrack_alerts")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            val notificationManager = NotificationManagerCompat.from(this)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
            ) {
                val notifId = if (txId > 0) txId else (System.currentTimeMillis() % 10000).toInt()
                notificationManager.notify(notifId, builder.build())
            }
        } catch (e: Exception) {
            // Gracefully ignore
        }
    }

    private val SYNC_NOTIFICATION_ID = 2004

    private fun showSyncNotification(title: String, message: String, progress: Int, max: Int, isOngoing: Boolean) {
        try {
            createNotificationChannel()
            val intent = Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(this, SYNC_NOTIFICATION_ID, intent, pendingIntentFlags)

            val builder = NotificationCompat.Builder(this, "arthatrack_sync")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(message)
                .setOngoing(isOngoing)
                .setOnlyAlertOnce(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_LOW)

            if (max > 0) {
                builder.setProgress(max, progress, false)
            } else {
                builder.setProgress(0, 0, true)
            }

            val notificationManager = NotificationManagerCompat.from(this)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
            ) {
                notificationManager.notify(SYNC_NOTIFICATION_ID, builder.build())
            }
        } catch (_: Exception) {}
    }

    private fun cancelSyncNotification() {
        try {
            val notificationManager = NotificationManagerCompat.from(this)
            notificationManager.cancel(SYNC_NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    private fun finishSyncNotification(title: String, message: String) {
        cancelSyncNotification()
    }
}
