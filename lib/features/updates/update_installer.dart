import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../platform/open_helper.dart';
import '../settings/update_checker.dart';
import 'update_archive.dart';
import 'update_desktop.dart';
import 'update_download.dart';
import 'update_target.dart';

enum UpdateInstallPhase { downloading, verifying, installing }

class UpdateProgress {
  const UpdateProgress({required this.phase, this.received = 0, this.total = 0});
  final UpdateInstallPhase phase;
  final int received;
  final int total;
  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

enum UpdateInstallOutcome { installerOpened, permissionRequired, externalRequired }

enum UpdateSupport { direct, android, flatpak, ios, unavailable }

class UpdateInstallException implements Exception {
  const UpdateInstallException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class UpdateInstaller {
  UpdateInstaller({
    UpdateRuntime? runtime,
    UpdateTransport Function()? transportFactory,
    Future<Directory> Function()? temporaryDirectory,
    MethodChannel? nativeChannel,
    List<String> launchArguments = const [],
    Future<bool> Function(String)? openFile,
    Future<DesktopHandoff> Function(DesktopUpdatePlan)? prepareDesktop,
  }) : _runtime = runtime ?? UpdateRuntime.current(),
       _transportFactory = transportFactory ?? HttpUpdateTransport.new,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _native = nativeChannel ?? const MethodChannel('org.pepoconnect/native'),
       _launchArguments = List.unmodifiable(launchArguments),
       _openFile = openFile ?? OpenHelper.openFile,
       _prepareDesktop = prepareDesktop ?? DesktopHandoff.prepare;

  final UpdateRuntime _runtime;
  final UpdateTransport Function() _transportFactory;
  final Future<Directory> Function() _temporaryDirectory;
  final MethodChannel _native;
  final List<String> _launchArguments;
  final Future<bool> Function(String) _openFile;
  final Future<DesktopHandoff> Function(DesktopUpdatePlan) _prepareDesktop;
  VerifiedUpdateDownload? _download;
  _VerifiedAsset? _verified;
  File? _extractionCancellation;
  bool _busy = false;
  bool _disposed = false;
  bool _cancelled = false;
  bool _handedOff = false;

  Future<UpdateSupport> support(UpdateCheckResult release) async {
    final target = selectUpdateTarget(_runtime, release);
    if (target == null) return UpdateSupport.unavailable;
    if (target.kind == UpdateTargetKind.ios) return UpdateSupport.ios;
    if (release.assetNamed('SHA256SUMS.txt') == null) return UpdateSupport.unavailable;
    if (target.kind == UpdateTargetKind.flatpak) return UpdateSupport.flatpak;
    if (target.kind == UpdateTargetKind.android) return UpdateSupport.android;
    if (!await File(target.launchPath).exists()) return UpdateSupport.unavailable;
    if (target.isBundle &&
        !await Directory(
          p.join(
            target.destination,
            target.kind == UpdateTargetKind.windowsBundle
                ? 'data/flutter_assets'
                : 'bundle/data/flutter_assets',
          ),
        ).exists()) {
      return UpdateSupport.unavailable;
    }
    return UpdateSupport.direct;
  }

  Future<UpdateInstallOutcome> install(
    UpdateCheckResult release, {
    required void Function(UpdateProgress) onProgress,
    required Future<void> Function() beforeRestart,
  }) async {
    if (_busy) throw const UpdateInstallException('busy', 'An update is already running');
    if (_disposed) throw const UpdateInstallException('cancelled', 'Updater is closed');
    final target = selectUpdateTarget(_runtime, release);
    if (!release.isNewer || target == null) {
      throw const UpdateInstallException('unsupported', 'No compatible update is available');
    }
    if (target.kind == UpdateTargetKind.ios) return UpdateInstallOutcome.externalRequired;
    _busy = true;
    _cancelled = false;
    _handedOff = false;
    Directory? downloads;
    Directory? work;
    var keepDownload = false;
    DesktopHandoff? handoff;
    try {
      final checksumAsset = release.assetNamed('SHA256SUMS.txt');
      final uri = Uri.parse(target.asset.url);
      if (checksumAsset == null ||
          !isOfficialAsset(uri, target.asset.name) ||
          !isOfficialAsset(Uri.parse(checksumAsset.url), 'SHA256SUMS.txt') ||
          !sameAssetRelease(uri, Uri.parse(checksumAsset.url)) ||
          normalizeVersion(uri.pathSegments[4]) != release.latest) {
        throw const UpdateInstallException(
          'verification',
          'This release has no matching checksum manifest',
        );
      }
      _download = VerifiedUpdateDownload(transport: _transportFactory());
      File payload;
      String checksum;
      final cached = _verified;
      if (target.kind == UpdateTargetKind.android &&
          cached != null &&
          cached.url == target.asset.url &&
          cached.size == target.asset.size &&
          await cached.file.exists()) {
        payload = cached.file;
        checksum = cached.checksum;
        downloads = cached.file.parent;
      } else {
        Directory base;
        if (target.kind == UpdateTargetKind.android) {
          final path = await _native.invokeMethod<String>('updateCacheDirectory');
          if (path == null) {
            throw const UpdateInstallException('install', 'Android update cache is unavailable');
          }
          base = Directory(path);
        } else {
          base = await _temporaryDirectory();
        }
        await base.create(recursive: true);
        downloads = await base.createTemp('pepoconnect-download-');
        final manifest = File(p.join(downloads.path, 'SHA256SUMS.txt'));
        await _download!.fetch(
          Uri.parse(checksumAsset.url),
          manifest,
          expectedSize: checksumAsset.size,
          maxBytes: 1024 * 1024,
        );
        checksum = checksumFor(await manifest.readAsString(), target.asset.name);
        payload = File(p.join(downloads.path, target.asset.name));
        onProgress(UpdateProgress(phase: UpdateInstallPhase.downloading, total: target.asset.size));
        await _download!.fetch(
          uri,
          payload,
          expectedSize: target.asset.size,
          maxBytes: 1024 * 1024 * 1024,
          onBytes: (received) => onProgress(
            UpdateProgress(
              phase: UpdateInstallPhase.downloading,
              received: received,
              total: target.asset.size,
            ),
          ),
        );
      }
      _checkCancelled();
      onProgress(const UpdateProgress(phase: UpdateInstallPhase.verifying));
      if (await payload.length() != target.asset.size) {
        throw const UpdateInstallException('verification', 'The update size changed');
      }
      await _download!.verify(payload, checksum);
      _checkCancelled();
      if (target.kind == UpdateTargetKind.android) {
        _verified = _VerifiedAsset(payload, target.asset.url, target.asset.size, checksum);
        onProgress(const UpdateProgress(phase: UpdateInstallPhase.installing));
        final response = await _native.invokeMethod<String>('updateInstall', {
          'path': payload.path,
          'version': release.latest,
          'sha256': checksum,
          'size': target.asset.size,
        });
        // PackageInstaller reads the content URI asynchronously after this returns.
        keepDownload = true;
        if (response == 'permissionRequired') return UpdateInstallOutcome.permissionRequired;
        if (response == 'installerOpened') return UpdateInstallOutcome.installerOpened;
        throw const UpdateInstallException(
          'install',
          'Android could not open the update installer',
        );
      }
      if (target.kind == UpdateTargetKind.flatpak) {
        onProgress(const UpdateProgress(phase: UpdateInstallPhase.installing));
        if (!await _openFile(payload.path)) {
          throw const UpdateInstallException(
            'unsupported',
            'The system software installer could not open this Flatpak. Install the release through your software manager.',
          );
        }
        keepDownload = true;
        return UpdateInstallOutcome.installerOpened;
      }
      if (await support(release) != UpdateSupport.direct) {
        throw const UpdateInstallException(
          'unsupported',
          'The application installation could not be identified',
        );
      }
      final parent = target.isBundle
          ? Directory(target.destination).parent
          : File(target.destination).parent;
      work = await parent.createTemp('.pepoconnect-update-');
      _extractionCancellation = File(p.join(work.path, 'cancel-extraction'));
      String staged;
      if (target.isBundle) {
        staged = await stageUpdateArchive(
          payload.path,
          p.join(work.path, 'package'),
          windows: _runtime.os == 'windows',
          cancellationFile: _extractionCancellation!.path,
        );
      } else {
        final copy = await payload.copy(p.join(work.path, 'payload'));
        await _download!.verify(copy, checksum);
        staged = copy.path;
        if (_runtime.os == 'linux') {
          final result = await Process.run('/bin/chmod', ['755', '--', staged]);
          if (result.exitCode != 0) {
            throw const UpdateInstallException(
              'permission',
              'The update cannot be made executable',
            );
          }
        }
      }
      _checkCancelled();
      onProgress(const UpdateProgress(phase: UpdateInstallPhase.installing));
      handoff = await _prepareDesktop(
        DesktopUpdatePlan(
          work: work,
          destination: target.destination,
          staged: staged,
          isBundle: target.isBundle,
          windows: _runtime.os == 'windows',
          launchPath: target.launchPath,
          launchArguments: _launchArguments,
          expectedExecutable: _runtime.executable,
        ),
      );
      _checkCancelled();
      // A real shutdown exits immediately, so cleanup must precede the callback.
      await downloads.delete(recursive: true);
      downloads = null;
      await handoff.commit();
      // Shutdown callbacks may exit the process instead of returning. The helper
      // still requires that exit; callback failures are explicitly revoked below.
      _handedOff = true;
      await beforeRestart();
      return UpdateInstallOutcome.installerOpened;
    } catch (error) {
      _handedOff = false;
      var canCleanWork = handoff == null;
      if (handoff != null) {
        try {
          await handoff.abort();
          canCleanWork = await handoff.finished.timeout(const Duration(seconds: 3)) == 'aborted';
        } catch (_) {
          /* Keep the recovery files if helper state is unknown. */
        }
      }
      if (canCleanWork && work != null && await work.exists()) {
        try {
          await work.delete(recursive: true);
        } on FileSystemException {
          /* Helper may still be exiting. */
        }
      }
      _checkCancelled();
      if (error is UpdateInstallException) rethrow;
      if (error is UpdateDownloadException) throw UpdateInstallException(error.code, error.message);
      if (error is FormatException) throw UpdateInstallException('verification', error.message);
      if (error is PlatformException) {
        throw UpdateInstallException(
          ['verification', 'permission', 'unsupported'].contains(error.code)
              ? error.code
              : 'install',
          error.message ?? 'Android update failed',
        );
      }
      if (error is FileSystemException && [5, 13].contains(error.osError?.errorCode)) {
        throw const UpdateInstallException('permission', 'The installation folder is not writable');
      }
      throw UpdateInstallException('install', error.toString());
    } finally {
      _busy = false;
      _download?.close();
      _download = null;
      _extractionCancellation = null;
      if (!keepDownload && downloads != null && await downloads.exists()) {
        try {
          await downloads.delete(recursive: true);
        } on FileSystemException {
          /* Retryable temporary cache. */
        }
      }
    }
  }

  Future<bool> canResumeAfterPermission() async {
    if (_runtime.os != 'android' || _verified == null) return false;
    try {
      return await _native.invokeMethod<bool>('updateCanInstall') ?? false;
    } on PlatformException {
      return false;
    }
  }

  void _checkCancelled() {
    if (_cancelled) throw const UpdateInstallException('cancelled', 'Update cancelled');
  }

  void cancel() {
    if (_handedOff) return;
    _cancelled = true;
    _download?.cancel();
    final marker = _extractionCancellation;
    if (marker != null) {
      try {
        marker.writeAsStringSync('cancel', flush: true);
      } on FileSystemException {
        /* Operation already ended. */
      }
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  /// Called only after application services start successfully on a new version.
  static Future<void> confirmStartup({Map<String, String>? environment}) async {
    final path = (environment ?? Platform.environment)['PEPOCONNECT_UPDATE_HEALTH'];
    if (path == null || path.isEmpty) return;
    final marker = File(path);
    if (marker.parent.path.split(Platform.pathSeparator).last.startsWith('.pepoconnect-update-') &&
        marker.uri.pathSegments.last == 'health') {
      try {
        if (await File(p.join(marker.parent.path, 'result')).exists()) return;
        await marker.writeAsString('healthy', flush: true);
      } on FileSystemException {
        /* Stale inherited markers never break startup. */
      }
    }
  }
}

class _VerifiedAsset {
  const _VerifiedAsset(this.file, this.url, this.size, this.checksum);
  final File file;
  final String url;
  final int size;
  final String checksum;
}
