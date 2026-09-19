import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/update_checker.dart';
import 'update_installer.dart';

/// Update bookkeeping lives separately from the user's settings/profile.
abstract interface class UpdateStore {
  String? read();
  Future<void> write(String value);
}

class PreferencesUpdateStore implements UpdateStore {
  PreferencesUpdateStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'pepo.updates';
  @override
  String? read() => preferences.getString(key);
  @override
  Future<void> write(String value) async {
    if (!await preferences.setString(key, value)) {
      throw StateError('Could not save update state');
    }
  }
}

enum UpdatePhase {
  idle,
  checking,
  available,
  upToDate,
  downloading,
  verifying,
  installing,
  installerOpened,
  permissionRequired,
  failed,
}

@immutable
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.release,
    this.support = UpdateSupport.unavailable,
    this.progress,
    this.errorCode,
  });
  final UpdatePhase phase;
  final UpdateCheckResult? release;
  final UpdateSupport support;
  final UpdateProgress? progress;
  final String? errorCode;
  bool get isInstalling => switch (phase) {
    UpdatePhase.downloading || UpdatePhase.verifying || UpdatePhase.installing => true,
    _ => false,
  };
  bool get busy => phase == UpdatePhase.checking || isInstalling;
  bool get canCancel =>
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.verifying ||
      phase == UpdatePhase.permissionRequired;
}

/// One state machine for settings, foreground offers and daily checks.
/// Dependencies and the clock are injectable so no test touches an installation.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.currentVersion,
    required this.store,
    required this.installer,
    required this.check,
    required this.beforeRestart,
    bool Function()? canInstall,
    DateTime Function()? now,
  }) : _canInstall = canInstall ?? (() => true),
       _now = now ?? DateTime.now {
    _restore();
  }

  static const checkInterval = Duration(hours: 24);
  static const retryInterval = Duration(hours: 1);
  static final _log = Logger('Updates');
  final String currentVersion;
  final UpdateStore store;
  final UpdateInstaller installer;
  final Future<UpdateCheckResult> Function() check;
  final Future<void> Function() beforeRestart;
  final bool Function() _canInstall;
  final DateTime Function() _now;
  UpdateState _state = const UpdateState();
  UpdateState get state => _state;
  DateTime? _lastSuccess;
  DateTime? _lastAttempt;
  bool _attemptFailed = false;
  String? _notifiedVersion;
  Future<void>? _checking;
  Future<void> _writes = Future<void>.value();
  bool _manualCheck = false;
  bool _supportLoaded = false;
  bool _loadingCachedSupport = false;
  bool _disposed = false;
  bool _resumingPermission = false;
  Timer? _timer;

  void _restore() {
    try {
      final raw = store.read();
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _lastSuccess = DateTime.tryParse(data['lastSuccess'] as String? ?? '');
      _lastAttempt = DateTime.tryParse(data['lastAttempt'] as String? ?? '');
      _attemptFailed = data['attemptFailed'] == true;
      _notifiedVersion = data['notifiedVersion'] as String?;
      final cached = data['release'];
      if (cached is Map<String, dynamic>) {
        final release = UpdateCheckResult.fromJson(cached, current: currentVersion);
        _state = UpdateState(
          phase: release.isNewer ? UpdatePhase.available : UpdatePhase.upToDate,
          release: release,
        );
      }
    } catch (_) {
      // An unreadable cache must never stop a fresh check or reset user settings.
      _lastSuccess = null;
      _lastAttempt = null;
      _attemptFailed = false;
    }
  }

  Future<void> _persist() {
    final data = jsonEncode({
      'lastSuccess': _lastSuccess?.toUtc().toIso8601String(),
      'lastAttempt': _lastAttempt?.toUtc().toIso8601String(),
      'attemptFailed': _attemptFailed,
      'notifiedVersion': _notifiedVersion,
      'release': _state.release?.toJson(),
    });
    _writes = _writes.then((_) => store.write(data)).catchError((Object error) {
      _log.warning('Could not persist update bookkeeping', error);
    });
    return _writes;
  }

  void _set(UpdateState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  /// The minute tick handles clock changes and long-lived/tray sessions. The
  /// persisted 24-hour gate determines whether it actually contacts GitHub.
  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(checkIfDue()));
    unawaited(checkIfDue());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Android's settings activity pauses Flutter. Continue the verified APK
  /// once permission is granted, without reopening settings after a denial.
  Future<void> resumed() async {
    if (_disposed) return;
    if (_state.phase == UpdatePhase.permissionRequired && !_resumingPermission) {
      _resumingPermission = true;
      try {
        if (await installer.canResumeAfterPermission() &&
            !_disposed &&
            _state.phase == UpdatePhase.permissionRequired) {
          await install();
        }
      } catch (error) {
        _log.fine('Could not resume the system installer', error);
      } finally {
        _resumingPermission = false;
      }
    }
    await checkIfDue();
  }

  bool get _due {
    final last = _attemptFailed ? _lastAttempt : _lastSuccess;
    if (last == null) return true;
    final elapsed = _now().difference(last);
    return elapsed.isNegative || elapsed >= (_attemptFailed ? retryInterval : checkInterval);
  }

  Future<void> checkIfDue() async {
    if (_disposed || _state.isInstalling || _state.phase == UpdatePhase.permissionRequired) return;
    if (!_due) {
      await _loadCachedSupport();
      return;
    }
    await _runCheck(manual: false);
  }

  Future<void> _loadCachedSupport() async {
    final release = _state.release;
    if (_supportLoaded ||
        _loadingCachedSupport ||
        _state.busy ||
        release == null ||
        !release.isNewer) {
      return;
    }
    _loadingCachedSupport = true;
    try {
      final support = await installer.support(release);
      if (_disposed || _state.release != release || _state.busy) return;
      _supportLoaded = true;
      _set(
        UpdateState(
          phase: _state.phase,
          release: release,
          support: support,
          progress: _state.progress,
          errorCode: _state.errorCode,
        ),
      );
    } catch (error) {
      _log.fine('Could not identify installation format', error);
    } finally {
      _loadingCachedSupport = false;
    }
  }

  Future<void> checkNow() => _runCheck(manual: true);

  Future<void> _runCheck({required bool manual}) {
    if (_disposed || _state.isInstalling || _state.phase == UpdatePhase.permissionRequired) {
      return Future<void>.value();
    }
    _manualCheck = _manualCheck || manual;
    return _checking ??= _performCheck().whenComplete(() {
      _checking = null;
      _manualCheck = false;
    });
  }

  Future<void> _performCheck() async {
    final previous = _state;
    _set(
      UpdateState(
        phase: UpdatePhase.checking,
        release: previous.release,
        support: previous.support,
      ),
    );
    try {
      final release = await check();
      if (_disposed) return;
      final support = release.isNewer
          ? await installer.support(release)
          : UpdateSupport.unavailable;
      if (_disposed) return;
      _supportLoaded = true;
      _lastSuccess = _lastAttempt = _now();
      _attemptFailed = false;
      _set(
        UpdateState(
          phase: release.isNewer ? UpdatePhase.available : UpdatePhase.upToDate,
          release: release,
          support: support,
        ),
      );
    } catch (error) {
      if (_disposed) return;
      _lastAttempt = _now();
      _attemptFailed = true;
      _log.fine('Update check failed; a later check will retry', error);
      _set(
        _manualCheck
            ? UpdateState(
                phase: UpdatePhase.failed,
                release: previous.release,
                support: previous.support,
                errorCode: 'check',
              )
            : previous,
      );
    }
    if (!_disposed) await _persist();
  }

  bool shouldPrompt({required bool notificationsEnabled}) =>
      notificationsEnabled &&
      !_state.busy &&
      _state.phase == UpdatePhase.available &&
      _state.release?.isNewer == true &&
      _state.support != UpdateSupport.unavailable &&
      _state.release!.latest != _notifiedVersion;

  Future<void> markNotified([String? offeredVersion]) async {
    _notifiedVersion = offeredVersion ?? _state.release?.latest;
    await _persist();
  }

  Future<void> install() async {
    if (_disposed || _state.busy || _state.release?.isNewer != true) return;
    // An offer may have been cached for a day, including across restarts and
    // failed upgrades. Clicking Install must fetch today's package, not retry
    // an obsolete installer. Keep Android's already verified permission flow.
    if (_state.phase != UpdatePhase.permissionRequired && _canInstall()) {
      await checkNow();
      if (_disposed || _state.phase != UpdatePhase.available) return;
    }
    final release = _state.release;
    final support = _state.support;
    if (_disposed || _state.busy || release == null || !release.isNewer) return;
    if (!_canInstall()) {
      _set(
        UpdateState(
          phase: UpdatePhase.failed,
          release: release,
          support: support,
          errorCode: 'busy',
        ),
      );
      return;
    }
    _set(UpdateState(phase: UpdatePhase.downloading, release: release, support: support));
    try {
      final outcome = await installer.install(
        release,
        onProgress: (progress) {
          if (progress.phase == UpdateInstallPhase.installing && !_canInstall()) {
            throw const UpdateInstallException('busy', 'Transfers are still active');
          }
          _set(
            UpdateState(
              phase: switch (progress.phase) {
                UpdateInstallPhase.downloading => UpdatePhase.downloading,
                UpdateInstallPhase.verifying => UpdatePhase.verifying,
                UpdateInstallPhase.installing => UpdatePhase.installing,
              },
              release: release,
              support: support,
              progress: progress,
            ),
          );
        },
        beforeRestart: () async {
          if (_disposed || !_canInstall()) {
            throw const UpdateInstallException('busy', 'Transfers are still active');
          }
          await beforeRestart();
        },
      );
      _set(
        UpdateState(
          phase: switch (outcome) {
            UpdateInstallOutcome.installerOpened => UpdatePhase.installerOpened,
            UpdateInstallOutcome.permissionRequired => UpdatePhase.permissionRequired,
            UpdateInstallOutcome.externalRequired => UpdatePhase.available,
          },
          release: release,
          support: support,
        ),
      );
    } catch (error) {
      final code = error is UpdateInstallException ? error.code : 'install';
      _log.fine('Update installation did not complete', error);
      _set(
        UpdateState(
          phase: code == 'cancelled' ? UpdatePhase.available : UpdatePhase.failed,
          release: release,
          support: support,
          errorCode: code == 'cancelled' ? null : code,
        ),
      );
    }
  }

  void cancelDownload() {
    if (!_state.canCancel) return;
    installer.cancel();
    if (_state.phase == UpdatePhase.permissionRequired) {
      _set(
        UpdateState(phase: UpdatePhase.available, release: _state.release, support: _state.support),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    installer.dispose();
    super.dispose();
  }
}
