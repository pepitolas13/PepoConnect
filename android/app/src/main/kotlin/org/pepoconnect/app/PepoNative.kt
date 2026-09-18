package org.pepoconnect.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Native helpers exposed to Dart on the MethodChannel `org.pepoconnect/native`.
 * Registered from [MainActivity.configureFlutterEngine].
 *
 * Methods (all errors come back as PlatformException):
 *  - `acquireMulticastLock()` -> Boolean. Holds a WifiManager.MulticastLock so mDNS
 *    (bonsoir) traffic is not filtered by the Wi-Fi driver. Idempotent.
 *  - `releaseMulticastLock()` -> null.
 *  - `requestIgnoreBatteryOptimizations()` -> Boolean. Opens the system dialog
 *    (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS); true if already exempt or the
 *    dialog/settings screen was opened.
 *  - `isIgnoringBatteryOptimizations()` -> Boolean.
 *  - `saveToDownloads(path: String, name: String?, mime: String?)` -> String. Copies the
 *    file into MediaStore Downloads/PepoConnect (off the main thread) and returns the
 *    `content://` URI of the copy.
 *  - `openAppSettings()` -> Boolean. Opens this app's details page in Settings.
 *  - `playWav(wav: ByteArray, sampleRate: Int)` -> Boolean. Plays a short 16-bit mono WAV
 *    (canonical 44-byte header) on the notification stream.
 */
class PepoNative : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "org.pepoconnect/native"
        private const val LOCK_TAG = "PepoConnect:mdns"
        private const val DOWNLOADS_SUBDIR = "PepoConnect"
        private const val WAV_HEADER = 44
    }

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activity: Activity? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private val io: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // ---- FlutterPlugin -----------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        releaseMulticastLock()
        io.shutdown()
        appContext = null
    }

    // ---- ActivityAware -----------------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ---- MethodChannel -----------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = appContext
        if (context == null) {
            result.error("no_context", "PepoNative is not attached to a Flutter engine", null)
            return
        }
        try {
            when (call.method) {
                "acquireMulticastLock" -> result.success(acquireMulticastLock(context))
                "releaseMulticastLock" -> {
                    releaseMulticastLock()
                    result.success(null)
                }
                "requestIgnoreBatteryOptimizations" ->
                    result.success(requestIgnoreBatteryOptimizations(context))
                "isIgnoringBatteryOptimizations" ->
                    result.success(isIgnoringBatteryOptimizations(context))
                "saveToDownloads" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("bad_args", "'path' is required", null)
                        return
                    }
                    saveToDownloadsAsync(
                        context,
                        path,
                        call.argument<String>("name"),
                        call.argument<String>("mime"),
                        result,
                    )
                }
                "openAppSettings" -> result.success(openAppSettings(context))
                "playWav" -> {
                    val wav = call.argument<ByteArray>("wav")
                    val sampleRate = call.argument<Int>("sampleRate") ?: 44100
                    if (wav == null || wav.size <= WAV_HEADER) {
                        result.error("bad_args", "'wav' is required", null)
                        return
                    }
                    result.success(playPcm(wav, WAV_HEADER, sampleRate))
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("native_error", e.message ?: e.javaClass.simpleName, e.javaClass.name)
        }
    }

    // ---- Multicast lock ----------------------------------------------------------------

    @Synchronized
    private fun acquireMulticastLock(context: Context): Boolean {
        multicastLock?.let { if (it.isHeld) return true }
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return false
        val lock = wifi.createMulticastLock(LOCK_TAG)
        lock.setReferenceCounted(false)
        lock.acquire()
        multicastLock = lock
        return lock.isHeld
    }

    @Synchronized
    private fun releaseMulticastLock() {
        val lock = multicastLock ?: return
        multicastLock = null
        try {
            if (lock.isHeld) lock.release()
        } catch (e: RuntimeException) {
            // Already released by the system; nothing to do.
        }
    }

    // ---- Battery optimizations ---------------------------------------------------------

    private fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun requestIgnoreBatteryOptimizations(context: Context): Boolean {
        if (isIgnoringBatteryOptimizations(context)) return true
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
        }
        if (startIntent(context, direct)) return true
        // Some OEM builds have no handler for the direct request: fall back to the list screen.
        return startIntent(context, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }

    // ---- App settings ------------------------------------------------------------------

    private fun openAppSettings(context: Context): Boolean {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${context.packageName}"),
        )
        return startIntent(context, intent)
    }

    private fun startIntent(context: Context, intent: Intent): Boolean {
        return try {
            val host = activity
            if (host != null) {
                host.startActivity(intent)
            } else {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    // ---- Sounds ------------------------------------------------------------------------

    /**
     * Plays 16-bit mono PCM (the bytes of [wav] after [offset]) as a notification sound.
     * Static AudioTrack: the whole clip is written up front and released once it is over.
     */
    private fun playPcm(wav: ByteArray, offset: Int, sampleRate: Int): Boolean {
        val size = wav.size - offset
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STATIC)
            .setBufferSizeInBytes(size)
            .build()
        if (track.write(wav, offset, size) < size) {
            track.release()
            return false
        }
        track.play()
        val millis = size * 1000L / (2L * sampleRate) + 300L
        mainHandler.postDelayed({ runCatching { track.stop(); track.release() } }, millis)
        return true
    }

    // ---- Downloads ---------------------------------------------------------------------

    private fun saveToDownloadsAsync(
        context: Context,
        path: String,
        name: String?,
        mime: String?,
        result: MethodChannel.Result,
    ) {
        io.execute {
            val outcome = runCatching { saveToDownloads(context, path, name, mime) }
            // MethodChannel.Result must be completed on the main thread.
            mainHandler.post {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { e ->
                        result.error("save_failed", e.message ?: e.javaClass.simpleName, e.javaClass.name)
                    },
                )
            }
        }
    }

    /** Copies [path] into Downloads/PepoConnect through MediaStore (API 29+). */
    private fun saveToDownloads(context: Context, path: String, name: String?, mime: String?): String {
        val source = File(path)
        if (!source.isFile) throw IOException("File not found: $path")
        val displayName = name?.takeIf { it.isNotBlank() } ?: source.name
        val mimeType = mime?.takeIf { it.isNotBlank() }
            ?: guessMime(displayName)
            ?: "application/octet-stream"

        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS + File.separator + DOWNLOADS_SUBDIR,
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values)
            ?: throw IOException("MediaStore rejected $displayName")
        try {
            val sink = resolver.openOutputStream(uri)
                ?: throw IOException("Cannot open $uri for writing")
            sink.use { out -> source.inputStream().use { it.copyTo(out) } }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        return uri.toString()
    }

    private fun guessMime(fileName: String): String? {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        if (ext.isEmpty()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
    }
}
