package com.arthatrack.app

import android.app.Notification
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.CopyOnWriteArrayList

class NotificationListener : NotificationListenerService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null
        private val mainHandler = Handler(Looper.getMainLooper())
        private val eventBuffer = CopyOnWriteArrayList<Map<String, Any?>>()

        fun setSink(sink: EventChannel.EventSink?) {
            eventSink = sink
            if (sink != null && eventBuffer.isNotEmpty()) {
                mainHandler.post {
                    for (item in eventBuffer) {
                        eventSink?.success(item)
                    }
                    eventBuffer.clear()
                }
            }
        }

        // Targeted banking and UPI packages in India
        val TARGET_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay (Tez)
            "com.phonepe.app",                        // PhonePe
            "net.one97.paytm",                        // Paytm
            "net.hdfcbank.android",                   // HDFC MobileBanking
            "com.sbi.lotusintouch",                   // SBI YONO
            "com.sbi.upi",                            // SBI BHIM Pay
            "com.csam.icici.bank.imobile",            // ICICI iMobile Pay
            "com.axis.mobile",                        // Axis Mobile
            "com.kotak.bank",                         // Kotak 811
            "com.google.android.apps.messaging",      // Google Messages
            "com.samsung.android.messaging"           // Samsung Messages
        )

        val BANKING_KEYWORDS = listOf(
            "debited", "credited", "spent", "withdrawn", "paid",
            "received", "₹", "inr", "rs.", "bal:", "avl bal", "balance"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val pkgName = sbn.packageName ?: ""
        val extras = sbn.notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

        val combinedContent = "$title $text $bigText $subText".lowercase()

        // Check if package is in target banking/UPI apps OR contains banking keywords
        val isTargetApp = TARGET_PACKAGES.contains(pkgName)
        val hasBankingKeywords = BANKING_KEYWORDS.any { combinedContent.contains(it) }

        if (!isTargetApp && !hasBankingKeywords) {
            return
        }

        val payload = mapOf(
            "packageName" to pkgName,
            "title" to title,
            "text" to text,
            "bigText" to bigText,
            "subText" to subText,
            "postTime" to sbn.postTime
        )

        mainHandler.post {
            val sink = eventSink
            if (sink != null) {
                sink.success(payload)
            } else {
                // Buffer notifications until Flutter EventChannel listener binds
                if (eventBuffer.size < 50) {
                    eventBuffer.add(payload)
                }
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No-op for removed notifications
    }
}
