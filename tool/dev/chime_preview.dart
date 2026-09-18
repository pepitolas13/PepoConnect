// Renders a few variations of the transfer chime to build/chime/*.wav and,
// on Windows, plays them one after another.
//
//   dart run tool/dev/chime_preview.dart [count]
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:pepoconnect/platform/chime_synth.dart';

void main(List<String> args) {
  final count = args.isEmpty ? 5 : int.parse(args.first);
  final dir = Directory('build/chime')..createSync(recursive: true);
  const synth = ChimeSynth();
  final random = Random();
  for (var i = 1; i <= count; i++) {
    final seed = random.nextInt(1 << 32);
    final wav = synth.render(Random(seed));
    final file = File('${dir.path}/chime-$i.wav')..writeAsBytesSync(wav);
    stdout.writeln('${file.path}  (seed $seed, ${wav.length} bytes)');
    if (Platform.isWindows) _playWindows(wav);
  }
}

void _playWindows(List<int> wav) {
  final playSound = DynamicLibrary.open('winmm.dll')
      .lookupFunction<
        Int32 Function(Pointer<Uint8>, IntPtr, Uint32),
        int Function(Pointer<Uint8>, int, int)
      >('PlaySoundW');
  final buffer = calloc<Uint8>(wav.length);
  buffer.asTypedList(wav.length).setAll(0, wav);
  const sndSync = 0x0000;
  const sndNoDefault = 0x0002;
  const sndMemory = 0x0004;
  final ok = playSound(buffer, 0, sndMemory | sndSync | sndNoDefault);
  calloc.free(buffer);
  if (ok == 0) stderr.writeln('PlaySound failed');
  sleep(const Duration(milliseconds: 400));
}
