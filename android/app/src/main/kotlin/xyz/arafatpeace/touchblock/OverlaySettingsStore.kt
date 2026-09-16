package xyz.arafatpeace.touchblock

import android.content.Context
import android.content.SharedPreferences

internal interface OverlaySettingsPreferences {
    fun readString(key: String, defaultValue: String?): String?

    fun readInt(key: String, defaultValue: Int): Int

    fun save(settings: OverlaySettings): Boolean
}

internal class SettingsPersistenceException : RuntimeException(
    "Could not persist overlay settings",
)

internal class OverlaySettingsStore internal constructor(
    private val preferences: OverlaySettingsPreferences,
) {
    constructor(context: Context) : this(
        SharedPreferencesOverlaySettingsPreferences(
            context.applicationContext.getSharedPreferences(
                PREFERENCES_NAME,
                Context.MODE_PRIVATE,
            ),
        ),
    )

    internal fun read(): OverlaySettings {
        val iconSize = OverlayIconSize.entries.firstOrNull {
            it.wireValue == preferences.readString(
                KEY_ICON_SIZE,
                OverlayIconSize.MEDIUM.wireValue,
            )
        } ?: OverlayIconSize.MEDIUM

        val opacityPercent = preferences.readInt(
            KEY_OPACITY_PERCENT,
            OverlaySettings.DEFAULT.opacityPercent,
        )

        val unlockTapCount = preferences.readInt(
            KEY_UNLOCK_TAP_COUNT,
            OverlaySettings.DEFAULT.unlockTapCount,
        )

        return OverlaySettings(
            iconSize = iconSize,
            opacityPercent = opacityPercent,
            unlockTapCount = unlockTapCount,
        ).normalized()
    }

    internal fun update(values: Map<*, *>): OverlaySettings {
        val next = OverlaySettings.fromMap(values, read())
        if (!preferences.save(next)) {
            throw SettingsPersistenceException()
        }
        return next
    }

    private class SharedPreferencesOverlaySettingsPreferences(
        private val preferences: SharedPreferences,
    ) : OverlaySettingsPreferences {
        override fun readString(key: String, defaultValue: String?): String? =
            preferences.all[key] as? String ?: defaultValue

        override fun readInt(key: String, defaultValue: Int): Int =
            (preferences.all[key] as? Number)?.toInt() ?: defaultValue

        override fun save(settings: OverlaySettings): Boolean =
            preferences.edit()
                .putString(KEY_ICON_SIZE, settings.iconSize.wireValue)
                .putInt(KEY_OPACITY_PERCENT, settings.opacityPercent)
                .putInt(KEY_UNLOCK_TAP_COUNT, settings.unlockTapCount)
                .commit()
    }

    private companion object {
        const val PREFERENCES_NAME = "touch_block_overlay_settings"
        const val KEY_ICON_SIZE = "overlay_icon_size"
        const val KEY_OPACITY_PERCENT = "overlay_opacity_percent"
        const val KEY_UNLOCK_TAP_COUNT = "overlay_unlock_tap_count"
    }
}
