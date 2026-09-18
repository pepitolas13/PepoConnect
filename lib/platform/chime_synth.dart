import 'dart:math';
import 'dart:typed_data';

/// The PepoConnect chime: a soft wooden tap and two glassy bell notes a fifth
/// apart (A5 → E6), about 0.8 s long. Pure Dart, no Flutter.
///
/// Every render nudges the overtones a little (partial levels, the inharmonic
/// sparkle, decay, tuning by a few cents, spacing of the notes, vibrato), so
/// the chime is always recognisably the same but never quite identical.
class ChimeSynth {
  const ChimeSynth({this.sampleRate = defaultSampleRate, this.peak = 0.28});

  static const defaultSampleRate = 44100;

  /// Bytes before the PCM data in the WAVs this class writes.
  static const wavHeaderLength = 44;

  final int sampleRate;

  /// Peak amplitude after normalisation, 0..1. 0.28 is about -11 dBFS: quiet,
  /// but clearly audible at a normal system volume.
  final double peak;

  static const _length = 0.8; // seconds
  static const _fadeOut = 0.04;

  /// 16-bit mono PCM WAV. The same [random] sequence gives identical bytes.
  Uint8List render(Random random) => encodeWav(samples(random), sampleRate);

  /// The waveform, -1..1.
  Float64List samples(Random random) {
    final n = (_length * sampleRate).round();
    final out = Float64List(n);

    // The whole chime drifts by up to ±6 cents; the interval stays a fifth.
    final tune = pow(2.0, _spread(random, 6) / 1200).toDouble();
    final gap = 0.105 * _jitter(random, 0.08);

    _tap(out, random, level: 0.30 * _jitter(random, 0.3));
    _bell(out, random, freq: 880.0 * tune, start: 0, tau: 0.11 * _jitter(random, 0.12), level: 0.8);
    _bell(
      out,
      random,
      freq: 1318.51 * tune,
      start: gap,
      tau: 0.28 * _jitter(random, 0.12),
      level: 1.0,
      vibrato: 0.0025 * _jitter(random, 0.4),
    );

    final fade = (_fadeOut * sampleRate).round();
    for (var i = 0; i < fade; i++) {
      out[n - 1 - i] *= 0.5 - 0.5 * cos(pi * i / fade);
    }
    var max = 0.0;
    for (final v in out) {
      if (v.abs() > max) max = v.abs();
    }
    if (max > 0) {
      final gain = peak / max;
      for (var i = 0; i < n; i++) {
        out[i] *= gain;
      }
    }
    return out;
  }

  /// -[spread]..+[spread].
  static double _spread(Random random, double spread) => (random.nextDouble() * 2 - 1) * spread;

  /// 1 ± [spread].
  static double _jitter(Random random, double spread) => 1 + _spread(random, spread);

  static double _attack(double t, double length) =>
      t >= length ? 1 : 0.5 - 0.5 * cos(pi * t / length);

  /// A short downward sweep: the "wood" under the first note.
  void _tap(Float64List out, Random random, {required double level}) {
    final from = 520.0 * _jitter(random, 0.1);
    const to = 160.0;
    final n = min(out.length, (0.09 * sampleRate).round());
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final f = to + (from - to) * exp(-t / 0.012);
      phase += 2 * pi * f / sampleRate;
      out[i] += level * _attack(t, 0.0015) * exp(-t / 0.011) * sin(phase);
    }
  }

  /// One bell note: harmonics, a sub tone and an inharmonic sparkle, each with
  /// its own decay.
  void _bell(
    Float64List out,
    Random random, {
    required double freq,
    required double start,
    required double tau,
    required double level,
    double vibrato = 0,
  }) {
    // [frequency ratio, level, decay relative to tau]
    final partials = <List<double>>[
      [1.0, 1.0, 1.0],
      [2.0, 0.30 * _jitter(random, 0.25), 0.55],
      [3.0, 0.11 * _jitter(random, 0.30), 0.40],
      [0.5, 0.09 * _jitter(random, 0.40), 0.85], // the sub tone under the note
      [5.4 * _jitter(random, 0.06), 0.045 * _jitter(random, 0.5), 0.22], // sparkle
    ];
    final phases = [for (var i = 0; i < partials.length; i++) random.nextDouble() * 2 * pi];
    final first = (start * sampleRate).round();
    final step = 2 * pi / sampleRate;
    for (var i = first; i < out.length; i++) {
      final t = (i - first) / sampleRate;
      final vib = vibrato == 0 ? 1.0 : 1 + vibrato * sin(2 * pi * 5.5 * t);
      var v = 0.0;
      for (var k = 0; k < partials.length; k++) {
        final p = partials[k];
        phases[k] += step * freq * p[0] * vib;
        v += p[1] * exp(-t / (tau * p[2])) * sin(phases[k]);
      }
      out[i] += level * _attack(t, 0.003) * v;
    }
  }

  /// Canonical 44-byte header followed by 16-bit little-endian mono samples.
  static Uint8List encodeWav(Float64List samples, int sampleRate) {
    final dataLength = samples.length * 2;
    final bytes = ByteData(wavHeaderLength + dataLength);
    void tag(int offset, String s) {
      for (var i = 0; i < 4; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);
    var o = wavHeaderLength;
    for (final v in samples) {
      bytes.setInt16(o, (v.clamp(-1.0, 1.0) * 32767).round(), Endian.little);
      o += 2;
    }
    return bytes.buffer.asUint8List();
  }
}
