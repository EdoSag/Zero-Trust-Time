package dev.sagron.zerotrusttime.places

/**
 * The decisions of start and stop by place, kept apart from Android so
 * they can be tested (PlaceDwellTest): when an arrival or a leaving that
 * Android reports is real, and when it is only the phone passing by or a
 * poor location fix.
 *
 * Android's own proximity alerts flap. They count a fix as "at the place"
 * whenever the place lies within the fix's own margin of error, so one
 * vague fix a kilometre away is an arrival and the next good one is a
 * leaving; and a drive past a place crosses its circle for real. Acting on
 * each alert at once made a string of timers a few seconds long. So:
 *
 * - **Wait.** A timer starts only after the phone has stayed for the
 *   place's "start after" time, and stops only after it has been away for
 *   its "stop after" time. Leaving before the first is over starts
 *   nothing; coming back before the second is over leaves the timer
 *   running. The entry still begins when the phone arrived and ends when
 *   it left, not when the wait was over.
 * - **Leave further out than you arrive.** Arriving is crossing the
 *   place's own circle; leaving is crossing a wider one ([outerRadius]).
 *   A phone resting near the edge doesn't go in and out.
 * - **Believe only a good fix.** An arrival counts from the first fix that
 *   is good enough to tell and puts the phone inside the circle ([see]).
 *   A vague fix alone never starts a timer, and doesn't call off a
 *   leaving.
 */
internal object PlaceDwell {
    /** While waiting for a fix good enough to tell, look again this often. */
    const val RECHECK_MS = 60_000L

    /** An arrival no good fix confirmed in this time is dropped. */
    const val GIVE_UP_MS = 30 * 60_000L

    /** A fix this exact can always tell, however small the place. */
    const val GOOD_ACCURACY_M = 50f

    const val DEFAULT_START_AFTER_MIN = 5
    const val DEFAULT_STOP_AFTER_MIN = 5

    /** The wider circle whose crossing counts as leaving. */
    fun outerRadius(radius: Float): Float = radius + maxOf(40f, radius * 0.25f)

    /**
     * Where the last location fix puts the phone, [distance] metres from
     * the place's centre and good to [accuracy] metres. With no fix to go
     * by, Android's own word (the alert) is trusted.
     */
    fun see(distance: Float?, accuracy: Float?, radius: Float): Seen = when {
        distance == null -> Seen.INSIDE
        (accuracy ?: 0f) > maxOf(radius, GOOD_ACCURACY_M) -> Seen.UNSURE
        distance <= radius -> Seen.INSIDE
        distance <= outerRadius(radius) -> Seen.NEAR
        else -> Seen.OUTSIDE
    }

    /** What [event] at one place changes, and what is due by now. */
    fun step(wait: PlaceWait, event: PlaceEvent, f: PlaceFacts): PlaceStep {
        var w = wait
        when (event) {
            PlaceEvent.ENTER, PlaceEvent.ENTER_OUTER ->
                if (w.leaveAt != 0L) {
                    // Back before the timer was stopped: it keeps running.
                    // A vague fix can't say so; it is looked at again when
                    // the stop is due.
                    w = if (f.seen == Seen.UNSURE) {
                        w.copy(backAt = if (w.backAt == 0L) f.now else w.backAt)
                    } else {
                        w.copy(leaveAt = 0, backAt = 0)
                    }
                } else if (event == PlaceEvent.ENTER && f.start && f.settled && !f.timerRunning && w.arriveFirst == 0L) {
                    w = w.copy(arriveFirst = f.now, arriveSeen = 0)
                }
            PlaceEvent.LEAVE_OUTER -> {
                // Gone before the wait was over: it was only passing by.
                w = w.copy(arriveFirst = 0, arriveSeen = 0, backAt = 0)
                if (f.stop && f.mine && w.leaveAt == 0L) w = w.copy(leaveAt = f.now)
            }
            PlaceEvent.CHECK -> Unit
        }

        var stopAt: Long? = null
        var startAt: Long? = null
        var running = f.timerRunning

        if (w.leaveAt != 0L) {
            if (!f.mine) {
                // Stopped or switched by hand meanwhile: nothing to stop.
                w = w.copy(leaveAt = 0, backAt = 0)
            } else if (f.now - w.leaveAt >= f.stopAfterMs) {
                if (w.backAt != 0L && (f.seen == Seen.INSIDE || f.seen == Seen.NEAR)) {
                    // The vague "back" was right after all.
                    w = w.copy(leaveAt = 0, backAt = 0)
                } else {
                    stopAt = w.leaveAt
                    running = false
                    // Still maybe back: wait for a fix that can tell.
                    val back = w.backAt != 0L && f.start
                    w = w.copy(leaveAt = 0, backAt = 0, arriveFirst = if (back) f.now else 0, arriveSeen = 0)
                }
            }
        }

        if (w.arriveFirst != 0L) {
            if (running || f.now - w.arriveFirst > GIVE_UP_MS) {
                // A timer was started by hand, or no fix ever confirmed it.
                w = w.copy(arriveFirst = 0, arriveSeen = 0)
            } else {
                if (f.seen == Seen.OUTSIDE) w = w.copy(arriveSeen = 0)
                if (f.seen == Seen.INSIDE && w.arriveSeen == 0L) w = w.copy(arriveSeen = f.now)
                // Seen inside once, and nothing since says otherwise.
                if (w.arriveSeen != 0L && f.seen != Seen.OUTSIDE && f.now - w.arriveSeen >= f.startAfterMs) {
                    startAt = w.arriveSeen
                    w = w.copy(arriveFirst = 0, arriveSeen = 0)
                }
            }
        }

        val checks = mutableListOf<Long>()
        if (w.leaveAt != 0L) checks += w.leaveAt + f.stopAfterMs
        if (w.arriveFirst != 0L) {
            val due = if (w.arriveSeen != 0L) w.arriveSeen + f.startAfterMs else 0L
            checks += if (due > f.now) due else f.now + RECHECK_MS
        }
        return PlaceStep(w, stopAt = stopAt, startAt = startAt, checkAt = checks.minOrNull())
    }
}

/** Where a location fix puts the phone. */
internal enum class Seen {
    /** Good enough to tell, and inside the place's circle. */
    INSIDE,

    /** Good enough to tell, and between the place's circle and the wider one. */
    NEAR,

    /** Good enough to tell, and outside both. */
    OUTSIDE,

    /** Too vague to tell. */
    UNSURE,
}

internal enum class PlaceEvent {
    /** Android says the phone crossed into the place's circle. */
    ENTER,

    /** ... into the wider circle. */
    ENTER_OUTER,

    /** ... out of the wider circle. */
    LEAVE_OUTER,

    /** Nothing new: only what is due by now. */
    CHECK,
}

/** What one place is waiting for. A time of 0 means not waiting. */
internal data class PlaceWait(
    /** Android reported an arrival then; no timer started yet. */
    val arriveFirst: Long = 0,
    /** A good fix first put the phone inside then; the entry starts here. */
    val arriveSeen: Long = 0,
    /** The phone left then; the timer stops once it has stayed away. */
    val leaveAt: Long = 0,
    /** While leaving, a vague fix said the phone was back. */
    val backAt: Long = 0,
) {
    val idle: Boolean get() = arriveFirst == 0L && leaveAt == 0L
}

internal data class PlaceFacts(
    val now: Long,
    /** The place starts timers; it stops them. */
    val start: Boolean,
    val stop: Boolean,
    val startAfterMs: Long,
    val stopAfterMs: Long,
    val seen: Seen,
    /** Any timer is running. */
    val timerRunning: Boolean,
    /** The running timer is the one this place started. */
    val mine: Boolean,
    /** The places weren't just set up (see PlaceTimer). */
    val settled: Boolean,
)

internal data class PlaceStep(
    val wait: PlaceWait,
    /** Stop the timer, as of this time. */
    val stopAt: Long? = null,
    /** Start a timer, as of this time. */
    val startAt: Long? = null,
    /** Look again at this time. */
    val checkAt: Long? = null,
)
