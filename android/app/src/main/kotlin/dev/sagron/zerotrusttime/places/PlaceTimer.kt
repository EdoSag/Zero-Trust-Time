package dev.sagron.zerotrusttime.places

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import dev.sagron.zerotrusttime.notify.RunningTimerNotification
import dev.sagron.zerotrusttime.widget.TimerWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Start and stop by place (roadmap TM-3): the phone's own LocationManager
 * watches the places (proximity alerts, no Google Play services) and the
 * location never leaves the phone.
 *
 * Arriving starts a timer and leaving stops it the same way a tap on the
 * home screen widget does: queued with the time it happened, shown on the
 * widget and in the running notification at once, and saved as an
 * encrypted, synced entry the next time the app is open and unlocked. So
 * it works while the vault is locked.
 *
 * Android keeps only what it needs to watch: each place's position and
 * radius, the project id, and whether to start and stop. No names.
 *
 * - Arriving starts a timer only when none is running.
 * - Leaving stops only a timer that this place started, and only while
 *   it still runs; a timer started or switched by hand, or by another
 *   place, is left alone.
 * - An "arrive" right after the places were set up means the phone was
 *   already there, and is ignored, as in zt_places.
 */
object PlaceTimer {
    private const val PREFS = "zt_time_places"
    private const val CHANNEL = "dev.sagron.zerotrusttime/places"
    private const val ACTION_ALERT = "dev.sagron.zerotrusttime.place.ALERT"
    private const val EXTRA_ID = "rule_id"
    private const val SETTLE_MS = 2 * 60 * 1000L

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    @Suppress("UNCHECKED_CAST")
                    val rules = call.argument<List<Map<String, Any?>>>("rules") ?: emptyList()
                    result.success(sync(app, rules))
                }
                "clear" -> {
                    sync(app, emptyList())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun hasLocation(c: Context) =
        c.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun stored(c: Context): List<JSONObject> {
        val raw = prefs(c).getString("rules", null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { array.getJSONObject(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** Watches exactly [rules]; returns how many are watched. */
    fun sync(c: Context, rules: List<Map<String, Any?>>): Int {
        val old = stored(c).map { it.optString("id") }.toSet()
        val array = JSONArray()
        for (r in rules) {
            val id = r["id"] as? String ?: continue
            val lat = (r["latitude"] as? Number)?.toDouble() ?: continue
            val lng = (r["longitude"] as? Number)?.toDouble() ?: continue
            array.put(
                JSONObject()
                    .put("id", id)
                    .put("lat", lat)
                    .put("lng", lng)
                    .put("radius", (r["radius"] as? Number)?.toDouble() ?: 150.0)
                    .put("projectId", r["projectId"] as? String ?: "")
                    .put("start", r["start"] == true)
                    .put("stop", r["stop"] == true),
            )
        }
        // The app sends the list each time it opens: leave unchanged
        // places alone, since registering again can count as arriving.
        // (Unless they weren't watched yet, before location was allowed.)
        val same = array.toString() == (prefs(c).getString("rules", null) ?: "[]")
        if (same && prefs(c).getBoolean("watching", false)) return array.length()
        val editor = prefs(c).edit().putString("rules", array.toString())
        if (array.length() == 0) editor.remove("placeStarted").remove("placeStartedBy")
        editor.apply()
        old.forEach { unwatch(c, it) }
        return watchAll(c)
    }

    /**
     * Registers every stored place (after a change, a reboot or an update).
     * An arrival in the next minutes means the phone was already there.
     */
    fun watchAll(c: Context): Int {
        prefs(c).edit().putLong("registeredAt", System.currentTimeMillis()).putBoolean("watching", false).apply()
        if (!hasLocation(c)) return 0
        var n = 0
        for (r in stored(c)) {
            try {
                c.getSystemService(LocationManager::class.java)?.addProximityAlert(
                    r.getDouble("lat"),
                    r.getDouble("lng"),
                    r.getDouble("radius").toFloat(),
                    -1,
                    alertIntent(c, r.getString("id")),
                )
                n++
            } catch (e: SecurityException) {
                // Permission taken back; the app shows it and syncs again.
            } catch (e: IllegalArgumentException) {
                // No location provider on this phone.
            }
        }
        prefs(c).edit().putBoolean("watching", n > 0).apply()
        return n
    }

    private fun unwatch(c: Context, id: String) {
        try {
            c.getSystemService(LocationManager::class.java)?.removeProximityAlert(alertIntent(c, id))
        } catch (e: SecurityException) {
            // Nothing to remove without the permission.
        }
    }

    private fun alertIntent(c: Context, id: String): PendingIntent {
        val intent = Intent(c, PlaceTimerReceiver::class.java)
            .setAction(ACTION_ALERT)
            .setData(Uri.parse("zttime://place/" + Uri.encode(id)))
            .putExtra(EXTRA_ID, id)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        // LocationManager adds KEY_PROXIMITY_ENTERING, so it must be mutable;
        // the intent is explicit, which Android 14 requires for that.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(c, id.hashCode() and 0x7fffffff, intent, flags)
    }

    internal fun onAlert(c: Context, intent: Intent) {
        if (intent.action != ACTION_ALERT) return
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val rule = stored(c).firstOrNull { it.optString("id") == id } ?: return
        val entering = intent.getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, false)
        val places = prefs(c)
        val widget = HomeWidgetPlugin.getData(c)
        val running = widget.getBoolean("time_widget_running", false)
        val runningSince = widget.getString("time_widget_start", null)?.toLongOrNull()
        if (entering) {
            if (!rule.optBoolean("start")) return
            val settled = System.currentTimeMillis() - places.getLong("registeredAt", 0) > SETTLE_MS
            if (!settled || running) return
            val projectId = rule.optString("projectId").ifEmpty { null }
            val at = TimerWidgetProvider().tap(c, start = true, projectId = projectId) ?: return
            places.edit().putLong("placeStarted", at).putString("placeStartedBy", id).apply()
            RunningTimerNotification.showStored(c, at)
        } else {
            if (!rule.optBoolean("stop")) return
            // Only the place that started the timer stops it: leaving
            // another place that overlaps it leaves the timer running.
            val started = places.getLong("placeStarted", 0)
            if (places.getString("placeStartedBy", null) != id) return
            if (!running || started == 0L || runningSince != started) return
            TimerWidgetProvider().tap(c, start = false, projectId = null)
            places.edit().remove("placeStarted").remove("placeStartedBy").apply()
        }
    }
}

/** Proximity alerts for [PlaceTimer]. Not exported: only Android's own
 *  PendingIntents reach it. */
class PlaceTimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        PlaceTimer.onAlert(context, intent)
    }
}

/** Android forgets proximity alerts on a reboot; this sets them again. */
class PlaceTimerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        PlaceTimer.watchAll(context)
    }
}
