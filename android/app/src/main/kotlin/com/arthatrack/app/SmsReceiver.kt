package com.arthatrack.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
            if (messages.isEmpty()) return

            val sender = messages[0].displayOriginatingAddress ?: ""
            val fullBody = messages.joinToString("") { it.displayMessageBody ?: "" }
            val postTime = messages[0].timestampMillis

            if (fullBody.isBlank()) return

            val lower = fullBody.lowercase()

            // 1. STRICT SECURITY SHIELD: Never capture or process OTP/2FA messages
            val containsOtp = NotificationListener.OTP_BLOCKLIST_KEYWORDS.any { lower.contains(it) }
            if (containsOtp) return

            // 2. Financial check: Must contain banking keywords or currency
            val hasAction = NotificationListener.TRANSACTION_ACTION_KEYWORDS.any { lower.contains(it) }
            val hasCurrency = NotificationListener.CURRENCY_REGEX.containsMatchIn(lower)
            if (!hasAction && !hasCurrency) return

            // 3. Dispatch to Flutter pipeline immediately via eventSink/eventBuffer
            val payload = mapOf(
                "packageName" to "sms.provider.telephony",
                "title" to sender,
                "text" to fullBody,
                "bigText" to fullBody,
                "subText" to "SMS",
                "postTime" to postTime
            )

            NotificationListener.postPayload(context, payload)
        } catch (e: Exception) {
            // Gracefully ignore error to avoid any app crash
        }
    }
}
