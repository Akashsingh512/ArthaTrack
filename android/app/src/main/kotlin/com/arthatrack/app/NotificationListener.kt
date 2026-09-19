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

        fun postPayload(payload: Map<String, Any?>) {
            mainHandler.post {
                val sink = eventSink
                if (sink != null) {
                    sink.success(payload)
                } else {
                    if (eventBuffer.size < 50) {
                        eventBuffer.add(payload)
                    }
                }
            }
        }

        // Targeted banking and UPI packages in India
        val TARGET_PACKAGES = setOf(
            // UPI & Wallets
            "com.google.android.apps.nbu.paisa.user", // Google Pay (Tez)
            "com.phonepe.app",                        // PhonePe
            "net.one97.paytm",                        // Paytm
            "in.org.npci.upiapp",                     // BHIM
            "in.amazon.mShop.android.shopping",       // Amazon Pay
            "com.dreamplug.androidapp",               // CRED
            "com.fampay.in",                          // FamPay
            "money.fi.app",                           // Fi Money
            "com.jupiter.money",                      // Jupiter

            // Major Banks
            "net.hdfcbank.android",                   // HDFC MobileBanking
            "com.sbi.lotusintouch",                   // SBI YONO
            "com.sbi.upi",                            // SBI BHIM Pay
            "com.csam.icici.bank.imobile",            // ICICI iMobile Pay
            "com.axis.mobile",                        // Axis Mobile
            "com.kotak.bank",                         // Kotak 811
            "com.bankofbaroda.mconnect",              // bob World
            "com.pnb.pnbone",                         // PNB One
            "com.canarabank.mobility",                // Canara ai1
            "com.indusind.mobile",                    // IndusMobile
            "com.idfcfirstbank.optimus",              // IDFC FIRST Bank

            // Default & OEM SMS Apps
            "com.google.android.apps.messaging",      // Google Messages
            "com.samsung.android.messaging",          // Samsung Messages
            "com.android.mms",                        // AOSP Messaging
            "com.miui.sms",                           // Xiaomi MIUI SMS
            "com.xiaomi.misms",                       // Xiaomi Mi SMS
            "com.oneplus.mms",                        // OnePlus SMS
            "com.oppo.mms",                           // Oppo SMS
            "com.vivo.mms"                            // Vivo SMS
        )

        // Strict blocklist for non-financial social, chat, and streaming apps
        val CHAT_SOCIAL_PACKAGES = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "org.telegram.messenger",
            "com.facebook.orca",
            "com.facebook.katana",
            "com.instagram.android",
            "com.twitter.android",
            "com.discord",
            "com.slack",
            "com.google.android.youtube",
            "com.snapchat.android",
            "com.reddit.frontpage",
            "com.linkedin.android"
        )

        val TRANSACTION_ACTION_KEYWORDS = listOf(
            "debited", "credited", "spent", "withdrawn", "paid",
            "transferred", "payment received", "nach debit", "ach debit"
        )

        val BANKING_KEYWORDS = TRANSACTION_ACTION_KEYWORDS

        val CURRENCY_REGEX = Regex("""(?:₹|inr|\brs\.?)\s*[\d,]+(?:\.\d{1,2})?""", RegexOption.IGNORE_CASE)

        // STRICT SECURITY GUARD: Unconditional blocklist for any OTP, 2FA, or verification messages
        val OTP_BLOCKLIST_KEYWORDS = listOf(
            "otp",
            "one time password",
            "one-time password",
            "verification code",
            "verification password",
            "security code",
            "auth code",
            "authentication code",
            "login code",
            "passcode",
            "secret code",
            "do not share",
            "never share",
            "valid for",
            "use code",
            "confirmation code",
            "is your code"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val pkgName = sbn.packageName ?: ""

        // 1. ABSOLUTE RECURSION GUARD: Never intercept ArthaTrack's own alerts or sync notifications!
        if (pkgName == packageName || pkgName == "com.arthatrack.app") {
            return
        }

        // 2. Ignore ongoing / persistent foreground services or grouped summary headers
        if (sbn.isOngoing || (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0)) {
            return
        }

        // 3. Ignore non-financial chat and social media apps
        if (CHAT_SOCIAL_PACKAGES.contains(pkgName)) {
            return
        }

        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

        val combinedContent = "$title $text $bigText $subText".lowercase()

        // 4. STRICT SECURITY SHIELD: If notification contains ANY OTP or authentication token, DISCARD IMMEDIATELY!
        val containsOtp = OTP_BLOCKLIST_KEYWORDS.any { combinedContent.contains(it) }
        if (containsOtp) {
            return
        }

        // 5. Verification of financial keywords and currency symbols
        val isTargetApp = TARGET_PACKAGES.contains(pkgName)
        val hasActionKeyword = TRANSACTION_ACTION_KEYWORDS.any { combinedContent.contains(it) }
        val hasCurrencyPattern = CURRENCY_REGEX.containsMatchIn(combinedContent)

        // For target banking/UPI apps, require an action keyword OR a currency pattern.
        // For untrusted/other apps, require BOTH an action keyword AND an explicit currency amount.
        val isValidTransaction = if (isTargetApp) {
            hasActionKeyword || hasCurrencyPattern
        } else {
            hasActionKeyword && hasCurrencyPattern
        }

        if (!isValidTransaction) {
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

        postPayload(payload)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No-op for removed notifications
    }
}
