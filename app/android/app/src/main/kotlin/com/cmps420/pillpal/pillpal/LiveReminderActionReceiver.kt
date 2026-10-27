package com.cmps420.pillpal.pillpal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * BroadcastReceiver for handling interactive action clicks ("Log Taken", "Snooze")
 * from the persistent ongoing snooze notification.
 */
class LiveReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val batchId = intent.getStringExtra(LiveReminderManager.EXTRA_BATCH_ID) ?: ""
        LiveReminderManager.handleAction(context, action, batchId)
    }
}
