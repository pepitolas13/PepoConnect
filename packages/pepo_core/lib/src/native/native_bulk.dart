// Bindings to the Rust fast lane (`packages/pepo_native/rust`): encrypted
// bulk file transfers over plain TCP, several hundred MB/s. Everything here
// is optional: when the library cannot be loaded the engine keeps using the
// TLS bulk channels written in Dart.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _log = Logger('pepo.native');

typedef _AbiVersionC = Uint32 Function();
typedef _AbiVersionD = int Function();
typedef _InitDartC = Int32 Function(Pointer<Void>);
typedef _InitDartD = int Function(Pointer<Void>);
typedef _NewC = Pointer<Void> Function(Int64);
typedef _NewD = Pointer<Void> Function(int);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _FreeD = void Function(Pointer<Void>);
typedef _ListenC = Int32 Function(Pointer<Void>, Uint16);
typedef _ListenD = int Function(Pointer<Void>, int);
typedef _SessionAddC = Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>);
typedef _SessionAddD = int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>);
typedef _SessionRemoveC = Int32 Function(Pointer<Void>, Pointer<Uint8>);
typedef _SessionRemoveD = int Function(Pointer<Void>, Pointer<Uint8>);
typedef _StartC = Int32 Function(
  Pointer<Void>,
  Uint64,
  Uint32,
  Pointer<Uint8>,
  Pointer<Uint8>,
  Uint8,
  Pointer<Utf8>,
  Uint64,
  Uint64,
  Pointer<Utf8>,
  Uint16,
);
typedef _StartD = int Function(
  Pointer<Void>,
  int,
  int,
  Pointer<Uint8>,
  Pointer<Uint8>,
  int,
  Pointer<Utf8>,
  int,
  int,
  Pointer<Utf8>,
  int,
);
typedef _CancelC = Void Function(Pointer<Void>, Uint64);
typedef _CancelD = void Function(Pointer<Void>, int);
typedef _Xxh3C = Uint64 Function(Pointer<Uint8>, Size);
typedef _Xxh3D = int Function(Pointer<Uint8>, int);

/// The ABI this Dart code was written against.
const int nativeBulkAbiVersion = 1;

/// Library base name (`pepo_native.dll`, `libpepo_native.so`).
const String nativeBulkLibraryName = 'pepo_native';

/// Environment variable that points at a specific library file (tests).
const String nativeBulkLibraryEnv = 'PEPO_NATIVE_LIB';

class NativeBulkException implements Exception {
  NativeBulkException(this.message);
  final String message;

  bool get isCancelled => message == 'cancelled';

  @override
  String toString() => 'NativeBulkException: $message';
}

class NativeBulkResult {
  const NativeBulkResult({required this.bytes, required this.hashHex});

  /// Bytes moved by this job (from the offset).
  final int bytes;

  /// xxh3-64 of those bytes, 16 lowercase hex digits.
  final String hashHex;
}

/// One running transfer on the fast lane.
class NativeJob {
  NativeJob._(this.id, this._engine);

  final int id;
  final NativeBulk _engine;
  final Completer<NativeBulkResult> _completer = Completer<NativeBulkResult>();
  void Function(int bytes)? onProgress;

  /// Completes with the bytes and hash, or fails with [NativeBulkException].
  Future<NativeBulkResult> get done => _completer.future;

  bool get isDone => _completer.isCompleted;

  void cancel() => _engine.cancel(this);
}

/// The fast lane engine of this process: one listener, the session keys of
/// connected peers and the jobs in flight.
class NativeBulk {
  NativeBulk._(this._lib) {
    _abiVersion = _lib.lookupFunction<_AbiVersionC, _AbiVersionD>('pepo_native_abi_version');
    _initDart = _lib.lookupFunction<_InitDartC, _InitDartD>('pepo_native_init_dart');
    _new = _lib.lookupFunction<_NewC, _NewD>('pepo_native_new');
    _free = _lib.lookupFunction<_FreeC, _FreeD>('pepo_native_free');
    _listen = _lib.lookupFunction<_ListenC, _ListenD>('pepo_native_listen');
    _sessionAdd = _lib.lookupFunction<_SessionAddC, _SessionAddD>('pepo_native_session_add');
    _sessionRemove = _lib.lookupFunction<_SessionRemoveC, _SessionRemoveD>(
      'pepo_native_session_remove',
    );
    _start = _lib.lookupFunction<_StartC, _StartD>('pepo_native_start');
    _cancel = _lib.lookupFunction<_CancelC, _CancelD>('pepo_native_cancel');
    _xxh3 = _lib.lookupFunction<_Xxh3C, _Xxh3D>('pepo_native_xxh3');
  }

  final DynamicLibrary _lib;
  late final _AbiVersionD _abiVersion;
  late final _InitDartD _initDart;
  late final _NewD _new;
  late final _FreeD _free;
  late final _ListenD _listen;
  late final _SessionAddD _sessionAdd;
  late final _SessionRemoveD _sessionRemove;
  late final _StartD _start;
  late final _CancelD _cancel;
  late final _Xxh3D _xxh3;

  final ReceivePort _events = ReceivePort('pepo_native');
  StreamSubscription<dynamic>? _sub;
  Pointer<Void> _engine = nullptr;
  final Map<int, NativeJob> _jobs = {};
  int _nextJob = 1;
  int _port = 0;
  bool _disposed = false;

  /// Why the last [tryLoad] returned null (for the About page / logs).
  static String? lastLoadError;

  /// Port of the bulk listener, 0 until [listen] succeeded.
  int get port => _port;
  bool get isListening => _port != 0;

  /// Loads the library and creates the engine, or returns null (with
  /// [lastLoadError] set) when the fast lane is not available here.
  static NativeBulk? tryLoad({String? libraryPath}) {
    final candidates = <String>[
      ?libraryPath,
      if (Platform.environment[nativeBulkLibraryEnv] case final env? when env.isNotEmpty) env,
      ..._defaultCandidates(),
    ];
    Object? lastError;
    for (final c in candidates) {
      try {
        final lib = c == '<process>' ? DynamicLibrary.process() : DynamicLibrary.open(c);
        final n = NativeBulk._(lib);
        final abi = n._abiVersion();
        if (abi != nativeBulkAbiVersion) {
          throw StateError('ABI $abi, expected $nativeBulkAbiVersion');
        }
        n._boot();
        lastLoadError = null;
        return n;
      } catch (e) {
        lastError = e;
      }
    }
    lastLoadError = '$lastError';
    _log.info('fast lane not available: $lastError');
    return null;
  }

  static List<String> _defaultCandidates() {
    if (Platform.isIOS || Platform.isMacOS) return const ['<process>'];
    final exeDir = p.dirname(Platform.resolvedExecutable);
    if (Platform.isWindows) {
      return ['$nativeBulkLibraryName.dll', p.join(exeDir, '$nativeBulkLibraryName.dll')];
    }
    if (Platform.isAndroid) return ['lib$nativeBulkLibraryName.so'];
    return [
      'lib$nativeBulkLibraryName.so',
      p.join(exeDir, 'lib', 'lib$nativeBulkLibraryName.so'),
      p.join(exeDir, 'lib$nativeBulkLibraryName.so'),
    ];
  }

  void _boot() {
    final rc = _initDart(NativeApi.postCObject.cast<Void>());
    if (rc != 0) throw StateError('pepo_native_init_dart failed ($rc)');
    _engine = _new(_events.sendPort.nativePort);
    if (_engine == nullptr) throw StateError('pepo_native_new failed');
    _sub = _events.listen(_onEvent);
  }

  /// Binds the bulk listener (port 0 = any free port) and returns the port.
  /// Returns 0 when binding failed; the fast lane then only works for
  /// transfers where the peer listens.
  int listen({int port = 0}) {
    if (_disposed) return 0;
    final bound = _listen(_engine, port);
    _port = bound > 0 ? bound : 0;
    return _port;
  }

  /// Registers the key of a session so the peer's connections are accepted.
  void addSession(Uint8List sid, Uint8List key) {
    _check(sid, key);
    final s = _bytes(sid);
    final k = _bytes(key);
    try {
      _sessionAdd(_engine, s, k);
    } finally {
      calloc.free(s);
      calloc.free(k);
    }
  }

  void removeSession(Uint8List sid) {
    if (sid.length != 16) throw ArgumentError('sid must be 16 bytes');
    final s = _bytes(sid);
    try {
      _sessionRemove(_engine, s);
    } finally {
      calloc.free(s);
    }
  }

  /// Sends [path] from [offset]. With [host] the job connects to the peer's
  /// listener; without it the peer connects to ours.
  NativeJob send({
    required Uint8List sid,
    required Uint8List key,
    required int transferId,
    required String path,
    int offset = 0,
    String? host,
    int port = 0,
    void Function(int bytes)? onProgress,
  }) => _startJob(
    sid: sid,
    key: key,
    transferId: transferId,
    role: 0,
    path: path,
    offset: offset,
    size: 0,
    host: host,
    port: port,
    onProgress: onProgress,
  );

  /// Receives into [path] (truncated to [offset] first). [size] is the
  /// announced total, used to refuse excess data.
  NativeJob receive({
    required Uint8List sid,
    required Uint8List key,
    required int transferId,
    required String path,
    int offset = 0,
    int size = 0,
    String? host,
    int port = 0,
    void Function(int bytes)? onProgress,
  }) => _startJob(
    sid: sid,
    key: key,
    transferId: transferId,
    role: 1,
    path: path,
    offset: offset,
    size: size,
    host: host,
    port: port,
    onProgress: onProgress,
  );

  NativeJob _startJob({
    required Uint8List sid,
    required Uint8List key,
    required int transferId,
    required int role,
    required String path,
    required int offset,
    required int size,
    required String? host,
    required int port,
    required void Function(int bytes)? onProgress,
  }) {
    if (_disposed) throw NativeBulkException('engine disposed');
    _check(sid, key);
    final job = NativeJob._(_nextJob++, this)..onProgress = onProgress;
    _jobs[job.id] = job;
    final s = _bytes(sid);
    final k = _bytes(key);
    final pathC = path.toNativeUtf8();
    final hostC = host?.toNativeUtf8() ?? nullptr;
    try {
      final rc = _start(_engine, job.id, transferId, s, k, role, pathC, offset, size, hostC, port);
      if (rc != 0) {
        _jobs.remove(job.id);
        job._completer.completeError(NativeBulkException('cannot start job ($rc)'));
      }
    } finally {
      calloc.free(s);
      calloc.free(k);
      calloc.free(pathC);
      if (hostC != nullptr) calloc.free(hostC);
    }
    return job;
  }

  void cancel(NativeJob job) {
    if (_disposed || job.isDone) return;
    _cancel(_engine, job.id);
  }

  /// xxh3-64 as computed by the native side (16 hex digits).
  String xxh3Hex(Uint8List data) {
    final ptr = _bytes(data);
    try {
      // Dart ints are signed 64-bit: go through BigInt for the unsigned hex.
      return BigInt.from(_xxh3(ptr, data.length)).toUnsigned(64).toRadixString(16).padLeft(16, '0');
    } finally {
      calloc.free(ptr);
    }
  }

  void _onEvent(dynamic message) {
    if (message is! String) return;
    final parts = message.split('\t');
    if (parts.length < 3) return;
    final id = int.tryParse(parts[1]);
    if (id == null) return;
    final job = _jobs[id];
    if (job == null) return;
    switch (parts[0]) {
      case 'p':
        final bytes = int.tryParse(parts[2]);
        if (bytes != null) job.onProgress?.call(bytes);
      case 'd':
        _jobs.remove(id);
        final bytes = int.tryParse(parts[2]) ?? 0;
        final hash = parts.length > 3 ? parts[3] : '';
        if (!job._completer.isCompleted) {
          job._completer.complete(NativeBulkResult(bytes: bytes, hashHex: hash));
        }
      case 'e':
        _jobs.remove(id);
        if (!job._completer.isCompleted) {
          job._completer.completeError(NativeBulkException(parts.sublist(2).join('\t')));
        }
    }
  }

  static void _check(Uint8List sid, Uint8List key) {
    if (sid.length != 16) throw ArgumentError('sid must be 16 bytes');
    if (key.length != 32) throw ArgumentError('key must be 32 bytes');
  }

  static Pointer<Uint8> _bytes(Uint8List data) {
    final ptr = calloc<Uint8>(data.isEmpty ? 1 : data.length);
    ptr.asTypedList(data.isEmpty ? 1 : data.length).setAll(0, data);
    return ptr;
  }

  /// Cancels every job, closes the listener and frees the engine.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final job in _jobs.values.toList()) {
      if (!job._completer.isCompleted) {
        job._completer.completeError(NativeBulkException('engine disposed'));
      }
    }
    _jobs.clear();
    if (_engine != nullptr) {
      _free(_engine);
      _engine = nullptr;
    }
    _sub?.cancel();
    _events.close();
    _port = 0;
  }
}
