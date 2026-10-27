package com.cmps420.pillpal.pillpal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Native manager for Android's persistent, real-time snooze countdown notification.
 *
 * Implements the Zero Dart Background Loops architecture:
 * Configures [NotificationCompat.Builder.setUsesChronometer], [NotificationCompat.Builder.setChronometerCountDown],
 * and [NotificationCompat.Builder.setWhen] with the target epoch millisecond timestamp
 * (`snoozeEndTimestampMs`) so the Android System UI compositors render decrementing countdowns
 * autonomously without waking background isolates.
 *
 * Preserves user privacy by omitting specific medication names from the lock screen / notification
 * shade, matching PillPal's iOS ActivityKit privacy baseline.
 */
object LiveReminderManager {
    const val CHANNEL_ID = "pillpal_live_reminders"
    const val CHANNEL_NAME = "Medication Reminders"
    const val NOTIFICATION_ID = 8420

    const val ACTION_LOG_TAKEN = "com.cmps420.pillpal.ACTION_LOG_TAKEN"
    const val ACTION_SNOOZE = "com.cmps420.pillpal.ACTION_SNOOZE"
    const val EXTRA_BATCH_ID = "batchId"

    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var currentBatchId: String = ""
        private set

    @Volatile
    var currentSnoozeEndMs: Long = 0L
        private set

    @Volatile
    var currentRemainingDoses: Int = 0
        private set

    @Volatile
    var currentDurationMinutes: Int = 9
        private set

    @Volatile
    var currentProfileName: String? = null
        private set

    fun attachChannel(methodChannel: MethodChannel, context: Context) {
        channel = methodChannel
        ensureNotificationChannel(context)
    }

    fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return
            val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Persistent real-time countdown for snoozed medication doses."
                    setShowBadge(true)
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                }
                notificationManager.createNotificationChannel(channel)
            }
        }
    }

    fun startSnooze(
        context: Context,
        batchId: String,
        snoozeDurationMinutes: Int,
        snoozeEndTimestampMs: Long,
        remainingDoseCount: Int,
        profileName: String? = null
    ) {
        ensureNotificationChannel(context)

        currentBatchId = batchId
        currentDurationMinutes = if (snoozeDurationMinutes > 0) snoozeDurationMinutes else 9
        currentProfileName = profileName?.trim()?.ifEmpty { null }
        currentSnoozeEndMs = if (snoozeEndTimestampMs > 0L) {
            snoozeEndTimestampMs
        } else {
            System.currentTimeMillis() + (currentDurationMinutes * 60 * 1000L)
        }
        currentRemainingDoses = if (remainingDoseCount > 0) remainingDoseCount else 1

        renderNotification(context)
    }

    fun updateRemainingDoses(
        context: Context,
        batchId: String,
        remainingDoseCount: Int,
        profileName: String? = null
    ) {
        if (remainingDoseCount <= 0) {
            dismiss(context, batchId)
            return
        }
        currentBatchId = batchId
        currentRemainingDoses = remainingDoseCount
        if (profileName != null) {
            currentProfileName = profileName.trim().ifEmpty { null }
        }
        renderNotification(context)
    }

    fun dismiss(context: Context, batchId: String) {
        if (batchId.isEmpty() || currentBatchId.isEmpty() || currentBatchId == batchId) {
            currentBatchId = ""
            currentRemainingDoses = 0
            currentSnoozeEndMs = 0L
            currentProfileName = null
            try {
                NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
            } catch (_: SecurityException) {}
        }
    }

    private fun renderNotification(context: Context) {
        val count = currentRemainingDoses
        if (count <= 0) {
            dismiss(context, currentBatchId)
            return
        }

        val baseTitle = if (count == 1) "1 dose pending" else "$count doses pending"
        val title = if (!currentProfileName.isNullOrBlank()) {
            "$currentProfileName • $baseTitle"
        } else {
            baseTitle
        }
        val subtitle = "PillPal Snooze • Tap to open schedule"

        // Deep-link intent when user taps the notification card
        val contentIntent = Intent(Intent.ACTION_VIEW, Uri.parse("pillpal://schedule")).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            1000,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action 1: "Log Taken" intent
        val logTakenIntent = Intent(context, LiveReminderActionReceiver::class.java).apply {
            action = ACTION_LOG_TAKEN
            putExtra(EXTRA_BATCH_ID, currentBatchId)
        }
        val logTakenPendingIntent = PendingIntent.getBroadcast(
            context,
            1001,
            logTakenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action 2: "Snooze" intent
        val snoozeIntent = Intent(context, LiveReminderActionReceiver::class.java).apply {
            action = ACTION_SNOOZE
            putExtra(EXTRA_BATCH_ID, currentBatchId)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            context,
            1002,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val smallIconRes = try {
            val resId = context.resources.getIdentifier("ic_stat_pill", "drawable", context.packageName)
            if (resId != 0) resId else android.R.drawable.ic_lock_idle_alarm
        } catch (_: Exception) {
            android.R.drawable.ic_lock_idle_alarm
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(smallIconRes)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(currentSnoozeEndMs)
            .setColor(0xFF168B87.toInt())
            .setColorized(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .addAction(
                android.R.drawable.checkbox_on_background,
                "Log Taken",
                logTakenPendingIntent
            )
            .addAction(
                android.R.drawable.ic_lock_idle_alarm,
                "Snooze",
                snoozePendingIntent
            )

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Android 13+ runtime POST_NOTIFICATIONS permission not yet granted by user.
        }
    }

    fun handleAction(context: Context, action: String, batchId: String) {
        val targetBatchId = if (batchId.isNotEmpty()) batchId else currentBatchId

        when (action) {
            ACTION_LOG_TAKEN -> {
                val newCount = currentRemainingDoses - 1
                if (newCount <= 0) {
                    dismiss(context, targetBatchId)
                } else {
                    updateRemainingDoses(context, targetBatchId, newCount)
                }
                invokeFlutterMethod("logTaken", mapOf("batchId" to targetBatchId))
            }
            ACTION_SNOOZE -> {
                val now = System.currentTimeMillis()
                val isAlreadyActive = currentSnoozeEndMs > now
                if (!isAlreadyActive) {
                    // Previous countdown expired: start a fresh snooze interval
                    val newEnd = now + (currentDurationMinutes * 60 * 1000L)
                    startSnooze(
                        context = context,
                        batchId = targetBatchId,
                        snoozeDurationMinutes = currentDurationMinutes,
                        snoozeEndTimestampMs = newEnd,
                        remainingDoseCount = currentRemainingDoses,
                        profileName = currentProfileName
                    )
                }
                // Smart Snooze: if already active, do NOT reset timer. Forward alreadyActive to Flutter.
                invokeFlutterMethod(
                    "snooze",
                    mapOf(
                        "batchId" to targetBatchId,
                        "alreadyActive" to isAlreadyActive,
                        "durationSeconds" to (currentDurationMinutes * 60.0)
                    )
                )
            }
        }
    }

    fun notifyOpenSchedule() {
        invokeFlutterMethod("openSchedule", mapOf("batchId" to currentBatchId))
    }

    private fun invokeFlutterMethod(method: String, arguments: Map<String, Any>) {
        mainHandler.post {
            channel?.invokeMethod(method, arguments)
        }
    }
}
