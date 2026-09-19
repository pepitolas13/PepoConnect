# Empaquetado de PepoConnect

Cómo se generan los binarios de cada plataforma y qué configuración nativa hay detrás.
La versión sale siempre de `pubspec.yaml` (`version: X.Y.Z+N`); `tool/release.ps1` la sube,
etiqueta `vX.Y.Z` y dispara `.github/workflows/release.yml`, que ejecuta lo mismo que se
describe aquí.

## Actualizaciones desde la app

El estado de actualizaciones es único para toda la app: cambiar de pantalla no
interrumpe una descarga. Se consulta la última versión estable de GitHub cada
24 horas mientras el proceso está en marcha, y al recuperar el primer plano si
la comprobación ya toca. Una comprobación fallida se reintenta después de una
hora; los fallos automáticos no abren ventanas. El resultado, las fechas y la
última versión ofrecida se guardan bajo `pepo.updates`, separado de los ajustes.
El interruptor `updateNotifications` controla solo el aviso; se puede seguir
comprobando e instalando manualmente en Acerca de.

La selección del paquete depende de la arquitectura del proceso y del formato
instalado. Solo se aceptan metadatos de versiones estables, enlaces HTTPS del
repositorio y archivos de esa misma versión. Primero se descarga a una carpeta
privada, se comprueba el tamaño y se valida contra `SHA256SUMS.txt`; una descarga
incompleta, cancelada o con un hash distinto no modifica la instalación.

| Distribución | Proceso |
|---|---|
| Windows, lanzador `.exe` | Sustitución del lanzador y del bundle, reinicio y conservación de sus rutas y datos. |
| Windows, ZIP | Preparación del bundle nuevo, sustitución al salir y reinicio. |
| Linux, AppImage | Sustitución de la imagen original y reinicio. |
| Linux, tarball | Preparación del bundle nuevo en su instalación y reinicio. |
| Linux, Flatpak | Descarga verificada y apertura del gestor de software del sistema. No se conceden permisos para salir del sandbox. |
| Android, APK | Descarga para la ABI del proceso y confirmación mediante el instalador de Android. Si falta autorización para instalar, se abre el ajuste del sistema y se continúa al volver. |
| iOS, IPA sin firmar | Aviso e instrucciones para reinstalar con AltStore/Sideloadly y la misma cuenta. No hay auto-instalación de IPA sin firmar. |

Antes de reiniciar se vuelve a comprobar que no haya transferencias activas ni
enlaces de invitado abiertos. El reemplazo de escritorio usa un ayudante que
espera a la salida del proceso. Conserva una copia de recuperación y comprueba
que la nueva app llegue a iniciar sus servicios; si no lo logra, restaura la
versión anterior. Los permisos de una carpeta protegida pueden impedir la
actualización: se informa del fallo sin solicitar elevación automáticamente.

El reemplazo es atómico por archivo. Un corte de energía durante un bundle con
varios archivos no equivale a una transacción atómica de todo el directorio:
se conserva el registro y la copia anterior en `.pepoconnect-update-*`, junto a
la instalación. Con la app completamente cerrada, se puede recuperar ejecutando
`install.ps1 -Config plan.json -Recover` en Windows (ambas rutas deben apuntar a
esa carpeta) o `sh install.sh --recover` en Linux. El archivo `result` distingue
`installed`, `rolledBack` y `recoveryRequired`; no se debe borrar la carpeta si
queda pendiente una recuperación. Repetir la recuperación de una operación ya
completada no revierte la versión instalada.

El lanzador de Windows también restaura automáticamente una carpeta `app.old*`
completa si un cierre interrumpió el intercambio y falta `app`. Conserva los
directorios anteriores como copias de recuperación, incluidos archivos ajenos
al paquete. Ocupan espacio; se pueden retirar manualmente después de comprobar
que la nueva versión y los datos funcionan. No se borran anticipadamente durante
el siguiente arranque.

La publicación debe producir todos los paquetes admitidos y sus checksums antes
de anunciar una nueva versión. Las etiquetas publicadas exigen los secretos
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` y `ANDROID_KEY_ALIAS`:
cambiar la clave de firma impide actualizar los APK anteriores conservando sus
datos. Las compilaciones de prueba locales pueden seguir usando la firma de
debug. El APK instalado debe tener el mismo identificador y una firma compatible,
y el número de compilación de la actualización debe ser mayor.

Una versión antigua que solo abre GitHub necesita instalar una vez la versión
que introduce este actualizador. A partir de esa versión, las siguientes
actualizaciones usan este flujo. No se ejecuta un servicio nuevo exclusivamente
para buscar versiones cuando la app está completamente cerrada.

El canal de distribución tiene que admitir consultas y descargas sin iniciar
sesión. Los clientes no incluyen credenciales de GitHub: un repositorio privado
devuelve 404 tanto para la API de versiones como para sus archivos. Antes de
distribuir una versión con el actualizador, hay que hacer accesible ese canal
o configurar una distribución pública separada; no basta con que el propietario
pueda descargar los archivos desde su navegador con sesión iniciada.

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
- Tras instalar un bundle nuevo llama a `SHChangeNotify(SHCNE_ASSOCCHANGED)`: la ruta de
  `app\pepoconnect.exe` no cambia entre versiones y el Explorador cachea los iconos por ruta sin
  volver a mirar el fichero, así que sin ese aviso la barra de tareas y el menú Inicio seguirían
  con el icono de la versión anterior (ver "Iconos").
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
  `android/app/proguard-rules.pro` (Flutter, `photo_manager`/Glide, `mobile_scanner`/ML Kit, Gson de
  `flutter_local_notifications`, `share_handler` y nuestras clases nativas: puente, servicio y receptor).
- `flutter_local_notifications` exige *core library desugaring* (`desugar_jdk_libs 2.1.4`); por eso
  también se añade `androidx.window:window(-java) 1.0.0`, que su README recomienda.
- **Manifest** (`android/app/src/main/AndroidManifest.xml`):
  - permisos: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE,
    WAKE_LOCK, CAMERA, POST_NOTIFICATIONS, FOREGROUND_SERVICE,
    FOREGROUND_SERVICE_CONNECTED_DEVICE, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, RECEIVE_BOOT_COMPLETED,
    READ_EXTERNAL_STORAGE (maxSdk 32), READ_MEDIA_IMAGES, READ_MEDIA_VIDEO,
    READ_MEDIA_VISUAL_USER_SELECTED, ACCESS_MEDIA_LOCATION;
  - `PepoForegroundService` (`foregroundServiceType="connectedDevice"`, `exported=false`,
    `stopWithTask=false`): mantiene vivo el proceso con la app cerrada (notificación persistente,
    wake lock, Wi-Fi lock y multicast lock) y, si Android lo reinicia (START_STICKY) o tras un
    reinicio del móvil o una actualización (`BootReceiver`: BOOT_COMPLETED y MY_PACKAGE_REPLACED),
    arranca el motor Flutter sin ventana. El motor es único y cacheado (`PepoEngineHolder`):
    `MainActivity` se engancha a él y lo suelta sin destruirlo mientras el servicio esté en marcha;
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
  (`audio`, `fetch`, `processing`), `BGTaskSchedulerPermittedIdentifiers`
  (`org.pepoconnect.app.refresh`, `org.pepoconnect.app.sync`), `UIFileSharingEnabled`,
  `LSSupportsOpeningDocumentsInPlace`, `ITSAppUsesNonExemptEncryption=false` y el esquema de URL
  `pepoconnect`. Ninguna de esas claves necesita entitlements, así que sobreviven a la refirma de
  AltStore o Sideloadly con un Apple ID gratuito. El job `ios` de `ci.yml` comprueba que siguen en
  el bundle compilado.
- Segundo plano (`ios/Runner/PepoBackground.swift`): iOS no despierta una app suspendida al hacer
  una foto —`PHPhotoLibraryChangeObserver` solo entrega a un proceso vivo y las `BGTask` son
  oportunistas—, así que `KeepAlive` reproduce un bucle de silencio con la sesión de audio en
  `.playback` + `.mixWithOthers` para que el proceso no llegue a suspenderse. `BackgroundHold`
  envuelve las transferencias en un `beginBackgroundTask` y `BackgroundTasks` registra las dos
  `BGTask` como red de seguridad. Todo se controla desde Dart por el canal `org.pepoconnect/native`
  (`keepAliveStart`, `keepAliveStop`, `backgroundHold`, `backgroundStatus`, `backgroundReady`,
  `backgroundTaskDone`, y `backgroundTask` en sentido contrario).
- `ios/ExportOptions.plist`: exportación ad-hoc con firma manual; `packaging/ios/sign-and-export.sh`
  sustituye `TEAM_ID` y `PROFILE_NAME` con los secretos `IOS_TEAM_ID` y el nombre del perfil, y
  ejecuta `flutter build ipa --export-options-plist=ios/ExportOptions.plist`.
- Pendiente (requiere Xcode): la Share Extension de `share_handler` (target `ShareExtension`,
  App Group y esquema `ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)`).

## Linux

- `linux/CMakeLists.txt`: binario `pepoconnect`, `APPLICATION_ID org.pepoconnect.PepoConnect`
  (coincide con el `.desktop`, el metainfo y el id de Flatpak).
- `linux/runner/my_application.cc`: título `PepoConnect`, tamaño por defecto 1100x700.
- Scripts en `packaging/linux/`: `make-tarball.sh`, `make-appimage.sh`, `make-flatpak.sh`,
  `bundle-extra-libs.sh` (indicador de bandeja y libnotify), `install-desktop-entry.sh`.
- Descubrimiento mDNS: `bonsoir_linux` habla con Avahi por el bus **de sistema**, así que el
  manifiesto Flatpak lleva `--system-talk-name=org.freedesktop.Avahi`. Sin `avahi-daemon` no hay
  anuncio ni exploración y queda solo el beacon UDP, que en Linux sigue activo; el iPhone, que no
  puede usar UDP, dejaría de encontrar ese equipo.
- Iconos: `flutter_launcher_icons` no soporta Linux. Los scripts copian a mano
  `assets/icon/pepoconnect-256.png` y `assets/icon/pepoconnect-512.png` como
  `org.pepoconnect.PepoConnect.png`; genera esos dos PNG junto con el resto.

## Iconos

Todo sale de la misma geometría (`assets/brand/pepoconnect.svg`) en dos pasos:

```powershell
python tool/brand/render_icons.py      # Pillow; PNG fuente, .ico de Windows, icono de estado Android
dart run flutter_launcher_icons        # Android (launcher) e iOS a partir de esos PNG
```

`render_icons.py` escribe:

- `assets/icon/icon-1024.png` — icono completo 1024x1024 (fuente de iOS y del legacy Android).
- `assets/icon/icon-foreground.png` — capa frontal del adaptativo (transparente, zona segura central).
- `assets/icon/icon-mono.png` — icono temático monocromo (Android 13+).
- `assets/icon/pepoconnect-256.png` y `-512.png` — Linux (bandeja y paquetes, ver arriba).
- `assets/icon/favicon.ico` — bandeja de Windows (`tray_manager`).
- `windows/runner/resources/app_icon.ico` — icono de `pepoconnect.exe` (barra de título, barra de
  tareas, Explorador) y del lanzador. Entradas DIB de 16 a 128 px y PNG solo a 256 px, que es el
  formato que esperan `LoadIcon`/`LoadImage` y el shell; por eso `windows.generate: false` en
  `flutter_launcher_icons.yaml` (escribiría un .ico todo PNG).
- `android/app/src/main/res/drawable-*/ic_stat_pepoconnect.png` — icono de la barra de estado
  (24 dp, glifo blanco sobre transparente: Android solo usa el alfa). Lo usan las notificaciones
  de `flutter_local_notifications` (`AndroidInitializationSettings` + `icon`) y la notificación de
  `PepoForegroundService` (`R.drawable.ic_stat_pepoconnect`). Sin él
  Android aplana el launcher a un cuadrado blanco. `res/raw/keep.xml` lo protege del
  `shrinkResources` porque Dart lo busca por nombre.

`flutter_launcher_icons` genera Android (legacy + adaptativo con fondo `#0A3D8F` y monocromo) e
iOS (sin alfa, fondo `#0A3D8F`). Ojo: la versión 0.14.4 también toca
`ios/Runner.xcodeproj/project.pbxproj` y deja `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon`
(valor inválido; `ASSETCATALOG_COMPILER_APPICON_NAME` ya es `AppIcon`): revierte ese fichero.

Ventana Windows: además del icono de clase (grande y pequeño), `win32_window.cpp` envía
`WM_SETICON` al DPI del monitor y de nuevo en `WM_DPICHANGED`, de modo que la ventana responde a
`WM_GETICON` con el icono correcto. Aun así, cuando el proceso tiene AppUserModelID (lo fija
`local_notifier` para los toasts) la barra de tareas resuelve el icono por la ruta del exe a
través de la caché del Explorador, que no se invalida al sustituir el fichero. Por eso el
lanzador vacía esa caché tras cada actualización (`SHChangeNotify(SHCNE_ASSOCCHANGED)`). En una
build de desarrollo ejecutada desde `build\windows\...` no pasa por el lanzador: si la barra
enseña el icono antiguo, `ie4uinit.exe -show` o reiniciar `explorer.exe`.

Ventana Linux: `my_application.cc` usa el icono del tema `org.pepoconnect.PepoConnect` cuando
está instalado (tarball + `install-desktop-entry.sh`, AppImage, Flatpak) y, si no, el PNG de
`data/flutter_assets/assets/icon/` junto al binario (bundle ejecutado en sitio).

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
