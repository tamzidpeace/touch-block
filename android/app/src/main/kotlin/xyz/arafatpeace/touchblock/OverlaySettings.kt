package xyz.arafatpeace.touchblock

internal enum class OverlayIconSize(
    val wireValue: String,
    val sizeDp: Int,
    val paddingDp: Int,
) {
    SMALL("small", 48, 10),
    MEDIUM("medium", 56, 12),
    LARGE("large", 64, 14),
}

internal data class OverlaySettings(
    val iconSize: OverlayIconSize = OverlayIconSize.MEDIUM,
    val opacityPercent: Int = 95,
    val unlockTapCount: Int = 2,
) {
    fun normalized(): OverlaySettings = copy(
        opacityPercent = opacityPercent.coerceIn(40, 100),
        unlockTapCount = if (unlockTapCount == 3) 3 else 2,
    )

    fun toMap(): Map<String, Any> = mapOf(
        "iconSize" to iconSize.wireValue,
        "opacityPercent" to opacityPercent,
        "unlockTapCount" to unlockTapCount,
    )

    companion object {
        val DEFAULT = OverlaySettings()

        fun fromMap(
            values: Map<*, *>,
            fallback: OverlaySettings = DEFAULT,
        ): OverlaySettings {
            val iconSize = if (values.containsKey("iconSize")) {
                OverlayIconSize.entries.firstOrNull {
                    it.wireValue == values["iconSize"]
                } ?: OverlayIconSize.MEDIUM
            } else {
                fallback.iconSize
            }

            val opacity = if (values.containsKey("opacityPercent")) {
                (values["opacityPercent"] as? Number)?.toInt()
                    ?: fallback.opacityPercent
            } else {
                fallback.opacityPercent
            }

            val taps = if (values.containsKey("unlockTapCount")) {
                (values["unlockTapCount"] as? Number)?.toInt()
                    ?.takeIf { it == 2 || it == 3 } ?: 2
            } else {
                fallback.unlockTapCount
            }

            return OverlaySettings(iconSize, opacity, taps).normalized()
        }
    }
}
