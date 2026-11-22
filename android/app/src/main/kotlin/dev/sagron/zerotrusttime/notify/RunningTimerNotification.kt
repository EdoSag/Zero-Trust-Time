package dev.sagron.zerotrusttime.notify

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import dev.sagron.zerotrusttime.MainActivity
import dev.sagron.zerotrusttime.R
import dev.sagron.zerotrusttime.widget.TimerWidgetProvider
import dev.sagron.zerotrusttime.widget.TimerWidgetTapReceiver
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The "timer running" notification (lib/notify/timer_notifier.dart), with
 * a live clock and a Stop button.
 *
 * Posted here rather than through flutter_local_notifications so that Stop
 * can go to the same receiver as the home screen widget's Stop: it queues
 * the stop with the time it was tapped, takes the notification down and
 * updates the widget, all without the vault. The app saves the stop (as an
 * encrypted, synced entry) the next time it is open and unlocked, exactly
 * like a Stop tapped on the widget.
 */
object RunningTimerNotification {
    /** Same id the app used before, so an older notification is replaced. */
    const val ID = 1
    private const val CHANNEL = "timer_running"
    private const val METHOD_CHANNEL = "dev.sagron.zerotrusttime/running_notification"

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val start = call.argument<Number>("start")?.toLong()
                    if (start == null) {
                        result.error("bad_args", "start missing", null)
                        return@setMethodCallHandler
                    }
                    show(
                        app,
                        start = start,
                        title = call.argument<String>("title") ?: "",
                        body = call.argument<String>("body") ?: "",
                        stopLabel = call.argument<String>("stop") ?: "Stop",
                        channelName = call.argument<String>("channelName") ?: "Running timer",
                        channelDescription = call.argument<String>("channelDescription") ?: "",
                    )
                    result.success(null)
                }
                "clear" -> {
                    app.getSystemService(NotificationManager::class.java)?.cancel(ID)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun show(
        context: Context,
        start: Long,
        title: String,
        body: String,
        stopLabel: String,
        channelName: String,
        channelDescription: String,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        // Low importance: no sound, no peeking banner. Renames follow the
        // app's language; Android keeps the user's own channel settings.
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, channelName, NotificationManager.IMPORTANCE_LOW).apply {
                description = channelDescription
                setShowBadge(false)
            },
        )
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getBroadcast(
            context,
            // Its own request code, apart from the widget's buttons (0-3).
            100,
            Intent(context, TimerWidgetTapReceiver::class.java).setAction(TimerWidgetProvider.ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(start)
            .setUsesChronometer(true)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            // The lock screen shows "ZT Time", not what is being tracked.
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(
                Notification.Action.Builder(
                    android.graphics.drawable.Icon.createWithResource(context, R.drawable.ic_zt_widget_stop),
                    stopLabel,
                    stop,
                ).build(),
            )
            .build()
        manager.notify(ID, notification)
    }
}
