package org.pepoconnect.app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /**
     * The shared engine: started here on a normal launch, or already running behind
     * [PepoForegroundService] (then this window just attaches to it and shows what Dart
     * has been doing meanwhile).
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine = PepoEngineHolder.get(this)

    /** Plugins (and our channel) are registered once, when the engine is created. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {}

    /**
     * With the background service running the engine outlives this window: closing the
     * app (back, swipe from Recents) leaves Dart connected to the PC. Otherwise the engine
     * goes away with the window, as in any app.
     */
    override fun shouldDestroyEngineWithHost(): Boolean = !PepoForegroundService.isRunning
}
