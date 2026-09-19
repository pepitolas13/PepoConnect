import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/features/settings/update_checker.dart';
import 'package:pepoconnect/features/updates/update_controller.dart';
import 'package:pepoconnect/features/updates/update_installer.dart';
import 'package:pepoconnect/state/app_settings.dart';

class MemoryUpdateStore implements UpdateStore {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class TestInstaller extends UpdateInstaller {
  int installs = 0;
  String? installedVersion;
  bool cancelled = false;
  Completer<UpdateInstallOutcome>? pending;
  Completer<UpdateSupport>? pendingSupport;
  UpdateSupport supported = UpdateSupport.direct;
  bool permissionGranted = false;
  bool restart = false;
  bool handoffProgress = false;
  @override
  Future<bool> canResumeAfterPermission() async => permissionGranted;
  @override
  Future<UpdateSupport> support(UpdateCheckResult release) async =>
      pendingSupport?.future ?? supported;
  @override
  Future<UpdateInstallOutcome> install(
    UpdateCheckResult release, {
    required void Function(UpdateProgress) onProgress,
    required Future<void> Function() beforeRestart,
  }) async {
    installs++;
    installedVersion = release.latest;
    onProgress(const UpdateProgress(phase: UpdateInstallPhase.downloading, received: 5, total: 10));
    final outcome = await (pending?.future ?? Future.value(UpdateInstallOutcome.installerOpened));
    if (handoffProgress) onProgress(const UpdateProgress(phase: UpdateInstallPhase.installing));
    if (restart) await beforeRestart();
    return outcome;
  }

  @override
  void cancel() => cancelled = true;
  @override
  void dispose() {}
}

UpdateCheckResult release([String version = '0.4.0']) => UpdateCheckResult.fromJson({
  'tag_name': 'v$version',
  'html_url': '$repositoryUrl/releases/tag/v$version',
}, current: '0.3.0');

void main() {
  late MemoryUpdateStore store;
  late TestInstaller installer;
  late DateTime now;
  late int checks;
  late Future<UpdateCheckResult> Function() fetch;
  late bool transfers;

  UpdateController make() => UpdateController(
    currentVersion: '0.3.0',
    store: store,
    installer: installer,
    check: () {
      checks++;
      return fetch();
    },
    now: () => now,
    canInstall: () => !transfers,
    beforeRestart: () async {},
  );

  setUp(() {
    store = MemoryUpdateStore();
    installer = TestInstaller();
    now = DateTime.utc(2026, 9, 18, 12);
    checks = 0;
    transfers = false;
    fetch = () async => release();
  });

  test('checks daily across restarts; manual checks bypass the interval', () async {
    var controller = make();
    await controller.checkIfDue();
    expect(checks, 1);
    expect(controller.state.phase, UpdatePhase.available);
    controller.dispose();
    controller = make();
    addTearDown(controller.dispose);
    await controller.checkIfDue();
    expect(checks, 1);
    expect(controller.state.release?.latest, '0.4.0');
    now = now.add(const Duration(hours: 23, minutes: 59));
    await controller.checkIfDue();
    expect(checks, 1);
    now = now.add(const Duration(minutes: 1));
    await controller.checkIfDue();
    expect(checks, 2);
    await controller.checkNow();
    expect(checks, 3);
  });

  test('install refreshes a cached offer from 0.4.1 to 0.4.2 before downloading', () async {
    fetch = () async => release('0.4.1');
    var controller = make();
    await controller.checkNow();
    controller.dispose();
    controller = make();
    addTearDown(controller.dispose);
    fetch = () async => release('0.4.2');
    await controller.install();
    expect(installer.installedVersion, '0.4.2');
    expect(checks, 2, reason: 'Install bypasses the daily cache gate');
  });

  test('install never falls back to a stale package if refresh fails', () async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.checkNow();
    fetch = () async => throw const FormatException('offline');
    await controller.install();
    expect(installer.installs, 0);
    expect(controller.state.errorCode, 'check');
  });

  test('duplicate install clicks share refresh and download only once', () async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.checkNow();
    final refreshed = Completer<UpdateCheckResult>();
    fetch = () => refreshed.future;
    final first = controller.install();
    final second = controller.install();
    expect(installer.installs, 0);
    refreshed.complete(release('0.4.2'));
    await Future.wait([first, second]);
    expect(installer.installs, 1);
    expect(installer.installedVersion, '0.4.2');
  });

  test('concurrent manual and automatic checks share one request', () async {
    final response = Completer<UpdateCheckResult>();
    fetch = () => response.future;
    final controller = make();
    addTearDown(controller.dispose);
    final first = controller.checkIfDue();
    final second = controller.checkNow();
    response.complete(release());
    await Future.wait([first, second]);
    expect(checks, 1);
  });

  test('cached support retries after a concurrent failed manual check', () async {
    var controller = make();
    await controller.checkIfDue();
    controller.dispose();
    installer.pendingSupport = Completer<UpdateSupport>();
    controller = make();
    addTearDown(controller.dispose);
    final cachedSupport = controller.checkIfDue();
    final response = Completer<UpdateCheckResult>();
    fetch = () => response.future;
    final manual = controller.checkNow();
    installer.pendingSupport!.complete(UpdateSupport.direct);
    await cachedSupport;
    response.completeError(const FormatException('offline'));
    await manual;
    installer.pendingSupport = null;
    await controller.checkIfDue();
    expect(checks, 2);
    expect(controller.state.support, UpdateSupport.direct);
    expect(controller.state.errorCode, 'check');
  });

  test('automatic errors stay quiet and retry after an hour, also after restart', () async {
    fetch = () async => throw const FormatException('offline');
    var controller = make();
    await controller.checkIfDue();
    expect(controller.state.errorCode, isNull);
    controller.dispose();
    controller = make();
    addTearDown(controller.dispose);
    await controller.checkIfDue();
    expect(checks, 1);
    now = now.add(const Duration(hours: 1));
    await controller.checkIfDue();
    expect(checks, 2);
    await controller.checkNow();
    expect(controller.state.errorCode, 'check');
  });

  test('an offer is persisted once per version and opt-out leaves checks working', () async {
    var controller = make();
    await controller.checkIfDue();
    expect(controller.shouldPrompt(notificationsEnabled: true), isTrue);
    expect(controller.shouldPrompt(notificationsEnabled: false), isFalse);
    await controller.markNotified();
    controller.dispose();
    controller = make();
    addTearDown(controller.dispose);
    await controller.checkIfDue();
    expect(controller.shouldPrompt(notificationsEnabled: true), isFalse);
    fetch = () async => release('0.5.0');
    now = now.add(const Duration(days: 1));
    await controller.checkIfDue();
    expect(controller.shouldPrompt(notificationsEnabled: true), isTrue);
  });

  test('incomplete packages are visible manually but do not raise automatic offers', () async {
    installer.supported = UpdateSupport.unavailable;
    final controller = make();
    addTearDown(controller.dispose);
    await controller.checkIfDue();
    expect(controller.state.release?.isNewer, isTrue);
    expect(controller.shouldPrompt(notificationsEnabled: true), isFalse);
  });

  test('manual checks cannot dismiss an offer the user has not seen', () async {
    var controller = make();
    await controller.checkNow();
    expect(controller.shouldPrompt(notificationsEnabled: true), isTrue);
    controller.dispose();
    controller = make();
    addTearDown(controller.dispose);
    await controller.checkIfDue();
    expect(controller.shouldPrompt(notificationsEnabled: true), isTrue);
  });

  test('serializes installs and blocks active transfers', () async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.checkNow();
    transfers = true;
    await controller.install();
    expect(installer.installs, 0);
    expect(controller.state.errorCode, 'busy');
    transfers = false;
    installer.pending = Completer<UpdateInstallOutcome>();
    final installing = controller.install();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.progress?.fraction, 0.5);
    await controller.install();
    await controller.checkNow();
    expect(installer.installs, 1);
    expect(checks, 2);
    installer.pending!.complete(UpdateInstallOutcome.permissionRequired);
    await installing;
    expect(controller.state.phase, UpdatePhase.permissionRequired);
  });

  test('cancel is forwarded and a disposed request cannot notify or install', () async {
    final controller = make();
    await controller.checkNow();
    installer.pending = Completer<UpdateInstallOutcome>();
    final work = controller.install();
    await Future<void>.delayed(Duration.zero);
    controller.cancelDownload();
    expect(installer.cancelled, isTrue);
    controller.dispose();
    installer.pending!.complete(UpdateInstallOutcome.installerOpened);
    await work;
  });

  test('returning from Android permission continues only when permission is granted', () async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.checkNow();
    installer.pending = Completer<UpdateInstallOutcome>();
    final first = controller.install();
    installer.pending!.complete(UpdateInstallOutcome.permissionRequired);
    await first;
    installer.pending = null;
    await controller.resumed();
    expect(installer.installs, 1);
    installer.permissionGranted = true;
    await Future.wait([controller.resumed(), controller.resumed()]);
    expect(installer.installs, 2);
    expect(controller.state.phase, UpdatePhase.installerOpened);
  });

  test('rechecks active transfers after downloading, before restarting', () async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.checkNow();
    installer.restart = true;
    installer.pending = Completer<UpdateInstallOutcome>();
    final work = controller.install();
    await Future<void>.delayed(Duration.zero);
    expect(installer.installs, 1);
    transfers = true;
    installer.pending!.complete(UpdateInstallOutcome.installerOpened);
    await work;
    expect(controller.state.errorCode, 'busy');
  });

  test('daily check cannot erase Android permission flow; cancelling releases the check', () async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.checkNow();
    now = now.add(const Duration(days: 1));
    installer.pending = Completer<UpdateInstallOutcome>();
    final work = controller.install();
    installer.pending!.complete(UpdateInstallOutcome.permissionRequired);
    await work;
    now = now.add(const Duration(days: 1));
    await controller.checkIfDue();
    expect(checks, 2);
    expect(controller.state.phase, UpdatePhase.permissionRequired);
    controller.cancelDownload();
    expect(controller.state.phase, UpdatePhase.available);
    await controller.checkIfDue();
    expect(checks, 3);
  });

  test('native installer handoff rechecks transfers after the download', () async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.checkNow();
    installer.handoffProgress = true;
    installer.pending = Completer<UpdateInstallOutcome>();
    final work = controller.install();
    await Future<void>.delayed(Duration.zero);
    expect(installer.installs, 1);
    transfers = true;
    installer.pending!.complete(UpdateInstallOutcome.installerOpened);
    await work;
    expect(controller.state.errorCode, 'busy');
  });

  test('corrupt cache and future timestamps do not disable checks permanently', () async {
    store.value = '{broken';
    var controller = make();
    await controller.checkNow();
    controller.dispose();
    now = now.subtract(const Duration(days: 5));
    controller = make();
    addTearDown(controller.dispose);
    await controller.checkIfDue();
    expect(checks, 2);
  });

  test('update notification preference is independent and backward compatible', () {
    expect(AppSettings.fromJson({}).updateNotifications, isTrue);
    final settings = const AppSettings().copyWith(updateNotifications: false);
    expect(settings.notifications, isTrue);
    expect(AppSettings.fromJson(settings.toJson()).updateNotifications, isFalse);
  });
}
