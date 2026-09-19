import AVFoundation
import BackgroundTasks
import UIKit

/// Keeps the process alive while PepoConnect is not on screen.
///
/// iOS has no API that wakes a suspended app when a photo is taken:
/// `PHPhotoLibraryChangeObserver` only delivers to a running process, and the
/// `BGTaskScheduler` tasks run when the system feels like it — minutes or
/// hours later. The only way for a new photo to leave the phone on its own is
/// for the process never to be suspended, and the `audio` background mode is
/// the one way to get there without asking for a permission a transfer app has
/// no business asking for.
///
/// So this plays one second of silence on a loop. The samples are zeroes, the
/// session mixes with whatever else is playing and we never publish
/// now-playing info, so nothing is audible, other apps keep their audio and no
/// indicator appears. What it buys is a process iOS does not suspend, which is
/// all the Dart engine needs: the photo library observer, the TLS control
/// socket and the transfers keep running exactly as they do in the foreground.
final class KeepAlive: NSObject {
  static let shared = KeepAlive()

  /// The watchdog beat. Short enough to recover from an interruption before
  /// anyone notices, long enough to cost nothing.
  private static let watchdogInterval: TimeInterval = 30

  private var player: AVAudioPlayer?
  private var watchdog: Timer?
  private var observing = false

  /// Whether the engine is meant to be running. The watchdog only revives the
  /// player while this is true.
  private(set) var running = false

  /// When the loop started. It resets with the process, so "running for 47
  /// minutes" is proof from the phone itself that iOS never suspended it —
  /// no cable, no Xcode.
  private(set) var startedAt: Date?

  var isPlaying: Bool { player?.isPlaying ?? false }

  @discardableResult
  func start() -> Bool {
    observe()
    if running { return resume() }
    running = true
    let ok = resume()
    if ok { startedAt = Date() }
    startWatchdog()
    return ok
  }

  func stop() {
    running = false
    watchdog?.invalidate()
    watchdog = nil
    player?.stop()
    player = nil
    startedAt = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
  }

  /// Brings the session and the player back up. Safe to call at any time:
  /// everything here is idempotent, which is what lets the watchdog and the
  /// notifications all funnel into the same path.
  @discardableResult
  private func resume() -> Bool {
    guard running else { return false }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      NSLog("PepoConnect: audio session failed: \(error.localizedDescription)")
      return false
    }
    if player == nil {
      do {
        let made = try AVAudioPlayer(
          data: KeepAlive.silence, fileTypeHint: AVFileType.wav.rawValue)
        made.numberOfLoops = -1
        made.volume = 0.01
        made.prepareToPlay()
        player = made
      } catch {
        NSLog("PepoConnect: silent player failed: \(error.localizedDescription)")
        return false
      }
    }
    guard let player = player else { return false }
    return player.isPlaying || player.play()
  }

  // ---------------------------------------------------------------------------
  // Recovery

  private func startWatchdog() {
    watchdog?.invalidate()
    let timer = Timer(timeInterval: KeepAlive.watchdogInterval, repeats: true) { [weak self] _ in
      guard let self = self, self.running, !self.isPlaying else { return }
      if self.resume() && self.startedAt == nil { self.startedAt = Date() }
    }
    // Common modes: the beat must survive whatever the run loop is doing.
    RunLoop.main.add(timer, forMode: .common)
    watchdog = timer
  }

  private func observe() {
    guard !observing else { return }
    observing = true
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(onInterruption(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
    center.addObserver(
      self, selector: #selector(onMediaReset(_:)),
      name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    center.addObserver(
      self, selector: #selector(onRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification, object: nil)
    center.addObserver(
      self, selector: #selector(onEnterBackground(_:)),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    center.addObserver(
      self, selector: #selector(onEnterForeground(_:)),
      name: UIApplication.willEnterForegroundNotification, object: nil)
    // Flutter runs on the scene lifecycle now; both sets fire today, and
    // everything they call is idempotent, so listen to both rather than bet
    // on which one keeps firing.
    center.addObserver(
      self, selector: #selector(onEnterBackground(_:)),
      name: UIScene.didEnterBackgroundNotification, object: nil)
    center.addObserver(
      self, selector: #selector(onEnterForeground(_:)),
      name: UIScene.willEnterForegroundNotification, object: nil)
  }

  /// A phone call or another app taking the session over. `.ended` is the
  /// normal way back; when it never arrives the watchdog picks it up.
  @objc private func onInterruption(_ note: Notification) {
    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw)
    else { return }
    if type == .ended { resume() }
  }

  /// The media server died and took the session and the player with it.
  @objc private func onMediaReset(_ note: Notification) {
    player = nil
    resume()
  }

  @objc private func onRouteChange(_ note: Notification) {
    resume()
  }

  @objc private func onEnterBackground(_ note: Notification) {
    resume()
    PepoTasks.shared.schedule()
  }

  @objc private func onEnterForeground(_ note: Notification) {
    resume()
  }

  // ---------------------------------------------------------------------------

  /// One second of 16-bit mono PCM silence in a RIFF container, built in code
  /// so there is no asset to lose when the IPA is re-signed for sideloading.
  private static let silence: Data = KeepAlive.makeSilence(seconds: 1, sampleRate: 44100)

  private static func makeSilence(seconds: Int, sampleRate: Int) -> Data {
    let channels = 1
    let bitsPerSample = 16
    let blockAlign = channels * bitsPerSample / 8
    let byteRate = sampleRate * blockAlign
    let dataSize = byteRate * seconds
    var out = Data(capacity: 44 + dataSize)
    func ascii(_ text: String) { out.append(contentsOf: Array(text.utf8)) }
    // Little endian by hand: no unsafe pointers to get wrong in a file that
    // only ever gets compiled on CI.
    func u32(_ value: Int) {
      let v = UInt32(value)
      out.append(contentsOf: [
        UInt8(v & 0xFF),
        UInt8((v >> 8) & 0xFF),
        UInt8((v >> 16) & 0xFF),
        UInt8((v >> 24) & 0xFF),
      ])
    }
    func u16(_ value: Int) {
      let v = UInt16(value)
      out.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)])
    }
    ascii("RIFF")
    u32(36 + dataSize)
    ascii("WAVE")
    ascii("fmt ")
    u32(16)
    u16(1)  // PCM
    u16(channels)
    u32(sampleRate)
    u32(byteRate)
    u16(blockAlign)
    u16(bitsPerSample)
    ascii("data")
    u32(dataSize)
    out.append(Data(count: dataSize))
    return out
  }
}

/// A background-task assertion around work that must not be cut short.
///
/// [KeepAlive] makes this mostly redundant, but a transfer that starts just as
/// the app leaves the screen still deserves the ~30 s iOS grants on request —
/// and when the engine is off, or has just been interrupted, this is the only
/// thing holding the process up.
final class BackgroundHold {
  static let shared = BackgroundHold()

  private var token: UIBackgroundTaskIdentifier = .invalid

  var isHeld: Bool { token != .invalid }

  func set(_ on: Bool) {
    if on {
      begin()
    } else {
      end()
    }
  }

  private func begin() {
    guard token == .invalid else { return }
    token = UIApplication.shared.beginBackgroundTask(withName: "pepoconnect.transfer") {
      [weak self] in
      self?.end()
    }
  }

  private func end() {
    guard token != .invalid else { return }
    UIApplication.shared.endBackgroundTask(token)
    token = .invalid
  }
}

/// The opportunistic tier: `BGAppRefreshTask` and `BGProcessingTask`.
///
/// These are the safety net for when [KeepAlive] is not running — the app was
/// closed from the app switcher, the phone rebooted, iOS reclaimed the
/// process. The system decides when they run, which in practice means minutes
/// to hours, so nothing about "take a photo and it arrives" rests on them:
/// they exist so a backlog eventually drains on its own.
///
/// When iOS launches the app straight into the background for one of these,
/// the scene may never connect and the Flutter engine never starts. Then
/// nobody answers and [answerTimeout] hands the task back rather than leaving
/// it hanging until the system kills it.
final class PepoTasks {
  static let shared = PepoTasks()

  static let refreshIdentifier = "org.pepoconnect.app.refresh"
  static let syncIdentifier = "org.pepoconnect.app.sync"

  /// How long a task waits for Dart before we give it back.
  private static let answerTimeout: TimeInterval = 25

  /// Earliest the system may run the next one.
  private static let earliest: TimeInterval = 15 * 60

  /// Set by the channel once Dart is listening.
  var onTask: ((String) -> Void)?

  private var active: [String: BGTask] = [:]
  private var timeouts: [String: Timer] = [:]
  private var undelivered: [String] = []
  private var registered = false

  /// Must run before `didFinishLaunchingWithOptions` returns.
  func register() {
    guard !registered else { return }
    registered = true
    for identifier in [PepoTasks.refreshIdentifier, PepoTasks.syncIdentifier] {
      let ok = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) {
        [weak self] task in
        self?.run(task)
      }
      if !ok {
        // Refused identifiers fail silently later on submit, so say it once here.
        NSLog("PepoConnect: cannot register background task \(identifier)")
      }
    }
  }

  func schedule() {
    guard registered else { return }
    let refresh = BGAppRefreshTaskRequest(identifier: PepoTasks.refreshIdentifier)
    refresh.earliestBeginDate = Date(timeIntervalSinceNow: PepoTasks.earliest)
    let sync = BGProcessingTaskRequest(identifier: PepoTasks.syncIdentifier)
    sync.requiresNetworkConnectivity = true
    sync.requiresExternalPower = false
    sync.earliestBeginDate = Date(timeIntervalSinceNow: PepoTasks.earliest)
    for request in [refresh, sync] as [BGTaskRequest] {
      do {
        // Submitting over a pending request for the same identifier is an
        // error on some releases; dropping it first never is.
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: request.identifier)
        try BGTaskScheduler.shared.submit(request)
      } catch {
        NSLog(
          "PepoConnect: cannot schedule \(request.identifier): \(error.localizedDescription)")
      }
    }
  }

  /// Anything that arrived before Dart was listening.
  func flush() {
    let pending = undelivered
    undelivered.removeAll()
    for identifier in pending { deliver(identifier) }
  }

  func complete(_ identifier: String, success: Bool) {
    timeouts.removeValue(forKey: identifier)?.invalidate()
    // A task handed back on the timeout must not be handed to Dart later.
    undelivered.removeAll { $0 == identifier }
    guard let task = active.removeValue(forKey: identifier) else { return }
    task.setTaskCompleted(success: success)
  }

  private func run(_ task: BGTask) {
    let identifier = task.identifier
    // Ask for the next one first: a task that ends without rescheduling is
    // the last one the app ever gets.
    schedule()
    active[identifier] = task
    task.expirationHandler = { [weak self] in
      self?.complete(identifier, success: false)
    }
    let timer = Timer(timeInterval: PepoTasks.answerTimeout, repeats: false) {
      [weak self] _ in
      self?.complete(identifier, success: false)
    }
    RunLoop.main.add(timer, forMode: .common)
    timeouts[identifier] = timer
    deliver(identifier)
  }

  private func deliver(_ identifier: String) {
    guard let handler = onTask else {
      undelivered.append(identifier)
      return
    }
    handler(identifier)
  }
}
