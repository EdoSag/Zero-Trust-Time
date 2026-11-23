package dev.sagron.zerotrusttime.links

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Time and the other Zero-Trust apps (lib/links/zt_links.dart): ZT Tasks and
 * ZT Calendar ask Time to track time on a task or an event, Time asks them
 * to pick one, and a linked entry opens its item there.
 *
 * Only apps signed with this app's own key take part (all Zero-Trust apps
 * share it). Android names the asking app only when it waits for an
 * answer, so a request must come with startActivityForResult; anything
 * else is turned away before the app shows anything. The other app's id is
 * taken from its package, never from what it says about itself.
 */
class ZtLinks(private val activity: Activity) {
    companion object {
        const val ACTION_TRACK = "bz.zerotrust.action.TRACK_TIME"
        const val ACTION_PICK = "bz.zerotrust.action.PICK_TEXT"
        const val ACTION_OPEN = "bz.zerotrust.action.OPEN_ITEM"
        const val EXTRA_TEXT = "bz.zerotrust.extra.TEXT"
        const val EXTRA_WANT_ITEM = "bz.zerotrust.extra.WANT_ITEM"
        const val EXTRA_ITEM_ID = "bz.zerotrust.extra.ITEM_ID"
        const val EXTRA_TITLE = "bz.zerotrust.extra.TITLE"
        const val EXTRA_START = "bz.zerotrust.extra.START_MS"
        const val EXTRA_END = "bz.zerotrust.extra.END_MS"
        const val REQUEST_PICK = 7311
        private const val CHANNEL = "dev.sagron.zerotrusttime/links"
        private const val SUITE_PREFIX = "dev.sagron.zerotrust"

        fun isTrack(intent: Intent?): Boolean = intent?.action == ACTION_TRACK

        /** A time in epoch milliseconds, sent as a Long (or as text). */
        @Suppress("DEPRECATION")
        private fun millis(extras: Bundle?, key: String): Long? =
            when (val v = extras?.get(key)) {
                is Number -> v.toLong()
                is String -> v.toLongOrNull()
                else -> null
            }
    }

    /** A track request from a suite app, waiting for the unlocked app. */
    private var track: Map<String, Any?>? = null

    /** Time was opened for a track request and must answer it. */
    private var tracking = false
    private var pickResult: MethodChannel.Result? = null

    private fun sameSigner(other: String?): Boolean {
        if (other == null || !other.startsWith(SUITE_PREFIX) || other == activity.packageName) return false
        return try {
            activity.packageManager.checkSignatures(activity.packageName, other) == PackageManager.SIGNATURE_MATCH
        } catch (e: Exception) {
            false
        }
    }

    /** From onCreate: takes a track request, or turns a stranger away. */
    fun onCreate(intent: Intent?) {
        if (intent == null || !isTrack(intent)) return
        val caller = activity.callingPackage
        if (!sameSigner(caller)) {
            activity.setResult(Activity.RESULT_CANCELED)
            activity.finish()
            return
        }
        val extras = intent.extras
        track = mapOf(
            "package" to caller,
            "itemId" to extras?.getString(EXTRA_ITEM_ID),
            "title" to (extras?.getString(EXTRA_TITLE) ?: extras?.getString(EXTRA_TEXT)),
            "start" to millis(extras, EXTRA_START),
            "end" to millis(extras, EXTRA_END),
        )
        tracking = true
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "takeTrack" -> {
                    val out = track
                    track = null
                    result.success(out)
                }
                "finishTrack" -> {
                    if (tracking) {
                        tracking = false
                        val saved = call.argument<Boolean>("saved") == true
                        activity.setResult(if (saved) Activity.RESULT_OK else Activity.RESULT_CANCELED)
                        activity.finish()
                    }
                    result.success(null)
                }
                "canPick" -> result.success(pickIntent(call.argument<String>("package")) != null)
                "pick" -> {
                    val intent = pickIntent(call.argument<String>("package"))
                    if (intent == null || pickResult != null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    pickResult = result
                    try {
                        activity.startActivityForResult(intent, REQUEST_PICK)
                    } catch (e: ActivityNotFoundException) {
                        pickResult = null
                        result.success(null)
                    }
                }
                "open" -> result.success(open(call.argument<String>("package"), call.argument<String>("itemId")))
                else -> result.notImplemented()
            }
        }
    }

    /** The other app's pick screen, if it is installed and one of ours. */
    private fun pickIntent(pkg: String?): Intent? {
        if (!sameSigner(pkg)) return null
        val intent = Intent(ACTION_PICK).setPackage(pkg).putExtra(EXTRA_WANT_ITEM, true)
        return if (intent.resolveActivity(activity.packageManager) != null) intent else null
    }

    /** From onActivityResult: true when it was the answer to a pick. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = pickResult ?: return true
        pickResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return true
        }
        val extras = data.extras
        result.success(
            mapOf(
                "text" to extras?.getString(EXTRA_TEXT),
                "itemId" to extras?.getString(EXTRA_ITEM_ID),
                "title" to extras?.getString(EXTRA_TITLE),
                "start" to millis(extras, EXTRA_START),
                "end" to millis(extras, EXTRA_END),
            ),
        )
        return true
    }

    /** Opens the item in its app, or just the app. False when not installed. */
    private fun open(pkg: String?, itemId: String?): Boolean {
        if (pkg == null || !sameSigner(pkg)) return false
        if (!itemId.isNullOrEmpty()) {
            val item = Intent(ACTION_OPEN).setPackage(pkg).putExtra(EXTRA_ITEM_ID, itemId)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (item.resolveActivity(activity.packageManager) != null) {
                try {
                    activity.startActivity(item)
                    return true
                } catch (e: ActivityNotFoundException) {
                    // Fall back to the app itself.
                }
            }
        }
        val launch = activity.packageManager.getLaunchIntentForPackage(pkg) ?: return false
        activity.startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return true
    }
}
