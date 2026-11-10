package dev.sagron.zerotrusttime.widget

import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import dev.sagron.zerotrusttime.MainActivity
import dev.sagron.zerotrusttime.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Timer widget (roadmap W14): a live clock and Stop while a timer runs;
 * Start, and recent projects to start with one tap, when none does.
 *
 * It renders only what the app wrote (lib/widget/timer_widget.dart) and
 * never reads the vault. A Start or Stop tapped here is queued under
 * `time_widget_pending` with the time of the tap, and the widget shows the
 * new state at once; the app saves it (as an encrypted, synced entry) the
 * next time it is open and unlocked.
 *
 * Shared Zero-Trust widget look (Zero-Trust-Core/android-widget-kit).
 */
class TimerWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val ACTION_START = "dev.sagron.zerotrusttime.widget.START"
        private const val ACTION_STOP = "dev.sagron.zerotrusttime.widget.STOP"
        private const val EXTRA_PROJECT = "project_id"
        private const val MAX_RECENT = 3

        /** The "timer running" notification's id (lib/notify/timer_notifier.dart). */
        private const val RUNNING_NOTIFICATION_ID = 1

        private val RECENT = intArrayOf(R.id.recent_0, R.id.recent_1, R.id.recent_2)
        private val RECENT_NAMES = intArrayOf(R.id.recent_0_name, R.id.recent_1_name, R.id.recent_2_name)
        private val RECENT_DOTS = intArrayOf(R.id.recent_0_dot, R.id.recent_1_dot, R.id.recent_2_dot)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, buildViews(context, widgetData, appWidgetManager.getAppWidgetOptions(id)))
        }
    }

    /** Resized: show the header and recent projects only when they fit. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, HomeWidgetPlugin.getData(context), newOptions))
    }

    /** Called by [TimerWidgetTapReceiver] for a Start or Stop on the widget. */
    internal fun onTap(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_START -> tap(context, start = true, projectId = intent.getStringExtra(EXTRA_PROJECT))
            ACTION_STOP -> tap(context, start = false, projectId = null)
        }
    }

    private fun tap(context: Context, start: Boolean, projectId: String?) {
        val prefs = HomeWidgetPlugin.getData(context)
        if (prefs.getBoolean("time_widget_signed_out", false)) return
        val now = System.currentTimeMillis()
        val line = if (start) "start|$now|${projectId.orEmpty()}" else "stop|$now"
        val queue = prefs.getString("time_widget_pending", null).orEmpty()
        val editor = prefs.edit()
            .putString("time_widget_pending", if (queue.isEmpty()) line else "$queue\n$line")
            .putBoolean("time_widget_running", start)
            .putString("time_widget_start", if (start) now.toString() else null)
        if (start) {
            val index = (0 until MAX_RECENT).firstOrNull { prefs.getString("time_widget_recent_${it}_id", null) == projectId }
            editor.putString(
                "time_widget_title",
                index?.let { prefs.getString("time_widget_recent_${it}_name", null) } ?: "Timer running",
            )
            editor.putString("time_widget_color", index?.let { prefs.getString("time_widget_recent_${it}_color", null) })
        } else {
            // The app clears its notification when it next opens; don't leave
            // a clock running in the shade until then.
            context.getSystemService(NotificationManager::class.java)?.cancel(RUNNING_NOTIFICATION_ID)
        }
        editor.apply()
        val manager = AppWidgetManager.getInstance(context)
        manager.getAppWidgetIds(ComponentName(context, TimerWidgetProvider::class.java)).forEach {
            manager.updateAppWidget(it, buildViews(context, prefs, manager.getAppWidgetOptions(it)))
        }
    }

    private fun buildViews(context: Context, prefs: SharedPreferences, options: Bundle?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_timer)
        // Portrait size; 0 when the launcher hasn't said yet.
        val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        val signedOut = prefs.getBoolean("time_widget_signed_out", false)
        val start = prefs.getString("time_widget_start", null)?.toLongOrNull()
        val running = !signedOut && prefs.getBoolean("time_widget_running", false) && start != null

        views.setViewVisibility(R.id.app_row, if (height == 0 || height >= 130) View.VISIBLE else View.GONE)
        views.setOnClickPendingIntent(R.id.main_text, open(context))
        views.setOnClickPendingIntent(R.id.app_row, open(context))

        if (running) {
            // Chronometer counts from an elapsedRealtime base.
            val base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - start!!).coerceAtLeast(0)
            views.setChronometer(R.id.clock, base, null, true)
            views.setViewVisibility(R.id.clock, View.VISIBLE)
            views.setViewVisibility(R.id.idle_text, View.GONE)
            views.setTextViewText(R.id.title, prefs.getString("time_widget_title", null) ?: "Timer running")
            views.setImageViewResource(R.id.action, R.drawable.ic_zt_widget_stop)
            views.setContentDescription(R.id.action, "Stop the timer")
            views.setOnClickPendingIntent(R.id.action, broadcast(context, ACTION_STOP, null, 0))
        } else {
            views.setChronometer(R.id.clock, SystemClock.elapsedRealtime(), null, false)
            views.setViewVisibility(R.id.clock, View.GONE)
            views.setViewVisibility(R.id.idle_text, View.VISIBLE)
            views.setTextViewText(R.id.idle_text, if (signedOut) "Signed out" else "Not tracking")
            views.setTextViewText(
                R.id.title,
                if (signedOut) "Open ZT Time to start tracking" else "Tap play to start a timer",
            )
            if (signedOut) {
                views.setImageViewResource(R.id.action, R.drawable.ic_zt_widget_lock)
                views.setInt(R.id.action, "setBackgroundResource", R.drawable.zt_widget_tile_circle)
                views.setInt(R.id.action, "setColorFilter", context.getColor(R.color.zt_widget_on_surface_variant))
                views.setContentDescription(R.id.action, "Open ZT Time")
                views.setOnClickPendingIntent(R.id.action, open(context))
            } else {
                views.setImageViewResource(R.id.action, R.drawable.ic_zt_widget_play)
                views.setContentDescription(R.id.action, "Start a timer")
                views.setOnClickPendingIntent(R.id.action, broadcast(context, ACTION_START, null, 0))
            }
        }

        // Recent projects: only when idle, with details on, and room for them.
        val count = prefs.getInt("time_widget_recent_count", 0).coerceIn(0, MAX_RECENT)
        val fits = if (width == 0) MAX_RECENT else ((width - 28 + 6) / 96).coerceIn(0, MAX_RECENT)
        val roomBelow = height == 0 || height >= 110
        val shown = if (running || signedOut || !roomBelow) 0 else minOf(count, fits)
        views.setViewVisibility(R.id.recent_row, if (shown > 0) View.VISIBLE else View.GONE)
        for (i in 0 until MAX_RECENT) {
            val id = prefs.getString("time_widget_recent_${i}_id", null)
            if (i >= shown || id == null) {
                views.setViewVisibility(RECENT[i], View.GONE)
                continue
            }
            views.setViewVisibility(RECENT[i], View.VISIBLE)
            views.setTextViewText(RECENT_NAMES[i], prefs.getString("time_widget_recent_${i}_name", null) ?: "")
            val color = try {
                Color.parseColor(prefs.getString("time_widget_recent_${i}_color", null) ?: "#3B82F6")
            } catch (e: Exception) {
                Color.GRAY
            }
            views.setInt(RECENT_DOTS[i], "setColorFilter", color)
            views.setContentDescription(RECENT[i], "Start a timer for ${prefs.getString("time_widget_recent_${i}_name", null) ?: "this project"}")
            views.setOnClickPendingIntent(RECENT[i], broadcast(context, ACTION_START, id, i + 1))
        }
        return views
    }

    private fun open(context: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("zttime://open"))

    private fun broadcast(context: Context, action: String, projectId: String?, requestCode: Int): PendingIntent {
        val intent = Intent(context, TimerWidgetTapReceiver::class.java).setAction(action)
        if (projectId != null) {
            intent.putExtra(EXTRA_PROJECT, projectId)
            // Distinct data per project, or Android reuses one PendingIntent.
            intent.data = Uri.parse("zttime://start/" + Uri.encode(projectId))
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/**
 * Receives the widget's own Start and Stop taps. Not exported, so only this
 * app's PendingIntents reach it; no other app can start or stop a timer.
 */
class TimerWidgetTapReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        TimerWidgetProvider().onTap(context, intent)
    }
}
