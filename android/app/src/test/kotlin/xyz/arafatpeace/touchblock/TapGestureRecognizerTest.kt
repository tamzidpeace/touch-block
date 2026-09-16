package xyz.arafatpeace.touchblock

import org.junit.Assert.assertEquals
import org.junit.Test

class TapGestureRecognizerTest {
    @Test
    fun isolatedTapWhileUnlockedLocksAfterTimeout() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.SCHEDULE_LOCK, recognizer.onTap(100, false))
        assertEquals(TapDecision.LOCK, recognizer.onLockTimeout(400))
    }

    @Test
    fun multiTapWhileUnlockedCancelsPendingLock() {
        val recognizer = TapGestureRecognizer(3)

        assertEquals(TapDecision.SCHEDULE_LOCK, recognizer.onTap(100, false))
        assertEquals(
            TapDecision.CANCEL_PENDING_LOCK,
            recognizer.onTap(200, false),
        )
        assertEquals(TapDecision.NONE, recognizer.onTap(250, false))
        assertEquals(TapDecision.NONE, recognizer.onLockTimeout(400))
    }

    @Test
    fun doubleTapUnlocksOnSecondTap() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(200, true))
    }

    @Test
    fun tripleTapNeedsThreeTaps() {
        val recognizer = TapGestureRecognizer(3)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        assertEquals(TapDecision.NONE, recognizer.onTap(200, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(250, true))
    }

    @Test
    fun sequenceExpiresAndStartsAgain() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        assertEquals(TapDecision.NONE, recognizer.onTap(500, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(600, true))
    }

    @Test
    fun resetCancelsASequenceAfterDrag() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.SCHEDULE_LOCK, recognizer.onTap(100, false))
        recognizer.reset()

        assertEquals(TapDecision.NONE, recognizer.onLockTimeout(400))
    }

    @Test
    fun tapAfterUnlockIsConsumedWithinTheSameWindow() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(200, true))
        assertEquals(TapDecision.NONE, recognizer.onTap(250, false))
        assertEquals(TapDecision.SCHEDULE_LOCK, recognizer.onTap(501, false))
    }

    @Test
    fun changingUnlockCountResetsPendingRecognition() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        recognizer.updateUnlockTapCount(3)

        assertEquals(TapDecision.NONE, recognizer.onTap(200, true))
        assertEquals(TapDecision.NONE, recognizer.onTap(250, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(275, true))
    }
}
