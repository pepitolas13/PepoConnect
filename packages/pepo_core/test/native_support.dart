import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pepo_core/src/native/native_bulk.dart';

/// Where the fast lane library is for tests: `PEPO_NATIVE_LIB`, else the
/// cargo release output of `packages/pepo_native/rust`. Null when missing.
String? nativeLibraryPath() {
  final env = Platform.environment[nativeBulkLibraryEnv];
  if (env != null && env.isNotEmpty && File(env).existsSync()) return env;
  final name = Platform.isWindows
      ? 'pepo_native.dll'
      : Platform.isMacOS
      ? 'libpepo_native.dylib'
      : 'libpepo_native.so';
  final candidate = p.normalize(
    p.join(Directory.current.path, '..', 'pepo_native', 'rust', 'target', 'release', name),
  );
  return File(candidate).existsSync() ? candidate : null;
}
