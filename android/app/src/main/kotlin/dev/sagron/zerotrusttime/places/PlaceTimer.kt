package dev.sagron.zerotrusttime.places

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
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
 * - Passing by starts nothing: a timer starts only after staying a few
 *   minutes and stops only after being away a few minutes, each place
 *   with its own times. Android's alerts alone flap (a drive past, a poor
 *   fix); PlaceDwell.kt says how they are told from a real arrival.
 *
 * Each place is watched twice: its own circle, whose crossing inwards is
 * arriving, and a wider one, whose crossing outwards is leaving.
 */
object PlaceTimer {
    private const val PREFS = "zt_time_places"
    private const val CHANNEL = "dev.sagron.zerotrusttime/places"
    private const val ACTION_ALERT = "dev.sagron.zerotrusttime.place.ALERT"
    private const val ACTION_CHECK = "dev.sagron.zerotrusttime.place.CHECK"
    private const val EXTRA_ID = "rule_id"
    private const val EXTRA_OUTER = "outer"
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

    /** What each place is waiting for (PlaceDwell.kt), by rule id. */
    private fun waits(c: Context): MutableMap<String, PlaceWait> {
        val out = mutableMapOf<String, PlaceWait>()
        val raw = prefs(c).getString("waits", null) ?: return out
        try {
            val all = JSONObject(raw)
            for (id in all.keys()) {
                val w = all.getJSONObject(id)
                out[id] = PlaceWait(
                    arriveFirst = w.optLong("first"),
                    arriveSeen = w.optLong("seen"),
                    leaveAt = w.optLong("leave"),
                    backAt = w.optLong("back"),
                )
            }
        } catch (e: Exception) {
            out.clear()
        }
        return out
    }

    private fun saveWaits(c: Context, waits: Map<String, PlaceWait>) {
        val all = JSONObject()
        for ((id, w) in waits) {
            if (w.idle) continue
            all.put(
                id,
                JSONObject().put("first", w.arriveFirst).put("seen", w.arriveSeen).put("leave", w.leaveAt).put("back", w.backAt),
            )
        }
        prefs(c).edit().putString("waits", all.toString()).apply()
    }

    private fun minutes(rule: JSONObject, key: String, fallback: Int) =
        rule.optInt(key, fallback).coerceIn(0, 60) * 60_000L

    /** Watches exactly [rules]; returns how many are watched. */
    fun sync(c: Context, rules: List<Map<String, Any?>>): Int {
        val before = stored(c).associate { it.optString("id") to it.toString() }
        val old = before.keys
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
                    .put("stop", r["stop"] == true)
                    .put("startAfter", (r["startAfter"] as? Number)?.toInt() ?: PlaceDwell.DEFAULT_START_AFTER_MIN)
                    .put("stopAfter", (r["stopAfter"] as? Number)?.toInt() ?: PlaceDwell.DEFAULT_STOP_AFTER_MIN),
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
        // A place that went is forgotten, and one that changed looks for
        // an arrival afresh (a timer waiting to be stopped still is).
        val now = stored(c).associate { it.optString("id") to it.toString() }
        saveWaits(
            c,
            waits(c).filterKeys { it in now }.mapValues { (id, w) ->
                if (before[id] == now[id]) w else w.copy(arriveFirst = 0, arriveSeen = 0)
            },
        )
        old.forEach { unwatch(c, it) }
        val n = watchAll(c)
        run(c, emptyMap())
        return n
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
                val locations = c.getSystemService(LocationManager::class.java)
                val radius = r.getDouble("radius").toFloat()
                for (outer in listOf(false, true)) {
                    locations?.addProximityAlert(
                        r.getDouble("lat"),
                        r.getDouble("lng"),
                        if (outer) PlaceDwell.outerRadius(radius) else radius,
                        -1,
                        alertIntent(c, r.getString("id"), outer),
                    )
                }
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

    /**
     * After a reboot Android has forgotten the places and the alarm; after
     * an update the places may need their wider circle watched too.
     */
    fun restore(c: Context, rebooted: Boolean) {
        if (rebooted) {
            // Whether the phone is still at a place it had just reached is
            // unknown now; a timer waiting to be stopped still is.
            saveWaits(c, waits(c).mapValues { it.value.copy(arriveFirst = 0, arriveSeen = 0) })
        }
        watchAll(c)
        run(c, emptyMap())
    }

    private fun unwatch(c: Context, id: String) {
        for (outer in listOf(false, true)) {
            try {
                c.getSystemService(LocationManager::class.java)?.removeProximityAlert(alertIntent(c, id, outer))
            } catch (e: SecurityException) {
                // Nothing to remove without the permission.
            }
        }
    }

    private fun alertIntent(c: Context, id: String, outer: Boolean): PendingIntent {
        val intent = Intent(c, PlaceTimerReceiver::class.java)
            .setAction(ACTION_ALERT)
            .setData(Uri.parse((if (outer) "zttime://place-outer/" else "zttime://place/") + Uri.encode(id)))
            .putExtra(EXTRA_ID, id)
            .putExtra(EXTRA_OUTER, outer)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        // LocationManager adds KEY_PROXIMITY_ENTERING, so it must be mutable;
        // the intent is explicit, which Android 14 requires for that.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(c, id.hashCode() and 0x7fffffff, intent, flags)
    }

    private fun checkIntent(c: Context): PendingIntent = PendingIntent.getBroadcast(
        c,
        0,
        Intent(c, PlaceTimerReceiver::class.java).setAction(ACTION_CHECK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /**
     * Wakes [PlaceTimerReceiver] at [at] to look again, or not at all.
     * Not to the minute: Android may deliver it somewhat late, which only
     * delays when the timer shows up, since entries get the time the phone
     * arrived or left.
     */
    private fun wakeAt(c: Context, at: Long?) {
        val alarms = c.getSystemService(AlarmManager::class.java) ?: return
        val check = checkIntent(c)
        if (at == null) {
            alarms.cancel(check)
            return
        }
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, check)
    }

    /** The newest fix the phone has, the one Android's alert came from. */
    private fun lastFix(c: Context): Location? {
        val locations = c.getSystemService(LocationManager::class.java) ?: return null
        val providers =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && locations.hasProvider(LocationManager.FUSED_PROVIDER)) {
                listOf(LocationManager.FUSED_PROVIDER)
            } else {
                listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            }
        return providers.mapNotNull {
            try {
                locations.getLastKnownLocation(it)
            } catch (e: SecurityException) {
                null
            } catch (e: IllegalArgumentException) {
                null
            }
        }.maxByOrNull { it.time }
    }

    private fun seen(rule: JSONObject, fix: Location?): Seen {
        val radius = rule.optDouble("radius", 150.0).toFloat()
        if (fix == null) return PlaceDwell.see(null, null, radius)
        val distance = FloatArray(1)
        Location.distanceBetween(fix.latitude, fix.longitude, rule.optDouble("lat"), rule.optDouble("lng"), distance)
        return PlaceDwell.see(distance[0], if (fix.hasAccuracy()) fix.accuracy else null, radius)
    }

    internal fun onAlert(c: Context, intent: Intent) {
        when (intent.action) {
            ACTION_CHECK -> run(c, emptyMap())
            ACTION_ALERT -> {
                val id = intent.getStringExtra(EXTRA_ID) ?: return
                val entering = intent.getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, false)
                val outer = intent.getBooleanExtra(EXTRA_OUTER, false)
                val event = when {
                    entering && outer -> PlaceEvent.ENTER_OUTER
                    entering -> PlaceEvent.ENTER
                    outer -> PlaceEvent.LEAVE_OUTER
                    // Out of the place's own circle isn't gone yet.
                    else -> return
                }
                run(c, mapOf(id to event))
            }
        }
    }

    /**
     * Takes in [events] (by rule id), starts and stops what is due by now
     * at every place, and sets the alarm for whatever is due next.
     */
    private fun run(c: Context, events: Map<String, PlaceEvent>) {
        val places = prefs(c)
        val waits = waits(c)
        val now = System.currentTimeMillis()
        val settled = now - places.getLong("registeredAt", 0) > SETTLE_MS
        val fix = if (events.isEmpty() && waits.isEmpty()) null else lastFix(c)
        var next: Long? = null
        for (rule in stored(c)) {
            val id = rule.optString("id")
            val wait = waits[id] ?: PlaceWait()
            val event = events[id] ?: PlaceEvent.CHECK
            if (event == PlaceEvent.CHECK && wait.idle) continue
            // Read for each place: one place's stop frees the next to start.
            val widget = HomeWidgetPlugin.getData(c)
            val running = widget.getBoolean("time_widget_running", false)
            val runningSince = widget.getString("time_widget_start", null)?.toLongOrNull()
            val started = places.getLong("placeStarted", 0)
            // Only the place that started the timer stops it: leaving
            // another place that overlaps it leaves the timer running.
            val mine = running && started != 0L && runningSince == started &&
                places.getString("placeStartedBy", null) == id
            val step = PlaceDwell.step(
                wait,
                event,
                PlaceFacts(
                    now = now,
                    start = rule.optBoolean("start"),
                    stop = rule.optBoolean("stop"),
                    startAfterMs = minutes(rule, "startAfter", PlaceDwell.DEFAULT_START_AFTER_MIN),
                    stopAfterMs = minutes(rule, "stopAfter", PlaceDwell.DEFAULT_STOP_AFTER_MIN),
                    seen = seen(rule, fix),
                    timerRunning = running,
                    mine = mine,
                    settled = settled,
                ),
            )
            val stop = {
                step.stopAt?.let {
                    TimerWidgetProvider().tap(c, start = false, projectId = null, at = it)
                    places.edit().remove("placeStarted").remove("placeStartedBy").apply()
                }
            }
            val start = {
                step.startAt?.let {
                    val projectId = rule.optString("projectId").ifEmpty { null }
                    val at = TimerWidgetProvider().tap(c, start = true, projectId = projectId, at = it)
                    if (at != null) {
                        places.edit().putLong("placeStarted", at).putString("placeStartedBy", id).apply()
                        RunningTimerNotification.showStored(c, at)
                    }
                }
            }
            // In the order they happened (PlaceStep.startAt).
            val startFirst = step.startAt != null && step.stopAt != null && step.startAt <= step.stopAt
            if (startFirst) start() else stop()
            if (startFirst) stop() else start()
            waits[id] = step.wait
            step.checkAt?.let { at -> next = minOf(next ?: at, at) }
        }
        saveWaits(c, waits)
        wakeAt(c, next)
    }
}

/** Proximity alerts and the "look again" alarm for [PlaceTimer]. Not
 *  exported: only Android's own PendingIntents reach it. */
class PlaceTimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        PlaceTimer.onAlert(context, intent)
    }
}

/** Android forgets proximity alerts on a reboot; this sets them again
 *  (and, after an update, watches each place's wider circle too). */
class PlaceTimerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        PlaceTimer.restore(context, rebooted = intent.action == Intent.ACTION_BOOT_COMPLETED)
    }
}
