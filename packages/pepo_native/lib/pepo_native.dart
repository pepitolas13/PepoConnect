/// Build-only plugin: it makes the Flutter build compile `rust/` and bundle
/// `pepo_native` next to the app on every platform. The Dart bindings live
/// in `pepo_core` (`NativeBulk`), which loads the library by name.
library;

/// Library name as built by Cargo (`pepo_native.dll`, `libpepo_native.so`,
/// linked statically on iOS).
const String pepoNativeLibraryName = 'pepo_native';
