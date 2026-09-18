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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PepoNative") {
      native = PepoNativeChannel(messenger: registrar.messenger())
    }
  }
}

/// The `org.pepoconnect/native` channel on iOS. Only `playWav` exists here:
/// it plays a short 16-bit mono WAV (the transfer chime). Everything else
/// answers "not implemented", which the Dart side treats as a no-op.
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
      default:
        result(FlutterMethodNotImplemented)
      }
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
  }
}
