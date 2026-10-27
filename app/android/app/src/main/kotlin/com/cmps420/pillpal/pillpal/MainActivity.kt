package com.cmps420.pillpal.pillpal

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Zero-disk-write photo picker for the upload-fallback scan path
 * (Stage F, med-tracker-spec.md's "no photo is ever taken or saved"
 * guarantee, extended to the fallback path too).
 *
 * `image_picker` would work here, but it always copies the picked file into
 * the app's private cache directory first -- there's no way to opt out of
 * that from its Dart API. This channel instead reads the picked image's
 * bytes straight out of `ContentResolver` into memory and hands them to
 * Dart directly; nothing is ever written to disk on the Android side.
 *
 * Uses the classic `startActivityForResult`/`onActivityResult` API rather
 * than the newer Activity Result API. This is a `FlutterFragmentActivity`
 * (required by `local_auth` for the app-lock prompt), which still supports the
 * classic pair. `ACTION_GET_CONTENT` still shows the system picker UI and
 * works on every supported API level (minSdk 24+).
 *
 * Also registers the `com.pillpal.app/live_reminders` MethodChannel to drive
 * Android's persistent Ongoing Notification countdown with autonomous chronometer.
 */
class MainActivity : FlutterFragmentActivity() {
    private val photoPickerChannelName = "pillpal/zero_disk_photo_picker"
    private val liveRemindersChannelName = "com.pillpal.app/live_reminders"
    private val pickImageRequestCode = 4201
    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme == "pillpal" && uri.host == "schedule") {
            LiveReminderManager.notifyOpenSchedule()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Photo picker channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, photoPickerChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "A pick is already in progress", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(intent, pickImageRequestCode)
                    }
                    else -> result.notImplemented()
                }
            }

        // App Lock channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pillpal/app_lock")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setHideInRecents" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            setRecentsScreenshotEnabled(call.arguments != true)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Live Reminders / Ongoing Notification channel
        val liveRemindersChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            liveRemindersChannelName
        )
        LiveReminderManager.attachChannel(liveRemindersChannel, this)

        liveRemindersChannel.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            when (call.method) {
                "startSnoozeActivity" -> {
                    val batchId = args["batchId"] as? String ?: ""
                    val durationMinutes = (args["snoozeDurationMinutes"] as? Number)?.toInt() ?: 9
                    val endMs = (args["snoozeEndTimestampMs"] as? Number)?.toLong()
                        ?: (System.currentTimeMillis() + durationMinutes * 60 * 1000L)
                    val remainingCount = (args["remainingDoseCount"] as? Number)?.toInt()
                        ?: (args["remainingCount"] as? Number)?.toInt()
                        ?: 1
                    val profileName = args["profileName"] as? String

                    LiveReminderManager.startSnooze(
                        context = this,
                        batchId = batchId,
                        snoozeDurationMinutes = durationMinutes,
                        snoozeEndTimestampMs = endMs,
                        remainingDoseCount = remainingCount,
                        profileName = profileName
                    )
                    result.success(null)
                }
                "updateRemainingDoses" -> {
                    val batchId = args["batchId"] as? String ?: ""
                    val remainingCount = (args["remainingDoseCount"] as? Number)?.toInt()
                        ?: (args["remainingCount"] as? Number)?.toInt()
                        ?: 0
                    val profileName = args["profileName"] as? String

                    LiveReminderManager.updateRemainingDoses(this, batchId, remainingCount, profileName)
                    result.success(null)
                }
                "dismissActivity" -> {
                    val batchId = args["batchId"] as? String ?: ""
                    LiveReminderManager.dismiss(this, batchId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickImageRequestCode) return

        val result = pendingResult
        pendingResult = null
        val uri = data?.data
        if (uri == null) {
            result?.success(null) // user cancelled -- not an error
            return
        }
        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            result?.success(bytes)
        } catch (e: Exception) {
            result?.error("READ_FAILED", e.message, null)
        }
    }
}
