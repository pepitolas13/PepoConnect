import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'chime_synth.dart';
import 'pepo_native.dart';

/// The chime that rings when transfers finish (Settings → Sonidos).
final transferChimeProvider = Provider<TransferChime>((ref) {
  final chime = TransferChime();
  ref.onDispose(chime.dispose);
  return chime;
});

/// Renders a fresh variation of the chime and plays it. A burst of files
/// finishing together rings once, and two chimes are never closer than
/// [cooldown].
class TransferChime {
  TransferChime({ChimeBackend? backend, Random? random})
    : _backend = backend ?? ChimeBackend.forPlatform(),
      _random = random ?? Random();

  /// Quiet time after a finished transfer before the chime rings.
  static const coalesce = Duration(milliseconds: 250);

  /// Minimum spacing between two chimes.
  static const cooldown = Duration(milliseconds: 900);

  final ChimeBackend _backend;
  final Random _random;
  Timer? _timer;
  DateTime? _lastPlay;

  /// A transfer finished. Rings after [coalesce] unless [busy] says other
  /// transfers are still running: their own completion rings later.
  void ping({bool Function()? busy}) {
    if (_timer?.isActive ?? false) return;
    var delay = coalesce;
    final last = _lastPlay;
    if (last != null) {
      final remaining = cooldown - DateTime.now().difference(last);
      if (remaining > delay) delay = remaining;
    }
    _timer = Timer(delay, () {
      if (busy?.call() ?? false) return;
      unawaited(play());
    });
  }

  /// Rings right now (the settings preview).
  Future<void> play() async {
    if (!_backend.enabled) return;
    _lastPlay = DateTime.now();
    try {
      final seed = _random.nextInt(1 << 32);
      final wav = await Isolate.run(() => _render(seed));
      await _backend.play(wav);
    } catch (_) {
      // Sound is best effort: it never gets in the way of a transfer.
    }
  }

  void dispose() {
    _timer?.cancel();
    _backend.dispose();
  }
}

Uint8List _render(int seed) => const ChimeSynth().render(Random(seed));

/// Plays a WAV. One implementation per platform, all best effort.
abstract class ChimeBackend {
  const ChimeBackend();

  factory ChimeBackend.forPlatform() {
    if (Platform.isWindows) return _WinmmBackend();
    if (Platform.isAndroid || Platform.isIOS) return const _ChannelBackend();
    if (Platform.isLinux || Platform.isMacOS) return _ProcessBackend();
    return const SilentChimeBackend();
  }

  /// False when nothing will be heard; the chime then skips the synthesis.
  bool get enabled => true;

  Future<void> play(Uint8List wav);

  void dispose() {}
}

/// Never makes a sound (tests).
class SilentChimeBackend extends ChimeBackend {
  const SilentChimeBackend();

  @override
  bool get enabled => false;

  @override
  Future<void> play(Uint8List wav) async {}
}

/// Windows: `PlaySound` from winmm with the WAV in memory. The buffer has to
/// outlive the asynchronous playback, so it is kept until the next chime.
class _WinmmBackend extends ChimeBackend {
  _WinmmBackend();

  static const _sndAsync = 0x0001;
  static const _sndNoDefault = 0x0002;
  static const _sndMemory = 0x0004;

  late final _playSound = DynamicLibrary.open('winmm.dll')
      .lookupFunction<
        Int32 Function(Pointer<Uint8>, IntPtr, Uint32),
        int Function(Pointer<Uint8>, int, int)
      >('PlaySoundW');
  Pointer<Uint8>? _playing;

  @override
  Future<void> play(Uint8List wav) async {
    final buffer = calloc<Uint8>(wav.length);
    buffer.asTypedList(wav.length).setAll(0, wav);
    // PlaySound stops whatever was playing before it starts the new sound, so
    // the previous buffer can go.
    final ok = _playSound(buffer, 0, _sndMemory | _sndAsync | _sndNoDefault) != 0;
    _release();
    if (!ok) {
      calloc.free(buffer);
      throw StateError('PlaySound failed');
    }
    _playing = buffer;
  }

  void _release() {
    final old = _playing;
    _playing = null;
    if (old != null) calloc.free(old);
  }

  @override
  void dispose() {
    if (_playing != null) _playSound(nullptr, 0, 0);
    _release();
  }
}

/// Android and iOS: the native side plays the WAV (`PepoNative.playWav`).
class _ChannelBackend extends ChimeBackend {
  const _ChannelBackend();

  @override
  Future<void> play(Uint8List wav) =>
      PepoNative.playWav(wav, sampleRate: ChimeSynth.defaultSampleRate);
}

/// Linux and macOS: the WAV goes to a temp file and a command-line player
/// plays it. The first player that works is kept.
class _ProcessBackend extends ChimeBackend {
  _ProcessBackend();

  static const _linux = [
    ['paplay'],
    ['pw-play'],
    ['aplay', '-q'],
    ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet'],
  ];
  static const _macos = [
    ['afplay'],
  ];

  List<String>? _player;
  int _seq = 0;

  @override
  Future<void> play(Uint8List wav) async {
    // Rotating files: a chime may still be read while the next one is written.
    final path = p.join(Directory.systemTemp.path, 'pepoconnect-chime-${_seq++ % 3}.wav');
    await File(path).writeAsBytes(wav, flush: true);
    final known = _player;
    if (known != null) {
      await _start(known, path);
      return;
    }
    for (final candidate in Platform.isMacOS ? _macos : _linux) {
      final process = await _start(candidate, path);
      if (process == null) continue;
      // The first run has to prove the player works (server up, no error).
      final code = await process.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => 0);
      if (code == 0) {
        _player = candidate;
        return;
      }
    }
  }

  Future<Process?> _start(List<String> command, String path) async {
    try {
      final process = await Process.start(command.first, [...command.skip(1), path]);
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      return process;
    } on ProcessException {
      return null;
    }
  }
}
