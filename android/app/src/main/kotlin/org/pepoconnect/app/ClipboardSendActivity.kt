package org.pepoconnect.app

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Toast

/**
 * Invisible window that reads the clipboard and sends it to the PCs.
 *
 * Android 10+ only lets an app read the clipboard while one of its windows has focus,
 * so the quick-settings tile ([ClipboardTileService]) and the launcher shortcut come
 * through here: the window appears (translucent, no animation), reads the primary clip
 * once it has focus, hands the text to Dart through [PepoNative.deliverClipboard] and
 * finishes. When the Flutter engine is not around (app not started, or Dart not ready
 * yet) the text goes to [MainActivity] as a share, which queues it until a PC connects.
 *
 * Android 12+ shows its own "PepoConnect pasted from your clipboard" notice on the
 * first read of each clip; that is the system's and cannot be avoided.
 */
class ClipboardSendActivity : Activity() {

    companion object {
        private const val WATCHDOG_MS = 3000L
        private const val READ_ATTEMPTS = 3
        private const val RETRY_GAP_MS = 150L

        /** Same cap as the Dart side (`ClipboardSync.maxLength`). */
        private const val MAX_LENGTH = 64 * 1024
    }

    private val handler = Handler(Looper.getMainLooper())
    private var done = false
    private var attempts = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // If focus never arrives (odd ROMs) do not linger as an invisible window.
        handler.postDelayed({ if (!done) finishQuietly() }, WATCHDOG_MS)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && !done) readClipboard()
    }

    private fun readClipboard() {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val item = clipboard.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)
        val text = (item?.text ?: item?.coerceToText(this))?.toString()
        if (text.isNullOrBlank()) {
            // Empty, or access not granted yet: some OEM builds allow the read a few
            // frames after the focus callback. Retry briefly, then give up.
            if (++attempts < READ_ATTEMPTS) {
                handler.postDelayed({ if (!done) readClipboard() }, RETRY_GAP_MS)
                return
            }
            toast(getString(R.string.clipboard_empty))
            finishQuietly()
            return
        }
        done = true
        if (text.length > MAX_LENGTH) {
            toast(getString(R.string.clipboard_too_long))
            finish()
            return
        }
        val native = PepoNative.current
        if (native == null || !native.dartReady) {
            openApp(text)
            return
        }
        native.deliverClipboard(text) { sent ->
            when {
                sent == null -> openApp(text)
                sent.isEmpty() -> {
                    toast(getString(R.string.clipboard_no_pc))
                    finish()
                }
                else -> {
                    toast(getString(R.string.clipboard_sent, sent.joinToString(", ")))
                    finish()
                }
            }
        }
    }

    /** No live engine: hand the text to the app as a share (queued until a PC connects). */
    private fun openApp(text: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_SEND
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        toast(getString(R.string.clipboard_opening))
        startActivity(intent)
        finish()
    }

    private fun finishQuietly() {
        done = true
        finish()
    }

    private fun toast(message: String) {
        Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
    }
}
