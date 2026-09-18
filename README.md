# PepoConnect

**Haz una foto con el móvil. Mírala en el ordenador. Descarga solo la que quieres.**

PepoConnect conecta tus dispositivos por la red local para mover fotos, vídeos,
archivos y texto. Sin enviártelos por un chat, sin cuentas y sin subir tus
archivos a una nube. Una alternativa a la parte de fotos y archivos de Intel
Unison, con Windows, Linux, Android e iPhone.

[Descargar la última versión](https://github.com/pepitolas13/PepoConnect/releases/latest) ·
[Novedades de 0.4](https://github.com/pepitolas13/PepoConnect/releases/tag/v0.4.0) ·
[English](README.en.md)

Si te resulta útil, puedes apoyar el proyecto con una **⭐**. Y si algo falla,
[cuéntalo aquí](https://github.com/pepitolas13/PepoConnect/issues/new/choose):
nos ayuda mucho más saber qué ha pasado que quedarnos con la duda.

## Descargar

Instala PepoConnect en los dos dispositivos que quieras conectar.

| Tu dispositivo | Descarga |
|---|---|
| Windows 10/11 de 64 bits | [PepoConnect.exe](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-win-x64.exe) · [ZIP portable](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-win-x64-portable.zip) |
| Android | [APK para móviles actuales](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-android-arm64-v8a.apk) · [APK universal ARM](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-android-universal.apk) |
| Linux x64 | [AppImage](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-x64.AppImage) · [Flatpak](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-x64.flatpak) · [tar.gz](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-x64.tar.gz) |
| Linux ARM64 | [AppImage](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-arm64.AppImage) · [Flatpak](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-arm64.flatpak) · [tar.gz](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-arm64.tar.gz) |
| iPhone | [IPA para instalación manual](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-ios-unsigned.ipa) · [Cómo instalarlo](#instalar-el-ipa-en-iphone-sin-cuenta-de-desarrollador) |

Windows se abre directamente. Android pide permiso para instalar el APK. En
Linux, da permiso de ejecución al AppImage o abre el Flatpak con tu gestor de
software. iPhone requiere AltStore o Sideloadly; no es una descarga del App Store.
Las variantes Android de 32 bits y x86_64 están en la página de la versión.

## Empezar en un minuto

1. Conecta los dos dispositivos a la misma red y abre PepoConnect.
2. Empareja el móvil escaneando el QR del ordenador, o usa el código de seis dígitos.
3. Abre la galería o arrastra un archivo al dispositivo. Los dispositivos que ya
   has emparejado se vuelven a conectar solos.

**Nuevo en 0.4:** puedes actualizar desde Ajustes → Acerca de. La app comprueba
si hay una versión nueva cada día y puedes desactivar los avisos que aparecen
en pantalla. Si vienes de una versión anterior a 0.4, instala esta una vez para
activar el nuevo actualizador.
En Windows y Linux, cierra la versión anterior antes de abrir la nueva descarga.
En Android, instala el APK sobre la app existente para conservar tus datos.

## Capturas

| Galería del móvil en el PC | Transferencias |
|---|---|
| ![Galería](docs/screenshots/galeria.png) | ![Transferencias](docs/screenshots/transferencias.png) |

| Tema oscuro, fotos recién llegadas | Emparejar por QR | Ancho de móvil |
|---|---|---|
| ![Galería en oscuro](docs/screenshots/galeria-oscuro.png) | ![Emparejar](docs/screenshots/emparejar.png) | ![Móvil](docs/screenshots/movil-galeria.png) |

Capturas de la aplicación real.

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
- **Sigue conectado con la app cerrada** (Android): con «Servicio en segundo
  plano» activado, un servicio en primer plano mantiene vivo el motor aunque
  cierres la ventana o la quites de recientes, y lo rearranca solo si Android
  mata el proceso o reinicias el móvil.
- **Portapapeles compartido**: un solo interruptor por pareja de dispositivos
  (se activa en cualquiera de los dos y vale para ambos sentidos). El PC lo
  envía al instante; Android no deja leer el portapapeles en segundo plano,
  así que el móvil lo manda al abrir PepoConnect, con el tile «Enviar
  portapapeles» de los ajustes rápidos, con el acceso directo del icono o con
  "Compartir → PepoConnect".
- Extras: auto-descarga de fotos nuevas, conversión HEIC→JPEG en el móvil, modo
  sesión de fotos y **envío por navegador** a cualquiera sin la app (enlace de
  un solo uso).
- **Actualizaciones desde la app**: comprobación cada 24 horas mientras está
  abierta (también en la bandeja) y al volver a abrirla si toca comprobar.
  «Ajustes → Acerca de → Actualizar» descarga, verifica e instala la nueva
  versión. El aviso aparece una sola vez por versión y se puede desactivar
  en «Ajustes → Notificaciones → Avisos de actualizaciones»; la comprobación
  diaria y el botón siguen funcionando.

Windows y Linux (AppImage/tarball) se reinician para completar la actualización
y conservan el perfil. Android pide la confirmación de su instalador; Flatpak
abre el gestor de software. En iPhone, el `.ipa` sin firmar requiere volver a
instalar con AltStore o Sideloadly usando la misma cuenta: iOS no permite que ese
paquete se sustituya a sí mismo. La app indica el paso correspondiente.

## Motor rápido (Rust)

Los archivos van por un carril aparte escrito en Rust (`packages/pepo_native`):
una conexión TCP por archivo, cifrada con AES-256-GCM con una clave derivada
del emparejamiento y de la sesión, con xxh3 de integridad, escrita en disco
sin pasar por Dart. En la práctica, la velocidad depende de la Wi-Fi y del
almacenamiento de los dispositivos. El canal de control (ofertas, aceptaciones,
miniaturas) sigue en TLS.

Se negocia por archivo: si un extremo no tiene el motor (versión antigua,
biblioteca no cargada) o su puerto no es alcanzable, ese archivo va por los
canales TLS de siempre y la app sigue funcionando. En "Acerca de" se ve si el
motor está activo. El crate se compila dentro de `flutter build` en las cinco
plataformas (cargokit en Windows, Linux e iOS; tarea de Gradle en Android), así
que hace falta `rustup` para compilar el proyecto.

## Seguridad

Cada dispositivo genera una clave EC P-256 y un certificado autofirmado. Entre
aplicaciones emparejadas, el canal de control usa TLS 1.3 con el certificado del otro extremo anclado por
huella, y cada sesión se autentica con una clave compartida derivada durante
el emparejamiento (HKDF/HMAC-SHA256). Los archivos y el emparejamiento no usan
servidores externos. Las comprobaciones de actualizaciones consultan GitHub;
los paquetes se descargan únicamente al pulsar «Actualizar» y se verifican
con el SHA-256 publicado en esa misma versión.

Los enlaces temporales para invitados, que se abren en un navegador sin instalar
la app, usan HTTP sin cifrado dentro de la red local. Úsalos únicamente en una
red de confianza; para enviar contenido cifrado, empareja las aplicaciones.

Los programas (`.exe`, `.msi`, `.apk`…) no se envían ni se aceptan, ni entre
dispositivos ni por el enlace de invitado, salvo que actives «Permitir
ejecutables» en Ajustes › Almacenamiento. Cada dispositivo decide por sí
mismo, así que hace falta activarlo en los dos; quien envía uno con el ajuste
apagado en el otro extremo ve la transferencia fallar con el motivo.

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

`.github/workflows/release.yml` compila todos los destinos al crear una
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

## Licencia y comunidad

Copyright © 2026 PepoTech ([pepitolas13](https://github.com/pepitolas13)).
El código propio de PepoConnect se publica bajo [GNU GPL versión 3](LICENSE)
(`GPL-3.0-only`). Puedes usarlo, estudiarlo, modificarlo y redistribuirlo,
también con fines comerciales. Si distribuyes una versión modificada, debes
facilitar su código fuente bajo GPLv3 y conservar los avisos de autoría.
Las dependencias y el código de terceros conservan sus respectivas licencias.

Las ideas, las pruebas en otros dispositivos y los informes de fallos ayudan
mucho. Consulta [cómo contribuir](CONTRIBUTING.md) y [cómo comunicar un problema
de seguridad](SECURITY.md).
