package org.pepoconnect.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Registers GeneratedPluginRegistrant (all pub plugins).
        super.configureFlutterEngine(flutterEngine)
        // Our own MethodChannel bridge (org.pepoconnect/native).
        flutterEngine.plugins.add(PepoNative())
    }
}
