package org.pepoconnect.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Brings [PepoForegroundService] (and with it the engine) back after a reboot or an app
 * update, when Dart had it running the last time. Both broadcasts are protected: only
 * the system sends them.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> PepoForegroundService.startFromSystem(context)
        }
    }
}
