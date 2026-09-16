package xyz.arafatpeace.touchblock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat
import kotlin.math.roundToInt

/**
 * FloatingOverlayService - Foreground service that manages the floating overlay
 * 
 * This service creates and manages:
 * 1. A draggable floating icon that stays above all apps
 * 2. A full-screen touch-blocking overlay (activated on single-tap)
 * 
 * Interaction:
 * - Single tap on floating icon: Toggle touch blocking ON
 * - Double tap on floating icon: Toggle touch blocking OFF
 * - Drag: Move the floating icon around the screen
 */
class FloatingOverlayService : Service() {
    
    companion object {
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "touch_block_channel"
        
        // Tap recognition window (milliseconds)
        private const val TAP_WINDOW_MS = 300L
        
        // Drag threshold (pixels) - movement beyond this is considered a drag, not a tap
        private const val DRAG_THRESHOLD = 10
        
        // Track if service is running (accessible from MainActivity)
        var isRunning = false
            private set

        private var instance: FloatingOverlayService? = null

        internal fun applySettings(settings: OverlaySettings): Boolean {
            return instance?.applySettingsOnMain(settings) ?: false
        }
    }
    
    private lateinit var windowManager: WindowManager
    private lateinit var floatingView: ImageView
    private var blockingView: View? = null

    private var isBlocking = false
    private lateinit var settings: OverlaySettings
    private lateinit var gestureRecognizer: TapGestureRecognizer
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingLockRunnable: Runnable? = null
    
    // For drag gesture handling
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var hasMoved = false
    
    private lateinit var floatingParams: WindowManager.LayoutParams
    
    override fun onCreate() {
        super.onCreate()
        isRunning = true
        instance = this
        settings = OverlaySettingsStore(applicationContext).read()
        gestureRecognizer = TapGestureRecognizer(settings.unlockTapCount, TAP_WINDOW_MS)
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        createFloatingIcon()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }
    
    override fun onDestroy() {
        cancelPendingLock()
        if (::gestureRecognizer.isInitialized) {
            gestureRecognizer.reset()
        }
        instance = null
        super.onDestroy()
        isRunning = false
        removeFloatingIcon()
        removeBlockingOverlay()
    }
    
    /**
     * Create the notification channel for Android 8.0+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Touch Block Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when touch blocking is available"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    /**
     * Create the foreground service notification
     */
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Touch Block Active")
            .setContentText(
                if (isBlocking) {
                    "Screen is locked - ${OverlayNotificationText.unlockInstruction(settings.unlockTapCount)}"
                } else {
                    "Tap floating icon to lock screen"
                },
            )
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
    
    /**
     * Update the notification text based on blocking state
     */
    private fun updateNotification() {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, createNotification())
    }
    
    /**
     * Create the floating icon overlay
     */
    private fun createFloatingIcon() {
        val sizePx = dpToPixels(settings.iconSize.sizeDp)
        val paddingPx = dpToPixels(settings.iconSize.paddingDp)

        floatingView = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            
            // Create a circular white background programmatically
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
                setStroke(4, Color.parseColor("#6750A4")) // Purple border
            }
            
            // Make it visually appealing
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
            alpha = settings.opacityPercent / 100f
            elevation = 8f
        }
        
        // Window parameters for overlay type
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        
        floatingParams = WindowManager.LayoutParams(
            sizePx, // width
            sizePx, // height
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 100
            y = 300
        }
        
        // Set up touch handling for drag and tap detection
        floatingView.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = floatingParams.x
                    initialY = floatingParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    hasMoved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = (event.rawX - initialTouchX).toInt()
                    val deltaY = (event.rawY - initialTouchY).toInt()
                    
                    // Check if movement exceeds drag threshold
                    if (kotlin.math.abs(deltaX) > DRAG_THRESHOLD || 
                        kotlin.math.abs(deltaY) > DRAG_THRESHOLD) {
                        if (!hasMoved) {
                            gestureRecognizer.reset()
                            cancelPendingLock()
                        }
                        hasMoved = true
                    }
                    
                    // Update position
                    floatingParams.x = initialX + deltaX
                    floatingParams.y = initialY + deltaY
                    windowManager.updateViewLayout(floatingView, floatingParams)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!hasMoved) {
                        handleTap()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    gestureRecognizer.reset()
                    cancelPendingLock()
                    true
                }
                else -> false
            }
        }
        
        windowManager.addView(floatingView, floatingParams)
        updateFloatingIconState()
    }
    
    /** Handle tap decisions from the configured gesture recognizer. */
    private fun handleTap() {
        when (
            gestureRecognizer.onTap(
                timestampMs = System.currentTimeMillis(),
                isBlocking = isBlocking,
            )
        ) {
            TapDecision.SCHEDULE_LOCK -> scheduleLockConfirmation()
            TapDecision.CANCEL_PENDING_LOCK -> cancelPendingLock()
            TapDecision.LOCK -> setBlocking(true)
            TapDecision.UNLOCK -> setBlocking(false)
            TapDecision.NONE -> Unit
        }
    }

    private fun scheduleLockConfirmation() {
        cancelPendingLock()
        val runnable = Runnable {
            pendingLockRunnable = null
            if (
                gestureRecognizer.onLockTimeout(System.currentTimeMillis()) ==
                TapDecision.LOCK &&
                !isBlocking
            ) {
                setBlocking(true)
            }
        }
        pendingLockRunnable = runnable
        mainHandler.postDelayed(runnable, TAP_WINDOW_MS)
    }

    private fun cancelPendingLock() {
        pendingLockRunnable?.let(mainHandler::removeCallbacks)
        pendingLockRunnable = null
    }

    private fun setBlocking(shouldBlock: Boolean) {
        if (isBlocking == shouldBlock) return

        isBlocking = shouldBlock
        vibrateShort()
        
        if (isBlocking) {
            createBlockingOverlay()
        } else {
            removeBlockingOverlay()
        }
        
        updateFloatingIconState()
        updateNotification()
    }

    private fun applySettingsOnMain(next: OverlaySettings): Boolean {
        if (
            !::floatingView.isInitialized ||
            !::floatingParams.isInitialized ||
            !::gestureRecognizer.isInitialized
        ) {
            return false
        }

        return try {
            val normalized = next.normalized()
            floatingParams.width = dpToPixels(normalized.iconSize.sizeDp)
            floatingParams.height = dpToPixels(normalized.iconSize.sizeDp)
            val paddingPx = dpToPixels(normalized.iconSize.paddingDp)
            floatingView.setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
            floatingView.alpha = normalized.opacityPercent / 100f
            windowManager.updateViewLayout(floatingView, floatingParams)

            settings = normalized
            gestureRecognizer.updateUnlockTapCount(normalized.unlockTapCount)
            cancelPendingLock()
            updateNotification()
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun dpToPixels(valueDp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            valueDp.toFloat(),
            resources.displayMetrics,
        ).roundToInt()
    }
    
    /**
     * Create the full-screen blocking overlay
     * This intercepts all touch events except for the floating icon
     */
    private fun createBlockingOverlay() {
        if (blockingView != null) return
        
        blockingView = View(this).apply {
            // Semi-transparent to indicate blocking
            setBackgroundColor(0x33000000) // 20% black overlay
        }
        
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutFlag,
            // This flag combination makes the overlay intercept ALL touches
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        
        // Add blocking view below the floating icon
        windowManager.addView(blockingView, params)
        
        // Re-add floating view to bring it to front
        windowManager.removeView(floatingView)
        windowManager.addView(floatingView, floatingParams)
    }
    
    /**
     * Remove the blocking overlay
     */
    private fun removeBlockingOverlay() {
        blockingView?.let {
            try {
                windowManager.removeView(it)
            } catch (e: Exception) {
                // View might already be removed
            }
            blockingView = null
        }
    }
    
    /**
     * Update the floating icon appearance based on blocking state
     */
    private fun updateFloatingIconState() {
        if (isBlocking) {
            floatingView.setImageResource(android.R.drawable.ic_lock_lock)
            // Red circular background when locked
            floatingView.background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E53935"))
                setStroke(4, Color.parseColor("#B71C1C"))
            }
        } else {
            floatingView.setImageResource(android.R.drawable.ic_lock_lock)
            // White circular background when unlocked
            floatingView.background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
                setStroke(4, Color.parseColor("#6750A4"))
            }
        }
    }
    
    /**
     * Remove the floating icon from screen
     */
    private fun removeFloatingIcon() {
        try {
            windowManager.removeView(floatingView)
        } catch (e: Exception) {
            // View might already be removed
        }
    }
    
    /**
     * Provide haptic feedback
     */
    private fun vibrateShort() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(50)
        }
    }
}
