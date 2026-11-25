package dev.sagron.zerotrusttime.places

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Start and stop by place: what counts as arriving and leaving. */
class PlaceDwellTest {
    private val min = 60_000L
    private val t0 = 1_800_000_000_000L

    /** One place and the timer, as PlaceTimer.run keeps them. */
    private class Phone(
        val startAfter: Long = 5 * 60_000L,
        val stopAfter: Long = 5 * 60_000L,
        val start: Boolean = true,
        val stop: Boolean = true,
    ) {
        var wait = PlaceWait()
        var running = false
        var mine = false
        var settled = true
        val starts = mutableListOf<Long>()
        val stops = mutableListOf<Long>()
        var checkAt: Long? = null

        fun at(now: Long, event: PlaceEvent, seen: Seen = Seen.INSIDE): PlaceStep {
            val step = PlaceDwell.step(
                wait,
                event,
                PlaceFacts(now, start, stop, startAfter, stopAfter, seen, running, mine, settled),
            )
            step.stopAt?.let {
                stops += it
                running = false
                mine = false
            }
            step.startAt?.let {
                starts += it
                running = true
                mine = true
            }
            wait = step.wait
            checkAt = step.checkAt
            return step
        }

        /** The alarm, whenever it was set for. */
        fun alarm(seen: Seen = Seen.INSIDE) = at(checkAt!!, PlaceEvent.CHECK, seen)
    }

    @Test
    fun drivingPastStartsNothing() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        assertEquals(t0 + 5 * min, phone.checkAt)
        phone.at(t0 + 40_000, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        assertTrue(phone.starts.isEmpty())
        assertTrue(phone.wait.idle)
        assertNull(phone.checkAt)
    }

    /** The afternoon that showed the bug: seven entries of 18 s to 3:40. */
    @Test
    fun aStringOfShortVisitsStartsNothing() {
        val phone = Phone()
        var now = t0
        for (seconds in listOf(96, 220, 121, 97, 40, 21, 18)) {
            phone.at(now, PlaceEvent.ENTER_OUTER)
            phone.at(now, PlaceEvent.ENTER)
            now += seconds * 1000L
            phone.at(now, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
            now += 2 * min
        }
        assertTrue(phone.starts.isEmpty())
        assertTrue(phone.stops.isEmpty())
        assertNull(phone.checkAt)
    }

    @Test
    fun stayingStartsFromTheArrival() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        // An early look changes nothing.
        phone.at(t0 + 2 * min, PlaceEvent.CHECK)
        assertTrue(phone.starts.isEmpty())
        assertEquals(t0 + 5 * min, phone.checkAt)
        // The alarm may come late; the entry still starts at the arrival.
        phone.at(t0 + 7 * min, PlaceEvent.CHECK)
        assertEquals(listOf(t0), phone.starts)
        assertTrue(phone.wait.idle)
    }

    @Test
    fun steppingOutOfTheInnerCircleIsNotLeaving() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        // Between the two circles when the wait is over: still there.
        phone.alarm(Seen.NEAR)
        assertEquals(listOf(t0), phone.starts)
    }

    @Test
    fun aVagueFixAloneNeverStarts() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER, Seen.UNSURE)
        assertEquals(t0 + min, phone.checkAt)
        var looks = 0
        while (phone.checkAt != null) {
            phone.alarm(Seen.UNSURE)
            looks++
        }
        assertTrue(phone.starts.isEmpty())
        // Gave up after half an hour instead of looking forever.
        assertTrue(looks in 25..35)
    }

    @Test
    fun aVagueArrivalCountsFromTheFirstGoodFix() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER, Seen.UNSURE)
        phone.at(t0 + min, PlaceEvent.CHECK, Seen.UNSURE)
        phone.at(t0 + 2 * min, PlaceEvent.CHECK, Seen.INSIDE)
        assertTrue(phone.starts.isEmpty())
        assertEquals(t0 + 7 * min, phone.checkAt)
        phone.alarm()
        assertEquals(listOf(t0 + 2 * min), phone.starts)
    }

    @Test
    fun aGoodArrivalSurvivesVagueFixesIndoors() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER, Seen.INSIDE)
        phone.alarm(Seen.UNSURE)
        assertEquals(listOf(t0), phone.starts)
    }

    @Test
    fun aGoodFixOutsideTakesTheArrivalBack() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER, Seen.INSIDE)
        phone.alarm(Seen.OUTSIDE)
        assertTrue(phone.starts.isEmpty())
        phone.alarm(Seen.INSIDE)
        assertTrue(phone.starts.isEmpty())
        phone.alarm(Seen.INSIDE)
        assertEquals(listOf(t0 + 6 * min), phone.starts)
    }

    @Test
    fun leavingStopsAsOfTheLeaving() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        phone.alarm()
        val left = t0 + 90 * min
        phone.at(left, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        assertTrue(phone.stops.isEmpty())
        assertEquals(left + 5 * min, phone.checkAt)
        phone.at(left + 8 * min, PlaceEvent.CHECK, Seen.OUTSIDE)
        assertEquals(listOf(left), phone.stops)
        assertNull(phone.checkAt)
    }

    @Test
    fun comingBackSoonKeepsTheTimer() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        phone.alarm()
        val left = t0 + 90 * min
        phone.at(left, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        phone.at(left + 2 * min, PlaceEvent.ENTER_OUTER, Seen.NEAR)
        assertNull(phone.checkAt)
        phone.at(left + 2 * min, PlaceEvent.ENTER, Seen.INSIDE)
        phone.at(left + 9 * min, PlaceEvent.CHECK)
        assertTrue(phone.stops.isEmpty())
        assertEquals(listOf(t0), phone.starts)
    }

    @Test
    fun aVagueFixDoesNotCallOffLeaving() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        phone.alarm()
        val left = t0 + 90 * min
        phone.at(left, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        phone.at(left + min, PlaceEvent.ENTER_OUTER, Seen.UNSURE)
        phone.at(left + min, PlaceEvent.ENTER, Seen.UNSURE)
        // The good fix that follows: gone again.
        phone.at(left + 2 * min, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        phone.alarm(Seen.OUTSIDE)
        assertEquals(listOf(left), phone.stops)
        assertTrue(phone.wait.idle)
    }

    @Test
    fun aVagueReturnThatWasRealKeepsTheTimer() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        phone.alarm()
        val left = t0 + 90 * min
        phone.at(left, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        phone.at(left + min, PlaceEvent.ENTER, Seen.UNSURE)
        phone.alarm(Seen.INSIDE)
        assertTrue(phone.stops.isEmpty())
        assertTrue(phone.wait.idle)
    }

    @Test
    fun aVagueReturnStillUnsureStopsThenWaitsForAGoodFix() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        phone.alarm()
        val left = t0 + 90 * min
        phone.at(left, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        phone.at(left + min, PlaceEvent.ENTER, Seen.UNSURE)
        phone.alarm(Seen.UNSURE)
        assertEquals(listOf(left), phone.stops)
        // Really back: a good fix starts a new timer after the wait.
        phone.alarm(Seen.INSIDE)
        phone.alarm(Seen.INSIDE)
        assertEquals(listOf(t0, left + 6 * min), phone.starts)
    }

    @Test
    fun onlyThePlacesOwnTimerIsStopped() {
        val phone = Phone()
        phone.running = true // started by hand, or by another place
        phone.at(t0, PlaceEvent.ENTER)
        assertTrue(phone.wait.idle)
        phone.at(t0 + 60 * min, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        assertTrue(phone.wait.idle)
        assertTrue(phone.stops.isEmpty())
    }

    @Test
    fun aTimerStoppedByHandWhileLeavingIsLeftAlone() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        phone.alarm()
        phone.at(t0 + 60 * min, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        phone.running = false
        phone.mine = false
        phone.alarm(Seen.OUTSIDE)
        assertTrue(phone.stops.isEmpty())
        assertNull(phone.checkAt)
    }

    @Test
    fun aTimerStartedByHandWhileArrivingWins() {
        val phone = Phone()
        phone.at(t0, PlaceEvent.ENTER)
        phone.running = true
        phone.alarm()
        assertTrue(phone.starts.isEmpty())
        assertTrue(phone.wait.idle)
    }

    @Test
    fun alreadyThereWhenThePlacesWereSetUp() {
        val phone = Phone()
        phone.settled = false
        phone.at(t0, PlaceEvent.ENTER)
        assertTrue(phone.wait.idle)
    }

    @Test
    fun rightAwayStillWorks() {
        val phone = Phone(startAfter = 0, stopAfter = 0)
        phone.at(t0, PlaceEvent.ENTER)
        assertEquals(listOf(t0), phone.starts)
        phone.at(t0 + 30 * min, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        assertEquals(listOf(t0 + 30 * min), phone.stops)
        assertNull(phone.checkAt)
    }

    @Test
    fun switchedOffHalvesDoNothing() {
        val noStart = Phone(start = false)
        noStart.at(t0, PlaceEvent.ENTER)
        assertTrue(noStart.wait.idle)
        val noStop = Phone(stop = false)
        noStop.at(t0, PlaceEvent.ENTER)
        noStop.alarm()
        noStop.at(t0 + 60 * min, PlaceEvent.LEAVE_OUTER, Seen.OUTSIDE)
        assertTrue(noStop.wait.idle)
        assertTrue(noStop.stops.isEmpty())
    }

    @Test
    fun whatAFixSays() {
        // Nothing to go by: Android's own word.
        assertEquals(Seen.INSIDE, PlaceDwell.see(null, null, 100f))
        assertEquals(Seen.INSIDE, PlaceDwell.see(80f, 20f, 100f))
        assertEquals(Seen.NEAR, PlaceDwell.see(120f, 20f, 100f))
        assertEquals(Seen.OUTSIDE, PlaceDwell.see(141f, 20f, 100f))
        // A kilometre off but "good to 1.5 km": Android calls that inside.
        assertEquals(Seen.UNSURE, PlaceDwell.see(1000f, 1500f, 100f))
        assertEquals(Seen.UNSURE, PlaceDwell.see(10f, 101f, 100f))
        // A small place needs a fix good to 50 m, not to its own 30.
        assertEquals(Seen.INSIDE, PlaceDwell.see(20f, 45f, 30f))
        assertEquals(Seen.UNSURE, PlaceDwell.see(20f, 60f, 30f))
        // A big place can tell from a rough fix.
        assertEquals(Seen.INSIDE, PlaceDwell.see(600f, 400f, 1000f))
    }

    @Test
    fun leavingIsFurtherOutThanArriving() {
        assertEquals(90f, PlaceDwell.outerRadius(50f))
        assertEquals(140f, PlaceDwell.outerRadius(100f))
        assertEquals(1250f, PlaceDwell.outerRadius(1000f))
    }
}
