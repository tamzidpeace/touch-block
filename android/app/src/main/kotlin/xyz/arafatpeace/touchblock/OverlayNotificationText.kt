package xyz.arafatpeace.touchblock

internal object OverlayNotificationText {
    fun unlockInstruction(unlockTapCount: Int): String =
        if (unlockTapCount == 3) {
            "Triple-tap the icon to unlock"
        } else {
            "Double-tap the icon to unlock"
        }
}
