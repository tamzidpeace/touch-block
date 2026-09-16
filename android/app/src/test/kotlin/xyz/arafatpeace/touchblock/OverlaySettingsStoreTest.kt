package xyz.arafatpeace.touchblock

import org.junit.Assert.assertEquals
import org.junit.Test

class OverlaySettingsStoreTest {
    @Test
    fun emptyPreferencesReturnSafeDefaults() {
        val store = OverlaySettingsStore(FakeOverlaySettingsPreferences())

        assertEquals(OverlaySettings.DEFAULT, store.read())
    }

    @Test
    fun updateMergesMissingFieldsAndClampsOpacity() {
        val preferences = FakeOverlaySettingsPreferences(
            OverlaySettings(
                iconSize = OverlayIconSize.SMALL,
                opacityPercent = 70,
                unlockTapCount = 3,
            ),
        )
        val store = OverlaySettingsStore(preferences)

        val result = store.update(mapOf("opacityPercent" to 1000))

        assertEquals(OverlayIconSize.SMALL, result.iconSize)
        assertEquals(100, result.opacityPercent)
        assertEquals(3, result.unlockTapCount)
        assertEquals(result, store.read())
    }

    @Test
    fun invalidEnumAndTapValuesUseMediumAndDoubleTap() {
        val store = OverlaySettingsStore(FakeOverlaySettingsPreferences())

        val result = store.update(
            mapOf(
                "iconSize" to "not-a-size",
                "opacityPercent" to 40,
                "unlockTapCount" to 9,
            ),
        )

        assertEquals(OverlayIconSize.MEDIUM, result.iconSize)
        assertEquals(40, result.opacityPercent)
        assertEquals(2, result.unlockTapCount)
    }

    @Test(expected = SettingsPersistenceException::class)
    fun failedCommitIsReported() {
        val store = OverlaySettingsStore(
            FakeOverlaySettingsPreferences(commitResult = false),
        )

        store.update(mapOf("opacityPercent" to 80))
    }
}

private class FakeOverlaySettingsPreferences(
    initial: OverlaySettings = OverlaySettings.DEFAULT,
    private val commitResult: Boolean = true,
) : OverlaySettingsPreferences {
    private var value = initial

    override fun readString(key: String, defaultValue: String?): String? =
        when (key) {
            "overlay_icon_size" -> value.iconSize.wireValue
            else -> defaultValue
        }

    override fun readInt(key: String, defaultValue: Int): Int =
        when (key) {
            "overlay_opacity_percent" -> value.opacityPercent
            "overlay_unlock_tap_count" -> value.unlockTapCount
            else -> defaultValue
        }

    override fun save(settings: OverlaySettings): Boolean {
        if (commitResult) value = settings
        return commitResult
    }
}
