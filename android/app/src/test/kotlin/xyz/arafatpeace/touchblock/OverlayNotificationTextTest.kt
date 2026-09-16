package xyz.arafatpeace.touchblock

import org.junit.Assert.assertEquals
import org.junit.Test

class OverlayNotificationTextTest {
    @Test
    fun doubleTapInstructionIsStable() {
        assertEquals(
            "Double-tap the icon to unlock",
            OverlayNotificationText.unlockInstruction(2),
        )
    }

    @Test
    fun tripleTapInstructionIsStable() {
        assertEquals(
            "Triple-tap the icon to unlock",
            OverlayNotificationText.unlockInstruction(3),
        )
    }

    @Test
    fun invalidTapCountUsesDoubleTapCopy() {
        assertEquals(
            "Double-tap the icon to unlock",
            OverlayNotificationText.unlockInstruction(9),
        )
    }
}
