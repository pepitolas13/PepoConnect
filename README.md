# PepoConnect

Fotos y archivos entre el móvil y el PC, al instante. Es la parte de archivos de
Intel Unison hecha de nuevo: haces una foto con el móvil, aparece en el PC en
menos de dos segundos, la previsualizas y decides si descargarla o no. Todo por
la red local, cifrado, sin cuentas y sin instalador.

Plataformas: Windows (`.exe` portable), Linux x64 y arm64 (tarball, AppImage y
Flatpak para móviles Linux), Android (`.apk`) e iOS (`.ipa`).

## Capturas

| Galería del móvil en el PC | Transferencias |
|---|---|
| ![Galería](docs/screenshots/galeria.png) | ![Transferencias](docs/screenshots/transferencias.png) |

| Tema oscuro, fotos recién llegadas | Emparejar por QR | Ancho de móvil |
|---|---|---|
| ![Galería en oscuro](docs/screenshots/galeria-oscuro.png) | ![Emparejar](docs/screenshots/emparejar.png) | ![Móvil](docs/screenshots/movil-galeria.png) |

Las capturas las genera `flutter test integration_test/screenshots_test.dart -d windows`
a partir de la app real.

## Qué hace

- **Galería del móvil en el PC** con miniaturas, previsualización a 1600 px y
  descarga del original con sus metadatos. Las fotos nuevas aparecen arriba con
  un aviso y un toast con "Ver" y "Descargar" (una ráfaga de fotos se agrupa en
  un solo aviso); "Seleccionar nuevas" (Ctrl+Mayús+N) las deja listas para
  descargarlas de golpe.
- **Transferencias en los dos sentidos**: arrastra archivos a la zona del
  dispositivo o elige "Añadir archivos…"; desde el móvil, el botón de enviar o
  "Compartir con PepoConnect". Reanudación tras cortes, verificación de
  integridad y varios archivos en paralelo.
- **Varios móviles a la vez** en el mismo PC, con lo recibido separado por
  dispositivo (`Fotos/`, `Vídeos/`, `Archivos/`) o unificado desde Ajustes.
- **Emparejamiento por QR** (móvil) o por código de 6 dígitos (PC↔PC), con
  reconexión automática.
- Extras: auto-descarga de fotos nuevas, conversión HEIC→JPEG en el móvil, modo
  sesión de fotos, portapapeles compartido y **envío por navegador** a
  cualquiera sin la app (enlace de un solo uso).

## Motor rápido (Rust)

Los archivos van por un carril aparte escrito en Rust (`packages/pepo_native`):
una conexión TCP por archivo, cifrada con AES-256-GCM con una clave derivada
del emparejamiento y de la sesión, con xxh3 de integridad, escrita en disco
sin pasar por Dart. En loopback mueve más de 400 MB/s con cifrado en los dos
extremos; en la práctica manda la Wi-Fi o el almacenamiento del móvil. El
canal de control (ofertas, aceptaciones, miniaturas) sigue en TLS.

Se negocia por archivo: si un extremo no tiene el motor (versión antigua,
biblioteca no cargada) o su puerto no es alcanzable, ese archivo va por los
canales TLS de siempre y la app sigue funcionando. En "Acerca de" se ve si el
motor está activo. El crate se compila dentro de `flutter build` en las cinco
plataformas (cargokit en Windows, Linux e iOS; tarea de Gradle en Android), así
que hace falta `rustup` para compilar el proyecto.

## Seguridad

Cada dispositivo genera una clave EC P-256 y un certificado autofirmado. Las
conexiones van por TLS 1.3 con el certificado del otro extremo anclado por
huella, y cada sesión se autentica con una clave compartida derivada durante
el emparejamiento (HKDF/HMAC-SHA256). No hay servidores externos.

## Compilar

Requisitos: Flutter 3.47 (estable), Visual Studio Build Tools con C++ y ATL
(Windows), Android SDK con NDK 28, Java 17, Rust con `rustup` (motor rápido y
lanzador de Windows; los targets de Android e iOS se instalan solos).

```bash
flutter pub get
flutter test                                        # tests de la app
cargo test --release --manifest-path packages/pepo_native/rust/Cargo.toml
cd packages/pepo_core && dart test                  # motor de red, TLS y carril rápido
```

Los tests del carril rápido cargan la biblioteca de `packages/pepo_native/rust/target/release`
(compílala antes con `cargo build --release`) o la que indique `PEPO_NATIVE_LIB`.

Prueba de extremo a extremo real (la app completa y un "móvil" sin interfaz en el
mismo proceso, sobre TLS en loopback: emparejar por QR, foto nueva, descarga,
envíos en los dos sentidos):

```bash
flutter test integration_test/e2e_test.dart -d windows
```

| Plataforma | Comando |
|---|---|
| Windows (`.exe` único) | `flutter build windows --release` y `.\packaging\windows\build-portable.ps1` → `dist\PepoConnect-win-x64.exe` |
| Android | `flutter build apk --release --split-per-abi` (firma con `android/key.properties`, ver `key.properties.example`) |
| Linux | `flutter build linux --release` y `packaging/linux/make-tarball.sh x64`, `make-appimage.sh x64 x86_64`, `make-flatpak.sh x64 x86_64` |
| iOS | `flutter build ios --release --no-codesign` (el `.ipa` sin firmar se genera en CI) |

`.github/workflows/release.yml` compila las cinco plataformas al crear una
etiqueta `vX.Y.Z` (`tool/release.ps1 -Part patch`).

Segunda instancia en el mismo PC para probar: `flutter run -d windows --dart-entrypoint-args=--profile=dev2`.

## Instalar el `.ipa` en iPhone sin cuenta de desarrollador

1. Descarga `PepoConnect-ios-unsigned.ipa` del release.
2. Instálalo con Sideloadly (Windows) o AltStore con tu Apple ID.
3. Con Apple ID gratuito la app caduca cada 7 días (AltServer la renueva
   sola si está en la misma Wi-Fi) y puedes tener 3 apps así a la vez.
4. La primera vez, acepta el permiso de "Red local"; en iPhone las fotos
   llegan al PC mientras PepoConnect está en pantalla.

## Estructura

- `packages/pepo_core`: motor en Dart puro (identidad, protocolo, sesiones,
  transferencias, galería, servidor de invitados). Sin dependencias de Flutter.
- `lib/`: app Flutter (estado con Riverpod, shell Fluent, páginas, plataforma).
- `windows-launcher/`: lanzador Rust que empaqueta la app en un solo `.exe`.
- `packaging/`: scripts de empaquetado por plataforma.
