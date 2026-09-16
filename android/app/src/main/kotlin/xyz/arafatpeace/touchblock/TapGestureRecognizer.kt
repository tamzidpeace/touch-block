package xyz.arafatpeace.touchblock

internal enum class TapDecision {
    NONE,
    SCHEDULE_LOCK,
    CANCEL_PENDING_LOCK,
    LOCK,
    UNLOCK,
}

internal class TapGestureRecognizer(
    unlockTapCount: Int,
    private val tapWindowMs: Long = 300L,
) {
    private var requiredUnlockTaps = normalizeUnlockTapCount(unlockTapCount)
    private var pendingLockAt: Long? = null
    private var lockedTapCount = 0
    private var lastLockedTapAt: Long? = null
    private var consumeUntilMs: Long? = null

    fun onTap(timestampMs: Long, isBlocking: Boolean): TapDecision {
        if (!isBlocking) {
            val ignoredUntil = consumeUntilMs
            if (ignoredUntil != null && timestampMs < ignoredUntil) {
                return TapDecision.NONE
            }
            consumeUntilMs = null

            val firstTapAt = pendingLockAt
            if (firstTapAt == null || timestampMs - firstTapAt >= tapWindowMs) {
                pendingLockAt = timestampMs
                return TapDecision.SCHEDULE_LOCK
            }

            pendingLockAt = null
            consumeUntilMs = firstTapAt + tapWindowMs
            return TapDecision.CANCEL_PENDING_LOCK
        }

        pendingLockAt = null
        val lastTapAt = lastLockedTapAt
        lockedTapCount = if (
            lastTapAt == null || timestampMs - lastTapAt >= tapWindowMs
        ) {
            1
        } else {
            lockedTapCount + 1
        }
        lastLockedTapAt = timestampMs

        if (lockedTapCount < requiredUnlockTaps) {
            return TapDecision.NONE
        }

        lockedTapCount = 0
        lastLockedTapAt = null
        consumeUntilMs = timestampMs + tapWindowMs
        return TapDecision.UNLOCK
    }

    fun onLockTimeout(timestampMs: Long): TapDecision {
        val firstTapAt = pendingLockAt ?: return TapDecision.NONE
        if (timestampMs - firstTapAt < tapWindowMs) {
            return TapDecision.NONE
        }

        pendingLockAt = null
        return TapDecision.LOCK
    }

    fun updateUnlockTapCount(tapCount: Int) {
        requiredUnlockTaps = normalizeUnlockTapCount(tapCount)
        reset()
    }

    fun reset() {
        pendingLockAt = null
        lockedTapCount = 0
        lastLockedTapAt = null
        consumeUntilMs = null
    }

    private fun normalizeUnlockTapCount(tapCount: Int): Int =
        if (tapCount == 3) 3 else 2
}
