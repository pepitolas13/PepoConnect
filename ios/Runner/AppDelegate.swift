import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var native: PepoNativeChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS refuses identifiers registered after launch finishes, so this has
    // to happen before anything else asks for time.
    PepoTasks.shared.register()
    PepoTasks.shared.schedule()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PepoNative") {
      native = PepoNativeChannel(messenger: registrar.messenger())
    }
  }
}

/// The `org.pepoconnect/native` channel on iOS: the transfer chime and the
/// background engine ([KeepAlive], [BackgroundHold], [PepoTasks]).
/// Everything else answers "not implemented", which the Dart side treats as
/// a no-op.
final class PepoNativeChannel: NSObject, AVAudioPlayerDelegate {
  private let channel: FlutterMethodChannel
  private var players: [AVAudioPlayer] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "org.pepoconnect/native", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "playWav":
        guard let args = call.arguments as? [String: Any],
          let wav = args["wav"] as? FlutterStandardTypedData
        else {
          result(FlutterError(code: "bad_args", message: "'wav' is required", details: nil))
          return
        }
        result(self.play(wav.data))
      case "keepAliveStart":
        result(KeepAlive.shared.start())
      case "keepAliveStop":
        KeepAlive.shared.stop()
        result(nil)
      case "backgroundHold":
        let on = (call.arguments as? [String: Any])?["on"] as? Bool ?? false
        BackgroundHold.shared.set(on)
        result(BackgroundHold.shared.isHeld)
      case "backgroundStatus":
        result(self.status())
      case "backgroundReady":
        // Native → Dart calls made before the Dart handler exists sit in the
        // channel buffer unanswered, so nothing is pushed until this arrives.
        self.listenForTasks()
        result(nil)
      case "openAppSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      case "backgroundTaskDone":
        let args = call.arguments as? [String: Any]
        let identifier = args?["id"] as? String ?? ""
        let ok = args?["ok"] as? Bool ?? true
        PepoTasks.shared.complete(identifier, success: ok)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func listenForTasks() {
    PepoTasks.shared.onTask = { [weak self] identifier in
      self?.channel.invokeMethod("backgroundTask", arguments: ["id": identifier])
    }
    PepoTasks.shared.flush()
  }

  private func status() -> [String: Any] {
    let engine = KeepAlive.shared
    var out: [String: Any] = [
      "running": engine.running,
      "playing": engine.isPlaying,
      "held": BackgroundHold.shared.isHeld,
      "refresh": PepoNativeChannel.refreshState(),
    ]
    if let started = engine.startedAt {
      out["startedAt"] = Int(started.timeIntervalSince1970 * 1000)
    }
    return out
  }

  private static func refreshState() -> String {
    switch UIApplication.shared.backgroundRefreshStatus {
    case .available: return "available"
    case .denied: return "denied"
    case .restricted: return "restricted"
    @unknown default: return "unknown"
    }
  }

  private func play(_ data: Data) -> Bool {
    do {
      let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
      player.delegate = self
      player.prepareToPlay()
      players.append(player)
      return player.play()
    } catch {
      return false
    }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    players.removeAll { $0 === player }
    // Never deactivate the session here: the chime shares it with the
    // keep-alive loop, and tearing it down would suspend the app.
  }
}
