import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/platform/chime_synth.dart';
import 'package:pepoconnect/platform/transfer_chime.dart';

void main() {
  const synth = ChimeSynth();

  Int16List pcm(Uint8List wav) => Int16List.view(
    wav.buffer,
    ChimeSynth.wavHeaderLength,
    (wav.length - ChimeSynth.wavHeaderLength) ~/ 2,
  );

  test('writes a canonical 16-bit mono WAV', () {
    final wav = synth.render(Random(1));
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(data.getUint16(20, Endian.little), 1); // PCM
    expect(data.getUint16(22, Endian.little), 1); // mono
    expect(data.getUint32(24, Endian.little), 44100);
    expect(data.getUint16(34, Endian.little), 16);
    expect(data.getUint32(40, Endian.little), wav.length - ChimeSynth.wavHeaderLength);
    expect(data.getUint32(4, Endian.little), wav.length - 8);
  });

  test('is short, quiet and ends in silence', () {
    final samples = pcm(synth.render(Random(2)));
    expect(samples.length / 44100, closeTo(0.8, 0.01));
    var peak = 0;
    for (final s in samples) {
      if (s.abs() > peak) peak = s.abs();
    }
    expect(peak, closeTo((0.28 * 32767).round(), 2));
    expect(samples.first.abs(), lessThan(50));
    expect(samples.last, 0);
  });

  test('same seed, same bytes; another seed, a slightly different chime', () {
    final a = synth.render(Random(7));
    expect(synth.render(Random(7)), a);
    final b = synth.render(Random(8));
    expect(b, isNot(equals(a)));
    expect(b.length, a.length);
    // Still the same chime: the overall loudness barely moves.
    double rms(Int16List s) {
      var acc = 0.0;
      for (final v in s) {
        acc += v * v;
      }
      return sqrt(acc / s.length);
    }

    expect(rms(pcm(b)) / rms(pcm(a)), closeTo(1, 0.25));
  });

  group('TransferChime', () {
    test('a burst of finished transfers rings once', () async {
      final backend = _RecordingBackend();
      final chime = TransferChime(backend: backend, random: Random(1));
      for (var i = 0; i < 5; i++) {
        chime.ping();
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(backend.played, hasLength(1));
      chime.dispose();
    });

    test('waits for the other transfers, then keeps chimes apart', () async {
      final backend = _RecordingBackend();
      final chime = TransferChime(backend: backend, random: Random(1));
      var busy = true;
      chime.ping(busy: () => busy);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(backend.played, isEmpty);

      busy = false;
      chime.ping(busy: () => busy);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(backend.played, hasLength(1));

      chime.ping(); // Right after a chime: pushed past the cooldown.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(backend.played, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(backend.played, hasLength(2));
      expect(backend.played[0], isNot(equals(backend.played[1])));
      chime.dispose();
    });
  });
}

class _RecordingBackend extends ChimeBackend {
  final List<Uint8List> played = [];

  @override
  Future<void> play(Uint8List wav) async => played.add(wav);
}
