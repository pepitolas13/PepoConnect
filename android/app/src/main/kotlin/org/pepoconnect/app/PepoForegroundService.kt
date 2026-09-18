package org.pepoconnect.app

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * Keeps PepoConnect connected to the PC while the app is not on screen.
 *
 * Android only lets a process keep running, use the network and hold the Wi-Fi awake
 * behind a foreground service, so while the "background service" setting is on and a PC
 * is paired, Dart starts this one ([PepoNative] `serviceStart`). It:
 *  - shows the persistent notification ("PepoConnect is connected to ..."), which Dart
 *    updates as PCs connect and disconnect;
 *  - holds a partial wake lock, a Wi-Fi lock and a multicast lock (the UDP beacon);
 *  - makes sure the Flutter engine is running ([PepoEngineHolder]). That is what brings
 *    the connection back when Android restarts the service after killing the process
 *    (START_STICKY) or after a reboot / app update ([BootReceiver]), without the app
 *    being opened: Dart starts headless, reconnects and updates the notification.
 *
 * Nothing runs inside the service: the engine lives in the main isolate, and the service
 * is what keeps the process, and with it the engine, alive once the window is gone.
 */
class PepoForegroundService : Service() {

    companion object {
        private const val TAG = "PepoService"
        const val NOTIFICATION_ID = 47473
        const val CHANNEL_ID = "pepoconnect.service"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val PREFS = "pepoconnect.service"
        private const val PREF_WANTED = "wanted"
        private const val PREF_TITLE = "title"
        private const val PREF_IDLE = "idle"
        private const val ACCENT = 0xFF0A3D8F.toInt()

        @Volatile
        private var instance: PepoForegroundService? = null

        /** True while the service is up; the engine then outlives the window. */
        val isRunning: Boolean
            get() = instance != null

        /**
         * Starts the service, or updates its notification when it is already running.
         * [idle] is what the notification says when the service comes back on its own
         * (process killed by the system, reboot), before Dart reports a connection.
         * False when Android refused the start (foreground-service start from the
         * background, Android 12+); the next call from the window succeeds.
         */
        fun start(context: Context, title: String, text: String, idle: String): Boolean {
            prefs(context).edit()
                .putBoolean(PREF_WANTED, true)
                .putString(PREF_TITLE, title)
                .putString(PREF_IDLE, idle)
                .apply()
            val running = instance
            if (running != null) {
                running.show(title, text)
                return true
            }
            val intent = Intent(context, PepoForegroundService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            return try {
                context.startForegroundService(intent)
                true
            } catch (e: Exception) {
                // ForegroundServiceStartNotAllowedException and friends.
                Log.w(TAG, "cannot start the service: ${e.message}")
                false
            }
        }

        /** Changes the notification text. False when the service is not running. */
        fun update(title: String, text: String): Boolean {
            val running = instance ?: return false
            running.show(title, text)
            return true
        }

        /** Stops the service; the engine then goes away with the window. */
        fun stop(context: Context) {
            prefs(context).edit().putBoolean(PREF_WANTED, false).apply()
            // A start still in flight sees `wanted == false` in onStartCommand and stops.
            instance?.shutdown()
        }

        /** Whether Dart last asked for the service (read by [BootReceiver]). */
        fun wanted(context: Context): Boolean = prefs(context).getBoolean(PREF_WANTED, false)

        /**
         * Starts the service on the system's initiative (boot, app update) if Dart wanted
         * it the last time around. The notification shows the idle text until Dart, which
         * the service boots, reports a connection.
         */
        fun startFromSystem(context: Context): Boolean {
            if (!wanted(context)) return false
            val p = prefs(context)
            val title = p.getString(PREF_TITLE, null) ?: context.getString(R.string.app_name)
            val idle = p.getString(PREF_IDLE, null) ?: context.getString(R.string.service_idle)
            return start(context, title, idle, idle)
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var foreground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val p = prefs(this)
        val title = intent?.getStringExtra(EXTRA_TITLE)
            ?: p.getString(PREF_TITLE, null)
            ?: getString(R.string.app_name)
        // No intent: Android restarted us after killing the process (START_STICKY).
        // Nothing is connected yet, so the notification shows the idle text until Dart
        // says otherwise.
        val text = intent?.getStringExtra(EXTRA_TEXT)
            ?: p.getString(PREF_IDLE, null)
            ?: getString(R.string.service_idle)
        // startForegroundService() demands a prompt startForeground(), even when we are
        // about to stop, and before the engine boot, which blocks the main thread briefly.
        if (!show(title, text)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!wanted(this)) {
            // Dart withdrew the request while this start was in flight.
            shutdown()
            return START_NOT_STICKY
        }
        acquireLocks()
        // Dart may not be running (process restarted by the system, reboot): bring the
        // engine back so it reconnects to the PC. It updates the notification itself.
        PepoEngineHolder.get(this)
        return START_STICKY
    }

    // The app's task being swiped away changes nothing: stopWithTask is false in the
    // manifest and the engine keeps running behind this service.

    override fun onDestroy() {
        releaseLocks()
        if (instance === this) instance = null
        super.onDestroy()
    }

    // ---- Notification -------------------------------------------------------------------

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.service_channel),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.service_channel_body)
            setShowBadge(false)
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    /** Posts the notification: through startForeground the first time, then as an update. */
    private fun show(title: String, text: String): Boolean {
        val notification = buildNotification(title, text)
        if (foreground) {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(NOTIFICATION_ID, notification)
            return true
        }
        return try {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
            foreground = true
            true
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException / SecurityException: the
            // Android 12-14 rules on background starts and service types.
            Log.w(TAG, "startForeground failed: ${e.message}")
            false
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_pepoconnect)
            .setColor(ACCENT)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun shutdown() {
        releaseLocks()
        stopForeground(STOP_FOREGROUND_REMOVE)
        foreground = false
        stopSelf()
    }

    // ---- Locks --------------------------------------------------------------------------

    /**
     * Partial wake lock (the CPU answers the PC with the screen off), Wi-Fi lock (the
     * radio stays up) and multicast lock (the discovery beacon is not filtered by the
     * Wi-Fi driver). Held for as long as the service runs.
     */
    @SuppressLint("WakelockTimeout")
    private fun acquireLocks() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wake = wakeLock ?: pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "PepoConnect:service")
            .apply { setReferenceCounted(false) }
            .also { wakeLock = it }
        if (!wake.isHeld) wake.acquire()

        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        @Suppress("DEPRECATION")
        val wifiMode = WifiManager.WIFI_MODE_FULL_HIGH_PERF
        val radio = wifiLock ?: wifi.createWifiLock(wifiMode, "PepoConnect:wifi")
            .apply { setReferenceCounted(false) }
            .also { wifiLock = it }
        if (!radio.isHeld) radio.acquire()

        val multicast = multicastLock ?: wifi.createMulticastLock("PepoConnect:beacon")
            .apply { setReferenceCounted(false) }
            .also { multicastLock = it }
        if (!multicast.isHeld) multicast.acquire()
    }

    private fun releaseLocks() {
        runCatching { wakeLock?.takeIf { it.isHeld }?.release() }
        runCatching { wifiLock?.takeIf { it.isHeld }?.release() }
        runCatching { multicastLock?.takeIf { it.isHeld }?.release() }
        wakeLock = null
        wifiLock = null
        multicastLock = null
    }
}
