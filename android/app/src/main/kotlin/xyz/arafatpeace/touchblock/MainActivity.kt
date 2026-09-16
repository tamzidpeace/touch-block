package xyz.arafatpeace.touchblock

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity - Entry point for the Flutter app
 * 
 * This activity handles:
 * 1. MethodChannel communication between Flutter and Android
 * 2. Overlay permission requests
 * 3. Service start/stop commands
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val CHANNEL = "xyz.arafatpeace.touchblock/overlay"
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 1001
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002
    }
    
    private var pendingResult: MethodChannel.Result? = null
    private lateinit var settingsStore: OverlaySettingsStore
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        settingsStore = OverlaySettingsStore(applicationContext)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    if (checkOverlayPermission()) {
                        ensureNotificationPermission()
                        startFloatingService()
                        result.success(true)
                    } else {
                        result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                    }
                }
                "stopService" -> {
                    stopFloatingService()
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    result.success(checkOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    pendingResult = result
                    requestOverlayPermission()
                }
                "isServiceRunning" -> {
                    result.success(FloatingOverlayService.isRunning)
                }
                "getOverlaySettings" -> {
                    result.success(settingsStore.read().toMap())
                }
                "updateOverlaySettings" -> {
                    updateOverlaySettings(call, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * Check if the app has permission to draw overlays
     */
    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true // Pre-Marshmallow doesn't require this permission
        }
    }
    
    /**
     * Ask for notification permission on Android 13+ so the foreground
     * service notification is visible.
     *
     * Deliberately fire-and-forget: a denial hides the notification but does
     * not stop a foreground service from running, so the service must start
     * either way. Blocking the app's primary function on a secondary
     * permission would be the wrong trade.
     */
    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED

        if (!granted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    /**
     * Open system settings to request overlay permission
     * User must manually toggle the permission
     */
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
        } else {
            pendingResult?.success(true)
            pendingResult = null
        }
    }
    
    /**
     * Handle result from overlay permission settings screen
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            val granted = checkOverlayPermission()
            pendingResult?.success(granted)
            pendingResult = null
        }
    }
    
    /**
     * Start the floating overlay service
     */
    private fun startFloatingService() {
        val intent = Intent(this, FloatingOverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
    
    /**
     * Stop the floating overlay service
     */
    private fun stopFloatingService() {
        val intent = Intent(this, FloatingOverlayService::class.java)
        stopService(intent)
    }

    private fun updateOverlaySettings(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            val normalized = settingsStore.update(arguments)
            val running = FloatingOverlayService.isRunning
            val liveApplied = if (running) {
                FloatingOverlayService.applySettings(normalized)
            } else {
                false
            }

            result.success(
                mapOf(
                    "settings" to normalized.toMap(),
                    "serviceRunning" to running,
                    "liveApplied" to liveApplied,
                ),
            )
        } catch (_: SettingsPersistenceException) {
            result.error(
                "SETTINGS_PERSIST_FAILED",
                "Could not persist overlay settings",
                null,
            )
        }
    }
}
