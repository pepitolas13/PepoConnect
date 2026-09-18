package org.pepoconnect.app

import android.content.Context
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The one Flutter engine of the app: Dart's main isolate, where the PepoConnect engine
 * (sessions with the PC, transfers, gallery, clipboard) runs.
 *
 * It is created on demand by whoever needs it first, [MainActivity] on a normal launch or
 * [PepoForegroundService] when Android brings the service back without the app being
 * opened, and kept in [FlutterEngineCache] so that it outlives the window: the activity
 * attaches to it and detaches from it, the service keeps the process alive. With the
 * service not running the activity destroys the engine on the way out, as a normal app
 * (see [MainActivity.shouldDestroyEngineWithHost]).
 */
object PepoEngineHolder {
    const val ENGINE_ID = "pepoconnect.main"

    /** The live engine, or null when Dart is not running. */
    val current: FlutterEngine?
        get() = FlutterEngineCache.getInstance().get(ENGINE_ID)

    /**
     * Returns the live engine, starting Dart (`main()`, which runs the app headless until
     * a window attaches) if it was not running. Main thread only.
     */
    fun get(context: Context): FlutterEngine {
        check(Looper.myLooper() == Looper.getMainLooper()) { "PepoEngineHolder.get off the main thread" }
        current?.let { return it }
        // FlutterEngine(context) initialises the loader and registers the pub plugins
        // (GeneratedPluginRegistrant) by itself.
        val engine = FlutterEngine(context.applicationContext)
        engine.plugins.add(PepoNative())
        engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() {}

            override fun onEngineWillDestroy() {
                if (current === engine) FlutterEngineCache.getInstance().remove(ENGINE_ID)
            }
        })
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return engine
    }
}
