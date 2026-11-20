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
    const val ACTION_REQUEST_CANCEL_SNOOZE = "com.cmps420.pillpal.ACTION_REQUEST_CANCEL_SNOOZE"
    const val ACTION_KEEP_SNOOZE = "com.cmps420.pillpal.ACTION_KEEP_SNOOZE"
    const val ACTION_CANCEL_SNOOZE = "com.cmps420.pillpal.ACTION_CANCEL_SNOOZE"
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
    var currentDurationMinutes: Int = 15
        private set

    @Volatile
    var currentProfileName: String? = null
        private set

    @Volatile
    var currentSnoozeNotificationId: Int? = null
        private set

    @Volatile
    var pendingCancelConfirmation: Boolean = false
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
        profileName: String? = null,
        snoozeNotificationId: Int? = null
    ) {
        ensureNotificationChannel(context)

        currentBatchId = batchId
        currentDurationMinutes = if (snoozeDurationMinutes > 0) snoozeDurationMinutes else 15
        currentProfileName = profileName?.trim()?.ifEmpty { null }
        currentSnoozeNotificationId = snoozeNotificationId
        currentSnoozeEndMs = if (snoozeEndTimestampMs > 0L) {
            snoozeEndTimestampMs
        } else {
            System.currentTimeMillis() + (currentDurationMinutes * 60 * 1000L)
        }
        currentRemainingDoses = if (remainingDoseCount > 0) remainingDoseCount else 1
        pendingCancelConfirmation = false

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
        pendingCancelConfirmation = false
        renderNotification(context)
    }

    fun dismiss(context: Context, batchId: String) {
        if (batchId.isEmpty() || currentBatchId.isEmpty() || currentBatchId == batchId) {
            currentBatchId = ""
            currentRemainingDoses = 0
            currentSnoozeEndMs = 0L
            currentProfileName = null
            currentSnoozeNotificationId = null
            pendingCancelConfirmation = false
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

        val isCountingDown = currentSnoozeEndMs > System.currentTimeMillis()
        if (!isCountingDown) {
            pendingCancelConfirmation = false
        }

        val headerLabel = formatBatchHeader(currentBatchId)
        val countLabel = if (count == 1) "1 Left" else "$count Left"
        val baseTitle = "$headerLabel • $countLabel"
        val title = if (!currentProfileName.isNullOrBlank()) {
            "$currentProfileName • $baseTitle"
        } else {
            baseTitle
        }
        val subtitle = formatStatusSubtitle(isCountingDown, pendingCancelConfirmation)

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

        val requestCancelPendingIntent = PendingIntent.getBroadcast(
            context,
            1004,
            Intent(context, LiveReminderActionReceiver::class.java).apply {
                action = ACTION_REQUEST_CANCEL_SNOOZE
                putExtra(EXTRA_BATCH_ID, currentBatchId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val keepSnoozePendingIntent = PendingIntent.getBroadcast(
            context,
            1005,
            Intent(context, LiveReminderActionReceiver::class.java).apply {
                action = ACTION_KEEP_SNOOZE
                putExtra(EXTRA_BATCH_ID, currentBatchId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Final cancel/dismiss action ("Confirm Cancel" during countdown, "Dismiss" once expired)
        val cancelSnoozePendingIntent = PendingIntent.getBroadcast(
            context,
            1003,
            Intent(context, LiveReminderActionReceiver::class.java).apply {
                action = ACTION_CANCEL_SNOOZE
                putExtra(EXTRA_BATCH_ID, currentBatchId)
            },
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
            .setShowWhen(true)
            .setWhen(if (isCountingDown) currentSnoozeEndMs else System.currentTimeMillis())
            .setUsesChronometer(isCountingDown)
            .setChronometerCountDown(isCountingDown)
            .setColor(0xFF168B87.toInt())
            .setColorized(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)

        if (isCountingDown && pendingCancelConfirmation) {
            builder
                .addAction(
                    android.R.drawable.ic_menu_revert,
                    "Keep Snooze",
                    keepSnoozePendingIntent
                )
                .addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Confirm Cancel",
                    cancelSnoozePendingIntent
                )
        } else {
            builder
                .addAction(
                    android.R.drawable.ic_menu_view,
                    "Open to Log",
                    contentPendingIntent
                )
                .addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    if (isCountingDown) "Cancel Snooze" else "Dismiss",
                    if (isCountingDown) requestCancelPendingIntent else cancelSnoozePendingIntent
                )
        }

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Android 13+ runtime POST_NOTIFICATIONS permission not yet granted by user.
        }
    }

    fun handleAction(context: Context, action: String, batchId: String) {
        val targetBatchId = if (batchId.isNotEmpty()) batchId else currentBatchId

        when (action) {
            ACTION_REQUEST_CANCEL_SNOOZE -> {
                if (currentRemainingDoses > 0 && currentSnoozeEndMs > System.currentTimeMillis()) {
                    pendingCancelConfirmation = true
                    renderNotification(context)
                } else {
                    handleAction(context, ACTION_CANCEL_SNOOZE, targetBatchId)
                }
            }
            ACTION_KEEP_SNOOZE -> {
                if (currentRemainingDoses > 0) {
                    pendingCancelConfirmation = false
                    renderNotification(context)
                }
            }
            ACTION_CANCEL_SNOOZE -> {
                val explicitId = currentSnoozeNotificationId
                val fallbackId = if (targetBatchId.isNotEmpty()) {
                    snoozeNotificationIdForBatch(targetBatchId)
                } else {
                    null
                }
                dismiss(context, targetBatchId)
                try {
                    val manager = NotificationManagerCompat.from(context)
                    if (explicitId != null) manager.cancel(explicitId)
                    if (fallbackId != null && fallbackId != explicitId) {
                        manager.cancel(fallbackId)
                    }
                } catch (_: SecurityException) {}
                invokeFlutterMethod("cancelSnooze", mapOf("batchId" to targetBatchId))
            }
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

    private fun formatBatchHeader(batchId: String): String {
        val parts = batchId.split("_")
        if (parts.size == 3 && parts[0] == "batch") {
            val hour = parts[1].toIntOrNull()
            val minute = parts[2].toIntOrNull()
            if (hour != null && minute != null && hour in 0..23 && minute in 0..59) {
                val totalMinutes = hour * 60 + minute
                val periodName = when {
                    totalMinutes in (5 * 60) until (11 * 60 + 30) -> "Morning"
                    totalMinutes in (11 * 60 + 30) until (14 * 60) -> "Midday"
                    totalMinutes in (14 * 60) until (17 * 60) -> "Afternoon"
                    totalMinutes in (17 * 60) until (21 * 60) -> "Evening"
                    else -> "Bedtime"
                }
                val displayHour = if (hour % 12 == 0) 12 else hour % 12
                val period = if (hour < 12) "AM" else "PM"
                val slotLabel = String.format(
                    java.util.Locale.US,
                    "%d:%02d %s",
                    displayHour,
                    minute,
                    period
                )
                return "$periodName • $slotLabel"
            }
        }
        return "Medication Routine"
    }

    private fun formatStatusSubtitle(
        isCountingDown: Boolean,
        isPendingCancelConfirmation: Boolean
    ): String {
        if (isCountingDown && isPendingCancelConfirmation) {
            return "Cancel this snooze reminder?"
        }
        if (isCountingDown) {
            return "Tap to open"
        }
        return "Ready to log • Tap to open"
    }

    private fun snoozeNotificationIdForBatch(batchId: String): Int {
        val combined = "snooze_slot\u0000$batchId"
        var hash = 0x811c9dc5L
        for (ch in combined) {
            hash = hash xor ch.code.toLong()
            hash = (hash * 0x01000193L) and 0xFFFFFFFFL
        }
        return (hash and 0x7FFFFFFFL).toInt()
    }

    private fun invokeFlutterMethod(method: String, arguments: Map<String, Any>) {
        mainHandler.post {
            channel?.invokeMethod(method, arguments)
        }
    }
}
