# Ayudar a mejorar PepoConnect

Al enviar código, aceptas publicarlo con la misma [licencia GPLv3](LICENSE)
del proyecto. Conservas los derechos de autor de tus aportaciones.

No hace falta programar para ayudar. Probarlo en un móvil o una distribución de
Linux que todavía no hemos podido comprobar, explicar un fallo o mejorar una
traducción también cuenta.

## Contar un fallo

[Abre un informe](https://github.com/pepitolas13/PepoConnect/issues/new/choose)
con la versión de PepoConnect, tus sistemas y los pasos para repetirlo. Cuanto
más pequeño sea el ejemplo, más fácil será encontrar la causa. No hace falta
compartir las fotos o archivos personales con los que ocurrió.

Para un problema de seguridad, sigue [SECURITY.md](SECURITY.md).

## Proponer una mejora

Cuenta qué estás intentando hacer y dónde se queda corta la app. Si el cambio
es grande, abre primero una propuesta para que podamos acordar su alcance.

## Enviar código

Una pull request pequeña, con un cambio claro, es más fácil de revisar. Explica
qué comportamiento cambia, cómo lo has probado y en qué dispositivos.

Consulta [cómo compilar](README.md#compilar). Antes de enviar un cambio:

```sh
flutter pub get
dart format lib test integration_test packages/pepo_core packages/pepo_native/lib
flutter analyze --fatal-infos
flutter test
cd packages/pepo_core
dart pub get
dart test --exclude-tags perf
```

Si cambias el motor Rust, ejecuta también sus pruebas. Si cambias una parte
nativa, indica en qué sistema la has comprobado. Las pruebas de un sistema no
sustituyen a las de otro.

Habla con respeto, da contexto y deja margen para que otras personas aprendan.
Los informes y las propuestas pueden estar en español o en inglés.
