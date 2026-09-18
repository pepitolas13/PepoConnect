# Empaquetado de PepoConnect

Cómo se generan los binarios de cada plataforma y qué configuración nativa hay detrás.
La versión sale siempre de `pubspec.yaml` (`version: X.Y.Z+N`); `tool/release.ps1` la sube,
etiqueta `vX.Y.Z` y dispara `.github/workflows/release.yml`, que ejecuta lo mismo que se
describe aquí.

## Windows

### Lanzador de un solo `.exe` (`windows-launcher/`)

`dist\PepoConnect-win-x64.exe` es un stub en Rust que lleva dentro el bundle completo de
`flutter build windows --release` (comprimido con zstd nivel 19 en un `tar.zst`). Al arrancar:

1. Elige la raíz de instalación:
   - `%LOCALAPPDATA%\PepoConnect\` (por defecto). La app queda siempre en `...\PepoConnect\app\`,
     una ruta estable entre versiones (las reglas del firewall y los accesos directos siguen valiendo).
   - **Modo portable**: si existe un fichero `portable.txt` junto al `.exe`, la raíz es la carpeta
     del `.exe` (`app\` y `data\` al lado del ejecutable).
2. Compara `app\.bundle-id` con el id incrustado en el `.exe` (`<version pubspec>-<16 hex de BLAKE3
   del archivo>`). Si no coincide o falta `pepoconnect.exe`:
   - extrae a `app.staging-<pid>`, escribe `.bundle-id`,
   - renombra `app` → `app.old` y `app.staging-<pid>` → `app`, y borra `app.old` (si no puede,
     lo intentará en el siguiente arranque).
   - Si la versión anterior sigue abierta (su `.exe` está bloqueado o la carpeta no se puede
     renombrar) muestra *"PepoConnect ya está abierto. Ciérralo y vuelve a abrir el nuevo."* y sale.
3. Lanza `app\pepoconnect.exe` con los mismos argumentos, `current_dir = app\` y estas variables:
   - `PEPOCONNECT_LAUNCHER` = ruta del stub que lo lanzó.
   - `PEPOCONNECT_DATA_DIR` = `<carpeta del exe>\data` (solo en modo portable).

   El stub no espera al hijo. Cualquier error acaba en un `MessageBox` en español y código de salida 1.

Compilación:

```powershell
flutter build windows --release            # genera build\windows\x64\runner\Release
.\packaging\windows\build-portable.ps1     # -> dist\PepoConnect-win-x64.exe y dist\PepoConnect-win-x64-portable.zip
```

`build-portable.ps1` encadena: comprobar el bundle → `prepare-bundle.ps1` (copia `msvcp140.dll`,
`vcruntime140.dll` y `vcruntime140_1.dll` desde el redistribuible VC143 que encuentra con `vswhere`
o `VCToolsRedistDir`) → `cargo build --release` → copia del `.exe` → `Compress-Archive` del bundle.
Parámetros: `-Bundle <dir>` (o `$env:PEPO_BUNDLE_DIR`), `-OutDir <dir>`, `-SkipVcRedist`.

A mano:

```powershell
.\packaging\windows\prepare-bundle.ps1
$env:PEPO_BUNDLE_DIR = 'C:\PepoConnect\build\windows\x64\runner\Release'   # opcional, es el valor por defecto
cargo build --release --manifest-path windows-launcher\Cargo.toml
# -> windows-launcher\target\release\PepoConnect.exe
```

Detalles del crate:

- `build.rs` empaqueta el bundle en `$OUT_DIR/bundle.tar.zst`, calcula el BLAKE3, emite
  `PEPO_BUNDLE_ID` y estampa icono (`windows/runner/resources/app_icon.ico`) y VERSIONINFO
  (ProductName/FileDescription `PepoConnect`, CompanyName `PepoTech`, FileVersion `X.Y.Z.N`) con
  `winresource`. Si el bundle no existe, **falla** con un mensaje claro
  (`run flutter build windows --release first or set PEPO_BUNDLE_DIR`).
- Se vuelve a empaquetar solo cuando cambia algo del bundle, `pubspec.yaml`, el icono o
  `PEPO_BUNDLE_DIR` (`rerun-if-changed` / `rerun-if-env-changed`).
- Requisitos: Rust stable con toolchain MSVC, Build Tools de C++ (zstd compila su C) y el
  Windows SDK (`rc.exe` para los recursos). `target/` está en `.gitignore`.
- Perfil release: `opt-level=3`, `lto="fat"`, `codegen-units=1`, `panic="abort"`, `strip=true`.
- Prueba rápida sin Flutter: cualquier carpeta con un `pepoconnect.exe` y `data\flutter_assets\`
  sirve como bundle (`$env:PEPO_BUNDLE_DIR = ...`); para probar el `.exe` sin tocar tu perfil,
  apunta `$env:LOCALAPPDATA` a una carpeta temporal.

### Zip portable

`dist\PepoConnect-win-x64-portable.zip` es el bundle tal cual (con las DLL del runtime VC++):
se descomprime y se ejecuta `pepoconnect.exe` en el sitio. Para tener el lanzador de un solo
fichero en modo portable, deja `PepoConnect-win-x64.exe` en una carpeta con un `portable.txt`
vacío al lado.

### Runner de Flutter (`windows/runner`)

- `Runner.rc`: ProductName/FileDescription `PepoConnect`, CompanyName `PepoTech`; la versión viene
  de `pubspec.yaml` a través de CMake.
- `runner.exe.manifest`: `dpiAwareness PerMonitorV2` + `longPathAware`.
- `main.cpp`: título de ventana `PepoConnect`, tamaño inicial 1100x700.

## Android

- `applicationId`/`namespace`: `org.pepoconnect.app`. `minSdk 29`, `targetSdk 36`, `compileSdk 36`,
  Java 17, `ndkVersion = flutter.ndkVersion`.
- **Firma**: `android/key.properties` (ignorado por git; plantilla en `android/key.properties.example`):
  `storeFile` (absoluto o relativo a `android/app`), `storePassword`, `keyAlias`, `keyPassword`.
  Si no existe, la release se firma con la clave de debug y Gradle avisa. En CI se genera desde los
  secretos `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` y `ANDROID_KEY_ALIAS`.
- **R8**: `isMinifyEnabled` + `isShrinkResources` con `proguard-android-optimize.txt` y
  `android/app/proguard-rules.pro` (Flutter, `flutter_foreground_task`, `photo_manager`/Glide,
  `mobile_scanner`/ML Kit, Gson de `flutter_local_notifications`, `share_handler` y nuestro puente).
- `flutter_local_notifications` exige *core library desugaring* (`desugar_jdk_libs 2.1.4`); por eso
  también se añade `androidx.window:window(-java) 1.0.0`, que su README recomienda.
- **Manifest** (`android/app/src/main/AndroidManifest.xml`):
  - permisos: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE,
    WAKE_LOCK, CAMERA, POST_NOTIFICATIONS, FOREGROUND_SERVICE,
    FOREGROUND_SERVICE_CONNECTED_DEVICE, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
    READ_EXTERNAL_STORAGE (maxSdk 32), READ_MEDIA_IMAGES, READ_MEDIA_VIDEO,
    READ_MEDIA_VISUAL_USER_SELECTED, ACCESS_MEDIA_LOCATION;
  - servicio de `flutter_foreground_task` (`com.pravera.flutter_foreground_task.service.ForegroundService`,
    `foregroundServiceType="connectedDevice"`, `exported=false`, `stopWithTask=false`). Al iniciar el
    servicio desde Dart, usa el tipo `connectedDevice`;
  - `MainActivity` con `launchMode="singleTask"` (recomendado por `share_handler` para que compartir
    no abra una segunda instancia), deep link `pepoconnect://pair` (VIEW + BROWSABLE) y filtros
    SEND / SEND_MULTIPLE para `image/*`, `video/*` y `*/*`.
- **Puente nativo** `org.pepoconnect/native` (`PepoNative.kt`, registrado en `MainActivity`):

  | Método | Argumentos | Devuelve |
  |---|---|---|
  | `acquireMulticastLock` | — | `bool` (lock mDNS activo) |
  | `releaseMulticastLock` | — | `null` |
  | `requestIgnoreBatteryOptimizations` | — | `bool` (ya exento o diálogo abierto) |
  | `isIgnoringBatteryOptimizations` | — | `bool` |
  | `saveToDownloads` | `path`, `name?`, `mime?` | `String` URI `content://` en `Downloads/PepoConnect` |
  | `openAppSettings` | — | `bool` |

  Los errores llegan como `PlatformException` (`bad_args`, `save_failed`, `native_error`, `no_context`).
  `saveToDownloads` copia en un hilo de fondo y responde en el hilo principal.

  ```dart
  const native = MethodChannel('org.pepoconnect/native');
  await native.invokeMethod<bool>('acquireMulticastLock');
  final uri = await native.invokeMethod<String>('saveToDownloads',
      {'path': file.path, 'name': 'foto.jpg', 'mime': 'image/jpeg'});
  ```

- Gradle: `-Xmx4G`, `org.gradle.caching=true`, `org.gradle.parallel=true`.

## iOS

- Bundle id `org.pepoconnect.app` (tests: `org.pepoconnect.app.RunnerTests`), iOS 15.0 mínimo.
  El proyecto usa Swift Package Manager para los plugins (no hay `Podfile`).
- `ios/Runner/Info.plist`: `CFBundleDisplayName` PepoConnect, textos de uso de fototeca (leer y
  guardar), cámara y red local, `NSBonjourServices` (`_pepoconnect._tcp`), `UIBackgroundModes`
  (`processing`), `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`,
  `ITSAppUsesNonExemptEncryption=false` y el esquema de URL `pepoconnect`.
- `ios/ExportOptions.plist`: exportación ad-hoc con firma manual; `packaging/ios/sign-and-export.sh`
  sustituye `TEAM_ID` y `PROFILE_NAME` con los secretos `IOS_TEAM_ID` y el nombre del perfil, y
  ejecuta `flutter build ipa --export-options-plist=ios/ExportOptions.plist`.
- Pendiente (requiere Xcode): la Share Extension de `share_handler` (target `ShareExtension`,
  App Group y esquema `ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)`) y, si se usa
  `flutter_foreground_task` en iOS, `UIBackgroundModes: fetch` +
  `BGTaskSchedulerPermittedIdentifiers` (`com.pravera.flutter_foreground_task.refresh`).

## Linux

- `linux/CMakeLists.txt`: binario `pepoconnect`, `APPLICATION_ID org.pepoconnect.PepoConnect`
  (coincide con el `.desktop`, el metainfo y el id de Flatpak).
- `linux/runner/my_application.cc`: título `PepoConnect`, tamaño por defecto 1100x700.
- Scripts en `packaging/linux/`: `make-tarball.sh`, `make-appimage.sh`, `make-flatpak.sh`,
  `bundle-extra-libs.sh` (indicador de bandeja y libnotify), `install-desktop-entry.sh`.
- Iconos: `flutter_launcher_icons` no soporta Linux. Los scripts copian a mano
  `assets/icon/pepoconnect-256.png` y `assets/icon/pepoconnect-512.png` como
  `org.pepoconnect.PepoConnect.png`; genera esos dos PNG junto con el resto.

## Iconos

`flutter_launcher_icons.yaml` genera Android (legacy + adaptativo con fondo `#0A3D8F` y
monocromo), iOS (sin alfa, fondo `#0A3D8F`) y Windows (`app_icon.ico` de 256 px, que también
usa el lanzador) a partir de:

- `assets/icon/icon-1024.png` — icono completo 1024x1024.
- `assets/icon/icon-foreground.png` — capa frontal del adaptativo (transparente, zona segura central).
- `assets/icon/icon-mono.png` — icono temático monocromo (Android 13+).

```powershell
dart run flutter_launcher_icons
```

Linux: copiar a mano `assets/icon/pepoconnect-256.png` y `pepoconnect-512.png` (ver arriba).

## Motor rápido (Rust) en cada plataforma

`packages/pepo_native/rust` se compila durante `flutter build`; hace falta `rustup` en la máquina
(los targets se instalan solos):

- Windows y Linux: `windows/CMakeLists.txt` y `linux/CMakeLists.txt` del plugin llaman a cargokit
  (`packages/pepo_native/cargokit`), que deja `pepo_native.dll` / `libpepo_native.so` en el bundle.
- iOS: el podspec compila una biblioteca estática con cargokit y la enlaza con `-force_load`;
  Dart la encuentra con `DynamicLibrary.process()`.
- Android: `packages/pepo_native/android/build.gradle` compila con cargo para cada ABI pedida
  (`-Ptarget-platform`) usando el clang del NDK que declara Flutter y copia los `.so` como jniLibs
  (alineados a 16 KB). El plugin Gradle de cargokit no sirve porque usa `libraryVariants`,
  eliminado en AGP 9.
