// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get updateNotifications => 'Avisos de actualizaciones';

  @override
  String get updateNotificationsBody =>
      'Mostrar un aviso cuando haya una versión nueva. Aunque lo desactives, seguiremos comprobando las actualizaciones cada día.';

  @override
  String get updateDailyBody =>
      'Buscamos actualizaciones cada 24 horas mientras PepoConnect está abierto, también en la bandeja, y al volver a abrirlo si toca comprobar.';

  @override
  String get updateInstall => 'Actualizar';

  @override
  String get updateContinue => 'Continuar instalación';

  @override
  String get updateLater => 'Ahora no';

  @override
  String get updateDontNotify => 'No mostrar más avisos de actualizaciones';

  @override
  String get updateDesktopBody =>
      'Se descargará y verificará la nueva versión. PepoConnect se reiniciará para instalarla y conservará tus ajustes y dispositivos.';

  @override
  String get updateAndroidBody =>
      'La app descargará y verificará la actualización. Android te pedirá confirmar la instalación.';

  @override
  String get updateFlatpakBody =>
      'Se descargará y verificará la actualización. Confirma la instalación en el gestor de software y vuelve a abrir PepoConnect.';

  @override
  String get updateIosBody =>
      'Esta versión de iPhone se instala con AltStore o Sideloadly. iOS no permite que este paquete sin firmar se actualice solo: instala la nueva versión con la misma cuenta para conservar tus datos.';

  @override
  String get updateUnavailableBody =>
      'Aún no hay un paquete compatible y verificable para esta instalación. Puedes consultar la versión publicada y las instrucciones de instalación.';

  @override
  String get updateInstructions => 'Ver instrucciones';

  @override
  String get updateDetails => 'Ver novedades';

  @override
  String get updateDownloading => 'Descargando actualización…';

  @override
  String get updateVerifying => 'Verificando la descarga…';

  @override
  String get updateInstalling => 'Preparando la instalación…';

  @override
  String get updateCancelDownload => 'Cancelar descarga';

  @override
  String get updatePermissionBody =>
      'Permite que PepoConnect instale aplicaciones en la pantalla de Android. Al volver, continuaremos automáticamente. También puedes pulsar «Continuar instalación».';

  @override
  String get updateInstallerOpened =>
      'El instalador está abierto. Confirma la actualización; si lo cerraste, puedes volver a abrirlo con «Actualizar».';

  @override
  String get updateInstallFailed => 'No se ha podido actualizar';

  @override
  String get updateDownloadFailed =>
      'La descarga no se completó. Comprueba la conexión y el espacio disponible y vuelve a intentarlo.';

  @override
  String get updateVerificationFailed =>
      'La actualización no ha superado las comprobaciones de integridad y compatibilidad. No se ha instalado nada. Consulta las instrucciones de esta versión.';

  @override
  String get updatePermissionFailed =>
      'No hay permiso para actualizar esta instalación. Comprueba los permisos de su carpeta o del instalador y vuelve a intentarlo.';

  @override
  String get updateGenericFailed =>
      'No se pudo preparar la actualización. Tu instalación actual sigue disponible. Vuelve a intentarlo o consulta las instrucciones de la versión.';

  @override
  String get updateBusyBody =>
      'Termina o pausa las transferencias y cierra los enlaces de invitado antes de actualizar.';

  @override
  String get updateOpenFailed =>
      'No se ha podido abrir el enlace. Comprueba que tienes un navegador disponible.';

  @override
  String get appName => 'PepoConnect';

  @override
  String get appTagline => 'Fotos y archivos entre el móvil y el PC, al instante';

  @override
  String get ok => 'Aceptar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get done => 'Hecho';

  @override
  String get retry => 'Reintentar';

  @override
  String get back => 'Atrás';

  @override
  String get next => 'Siguiente';

  @override
  String get skip => 'Omitir';

  @override
  String get save => 'Guardar';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get remove => 'Quitar';

  @override
  String get delete => 'Eliminar';

  @override
  String get open => 'Abrir';

  @override
  String get copy => 'Copiar';

  @override
  String get share => 'Compartir';

  @override
  String get select => 'Seleccionar';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get deselectAll => 'Quitar selección';

  @override
  String get more => 'Más opciones';

  @override
  String get search => 'Buscar';

  @override
  String get loading => 'Cargando…';

  @override
  String get refresh => 'Actualizar';

  @override
  String get add => 'Añadir';

  @override
  String get edit => 'Editar';

  @override
  String get pause => 'Pausar';

  @override
  String get resume => 'Reanudar';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get today => 'hoy';

  @override
  String get yesterday => 'ayer';

  @override
  String get unknownDevice => 'Dispositivo desconocido';

  @override
  String get dismiss => 'Descartar';

  @override
  String get showInFolder => 'Mostrar en carpeta';

  @override
  String get saveAs => 'Guardar como…';

  @override
  String get download => 'Descargar';

  @override
  String get openFolder => 'Abrir carpeta';

  @override
  String get navTransfers => 'Transferencias';

  @override
  String get navGallery => 'Galería';

  @override
  String get navActivity => 'Actividad';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navDownloads => 'Descargas';

  @override
  String navShortcutHint(int number) {
    return 'Ctrl+$number';
  }

  @override
  String get hubTooltip => 'Dispositivos';

  @override
  String get thisPc => 'Este PC';

  @override
  String get editPcName => 'Cambiar el nombre del PC';

  @override
  String get pcNamePlaceholder => 'Nombre del PC';

  @override
  String lastSync(String when) {
    return 'Última sincronización: $when';
  }

  @override
  String get neverSynced => 'Sin sincronizar todavía';

  @override
  String get noDevicesPaired => 'No hay dispositivos emparejados';

  @override
  String get addDevice => 'Añadir dispositivo';

  @override
  String get manageDevices => 'Gestionar dispositivos';

  @override
  String get doNotDisturb => 'No molestar';

  @override
  String get doNotDisturbBody => 'Silencia los avisos hasta que lo desactives';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusOffline => 'Sin conexión';

  @override
  String get statusConnecting => 'Conectando…';

  @override
  String deviceConnected(String device) {
    return '$device conectado';
  }

  @override
  String deviceDisconnected(String device) {
    return '$device desconectado';
  }

  @override
  String batteryLevel(int percent) {
    return '$percent %';
  }

  @override
  String get batteryCharging => 'Cargando';

  @override
  String get deviceKindPhone => 'Móvil';

  @override
  String get deviceKindTablet => 'Tablet';

  @override
  String get deviceKindPc => 'PC';

  @override
  String get myPc => 'Mi PC';

  @override
  String get myDevices => 'Mis dispositivos';

  @override
  String get changeName => 'Cambiar nombre';

  @override
  String get forgetDevice => 'Quitar';

  @override
  String forgetDeviceConfirm(String device) {
    return '¿Quitar $device?';
  }

  @override
  String get forgetDeviceBody => 'Tendrás que volver a emparejarlo para usarlo';

  @override
  String get deviceNamePlaceholder => 'Nombre del dispositivo';

  @override
  String get noDevicesYet => 'Aún no hay dispositivos';

  @override
  String get pairFirstDevice => 'Empareja tu móvil para empezar';

  @override
  String deviceOptions(String device) {
    return 'Opciones de $device';
  }

  @override
  String get reconnect => 'Volver a conectar';

  @override
  String get transfersTitle => 'Transferir archivos';

  @override
  String get transfersSubtitle => 'Arrastra o añade archivos para enviarlos a tu dispositivo';

  @override
  String get addFiles => 'Añadir archivos…';

  @override
  String dropHere(String device) {
    return 'Suelta para enviar a $device';
  }

  @override
  String get dropAnywhere => 'Suelta los archivos aquí';

  @override
  String sentTo(int percent, String device) {
    return '$percent % enviado a $device';
  }

  @override
  String receivedFrom(int percent, String device) {
    return '$percent % recibido de $device';
  }

  @override
  String sendingTo(String device) {
    return 'Enviando a $device';
  }

  @override
  String receivingFrom(String device) {
    return 'Recibiendo de $device';
  }

  @override
  String get transferComplete => 'Transferencia completada';

  @override
  String transferFailed(String file) {
    return 'No se pudo transferir $file';
  }

  @override
  String get transferCancelled => 'Transferencia cancelada';

  @override
  String get transferPaused => 'En pausa';

  @override
  String get transferQueued => 'En cola';

  @override
  String get transfersEmptyTitle => 'No hay transferencias';

  @override
  String get transfersEmptyBody => 'Los archivos que envíes o recibas aparecerán aquí';

  @override
  String get transfersRecent => 'Recientes';

  @override
  String get transfersInProgress => 'En curso';

  @override
  String transfersActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transferencias en curso',
      one: '1 transferencia en curso',
    );
    return '$_temp0';
  }

  @override
  String get cancelTransfer => 'Cancelar';

  @override
  String get pauseTransfer => 'Pausar';

  @override
  String get resumeTransfer => 'Reanudar';

  @override
  String get removeFromList => 'Quitar de la lista';

  @override
  String get clearHistory => 'Borrar historial';

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
    );
    return '$_temp0';
  }

  @override
  String sendingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviando $count archivos',
      one: 'Enviando 1 archivo',
    );
    return '$_temp0';
  }

  @override
  String sendToDevice(String device) {
    return 'Enviar a $device';
  }

  @override
  String get chooseDevice => 'Elige un dispositivo';

  @override
  String get noDeviceConnected => 'No hay ningún dispositivo conectado';

  @override
  String get connectToSend => 'Conecta el móvil para enviar archivos';

  @override
  String get executableBlocked => 'PepoConnect no envía programas hasta que lo permitas en Ajustes';

  @override
  String executableBlockedOne(String file) {
    return 'No se ha enviado $file';
  }

  @override
  String executableBlockedMany(int count) {
    return 'No se han enviado $count ejecutables';
  }

  @override
  String get executableBlockedBody =>
      'PepoConnect no envía programas (.exe, .msi, .apk…) hasta que actives «Permitir ejecutables» en Ajustes › Almacenamiento, en este dispositivo y en el que los recibe.';

  @override
  String get executableOpenSettings => 'Abrir ajustes';

  @override
  String executableRefusedTitle(String file, String device) {
    return 'No se ha aceptado $file de $device';
  }

  @override
  String get executableRefusedBody =>
      'Los ejecutables están desactivados. Actívalos en Ajustes › Almacenamiento si lo esperabas';

  @override
  String get trRejectedExecutable => 'El otro dispositivo no acepta ejecutables';

  @override
  String speedAndEta(String speed, String eta) {
    return '$speed/s · quedan $eta';
  }

  @override
  String etaSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count s', one: '1 s');
    return '$_temp0';
  }

  @override
  String etaMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String galleryOf(String device) {
    return 'Galería de $device';
  }

  @override
  String get allDevices => 'Todos los dispositivos';

  @override
  String get photos => 'Fotos';

  @override
  String get videos => 'Vídeos';

  @override
  String get all => 'Todo';

  @override
  String get addToPhone => 'Añadir al móvil';

  @override
  String get type => 'Tipo';

  @override
  String get view => 'Vista';

  @override
  String get viewLarge => 'Grande';

  @override
  String get viewMedium => 'Mediana';

  @override
  String get viewSmall => 'Pequeña';

  @override
  String get squareThumbnails => 'Miniaturas cuadradas';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '1 seleccionado',
    );
    return '$_temp0';
  }

  @override
  String selectedCountSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados ($size)',
      one: '1 seleccionado ($size)',
    );
    return '$_temp0';
  }

  @override
  String get deleteFromPhone => 'Eliminar del móvil';

  @override
  String deleteFromPhoneConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count elementos del móvil?',
      one: '¿Eliminar 1 elemento del móvil?',
    );
    return '$_temp0';
  }

  @override
  String get deleteFromPhoneBody => 'Se borran del móvil. La copia del PC, si la hay, no se toca';

  @override
  String get newLabel => 'Nuevo';

  @override
  String get onPc => 'En el PC';

  @override
  String get galleryEmptyTitle => 'No hay fotos todavía';

  @override
  String get galleryEmptyBody => 'Las fotos que hagas con el móvil aparecerán aquí';

  @override
  String get galleryOffline => 'Conecta el móvil para ver la galería';

  @override
  String get galleryLoadMore => 'Cargar más';

  @override
  String newPhotosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos nuevas',
      one: '1 foto nueva',
    );
    return '$_temp0';
  }

  @override
  String downloadedTo(String path) {
    return 'Guardado en $path';
  }

  @override
  String get galleryRefreshTooltip => 'Actualizar la galería';

  @override
  String galleryItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get galleryGroupToday => 'Hoy';

  @override
  String get galleryGroupYesterday => 'Ayer';

  @override
  String get galleryGroupThisWeek => 'Esta semana';

  @override
  String get galleryGroupThisMonth => 'Este mes';

  @override
  String get dismissNew => 'Quitar la marca de nuevo';

  @override
  String get viewerTitle => 'Visor';

  @override
  String get viewerPrevious => 'Anterior';

  @override
  String get viewerNext => 'Siguiente';

  @override
  String get viewerZoomIn => 'Acercar';

  @override
  String get viewerZoomOut => 'Alejar';

  @override
  String get viewerFit => 'Ajustar a la ventana';

  @override
  String get viewerActualSize => 'Tamaño real';

  @override
  String get viewerInfo => 'Información';

  @override
  String viewerTakenOn(String date) {
    return 'Hecha el $date';
  }

  @override
  String viewerDimensions(int width, int height) {
    return '$width × $height';
  }

  @override
  String get viewerFileSize => 'Tamaño';

  @override
  String get viewerFileName => 'Nombre';

  @override
  String get viewerPlay => 'Reproducir';

  @override
  String get viewerLoadingFull => 'Cargando la foto a tamaño completo…';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get keepInBackground => 'Permitir que PepoConnect siga en segundo plano';

  @override
  String get keepInBackgroundBody => 'Al cerrar la ventana, la app sigue en la bandeja del sistema';

  @override
  String get startWithWindows => 'Iniciar PepoConnect con Windows';

  @override
  String get startWithSystem => 'Iniciar PepoConnect al arrancar';

  @override
  String get theme => 'Tema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeSystem => 'Según el sistema';

  @override
  String get downloadsSavedIn => 'Los archivos recibidos se guardan en:';

  @override
  String get changeLocation => 'Cambiar ubicación';

  @override
  String get separateByDevice => 'Separar por dispositivo';

  @override
  String get separateByDeviceBody => 'Una carpeta por dispositivo dentro de esa ubicación';

  @override
  String get animations => 'Animaciones';

  @override
  String get animationsBody => 'Desactívalas para ahorrar recursos';

  @override
  String get autoDownloadPhotos => 'Descargar fotos nuevas automáticamente';

  @override
  String get autoDownloadPhotosBody => 'Cada foto nueva se guarda en el PC sin preguntar';

  @override
  String get convertHeic => 'Convertir HEIC a JPEG';

  @override
  String get convertHeicBody => 'Las fotos del iPhone se guardan como JPEG';

  @override
  String get sharedClipboard => 'Portapapeles compartido';

  @override
  String get sharedClipboardBody =>
      'Lo que copies en un dispositivo se puede pegar en el otro. En el móvil se envía al abrir PepoConnect, con el tile «Enviar portapapeles» de los ajustes rápidos o con el acceso directo del icono.';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get notificationsBody => 'Avisos de fotos nuevas y transferencias';

  @override
  String get sounds => 'Sonidos';

  @override
  String get soundsBody => 'Un sonido corto al terminar una transferencia';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Según el sistema';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String version(String version) {
    return 'Versión $version';
  }

  @override
  String get aboutBody =>
      'Fotos y archivos entre el móvil y el PC, en tu red local. Nada pasa por internet';

  @override
  String get allowExecutables => 'Permitir ejecutables';

  @override
  String get autoSendPhotos => 'Enviar fotos nuevas al PC automáticamente';

  @override
  String get autoSendPhotosBody => 'Cada foto que hagas llega al PC al momento';

  @override
  String get backgroundService => 'Mantener la conexión en segundo plano';

  @override
  String get backgroundServiceBody => 'Necesario para que las fotos lleguen con la app cerrada';

  @override
  String get defaultHub => 'PC predeterminado';

  @override
  String get deviceSettings => 'Ajustes del dispositivo';

  @override
  String get openDownloadsFolder => 'Abrir la carpeta de descargas';

  @override
  String get resetSettings => 'Restablecer ajustes';

  @override
  String get settingsSaved => 'Ajustes guardados';

  @override
  String get pairTitle => 'Empareja tu móvil y tu PC';

  @override
  String get pairSubtitle => 'Los dos deben estar en la misma red Wi-Fi';

  @override
  String get pairStep1 => 'Instala PepoConnect en el móvil y toca Añadir PC';

  @override
  String get pairStep2 => 'Escanea este código con el móvil';

  @override
  String pairStepNumber(int number) {
    return 'Paso $number';
  }

  @override
  String get pairCheckCode => 'Comprueba el código';

  @override
  String get pairCheckCodeBody => 'Confirma que el móvil muestra el mismo código';

  @override
  String get pairConfirm => 'Confirmar';

  @override
  String get pairRescan => 'Volver a escanear';

  @override
  String get pairDone => 'Emparejado';

  @override
  String get pairDoneBody => 'Tu PC y tu móvil ya están conectados';

  @override
  String get pairUseCode => 'Usar código en lugar de QR';

  @override
  String get pairUseQr => 'Usar QR';

  @override
  String get pairCode => 'Código';

  @override
  String pairExpiresIn(int seconds) {
    return 'Caduca en $seconds s';
  }

  @override
  String get pairExpired => 'El código ha caducado';

  @override
  String get pairNewCode => 'Nuevo código';

  @override
  String get pairEnterCode => 'Escribe el código que muestra el PC';

  @override
  String get pairScanQr => 'Escanea el QR del PC';

  @override
  String get pairFailed => 'No se pudo emparejar';

  @override
  String get pairFailedBody => 'Comprueba el código y que los dos estén en la misma red';

  @override
  String get pairCancel => 'Cancelar emparejamiento';

  @override
  String get pairSearching => 'Buscando PCs en la red…';

  @override
  String get pairFound => 'PCs encontrados';

  @override
  String get pairManual => 'Escribir la dirección a mano';

  @override
  String get pairAddress => 'Dirección';

  @override
  String get pairPort => 'Puerto';

  @override
  String pairConnecting(String device) {
    return 'Conectando con $device…';
  }

  @override
  String pairingWith(String device) {
    return 'Emparejando con $device';
  }

  @override
  String pairRequestTitle(String device) {
    return '$device quiere emparejarse';
  }

  @override
  String get pairCameraPermission => 'PepoConnect necesita la cámara para leer el QR';

  @override
  String get mobileReceived => 'Recibidos';

  @override
  String get mobileSent => 'Enviados';

  @override
  String get mobileSendToPc => 'Enviar al PC';

  @override
  String get mobileFiles => 'Archivos';

  @override
  String get mobileGallery => 'Galería';

  @override
  String get mobileClipboard => 'Portapapeles';

  @override
  String get mobileCamera => 'Cámara';

  @override
  String get mobileNoPc => 'Sin PC conectado';

  @override
  String get mobileTapToChangePc => 'Toca para cambiar de PC';

  @override
  String get mobileShareVia => 'Enviar con PepoConnect';

  @override
  String get mobileReceivedEmpty => 'Los archivos que te envíe el PC aparecerán aquí';

  @override
  String get mobileSentEmpty => 'Lo que envíes al PC aparecerá aquí';

  @override
  String get mobileAddPc => 'Añadir PC';

  @override
  String mobileServiceNotification(String device) {
    return 'PepoConnect está conectado con $device';
  }

  @override
  String get mobileServiceIdle => 'PepoConnect espera al PC';

  @override
  String get activityTitle => 'Actividad';

  @override
  String activityNewPhoto(String device) {
    return 'Foto nueva en $device';
  }

  @override
  String activityNewVideo(String device) {
    return 'Vídeo nuevo en $device';
  }

  @override
  String activityReceived(String file, String device) {
    return 'Recibido $file de $device';
  }

  @override
  String activitySent(String file, String device) {
    return 'Enviado $file a $device';
  }

  @override
  String activityFailed(String file) {
    return 'No se pudo transferir $file';
  }

  @override
  String activityConnected(String device) {
    return '$device conectado';
  }

  @override
  String activityDisconnected(String device) {
    return '$device desconectado';
  }

  @override
  String activityPaired(String device) {
    return '$device emparejado';
  }

  @override
  String activityForgotten(String device) {
    return '$device quitado';
  }

  @override
  String activityClipboard(String device) {
    return 'Texto copiado de $device';
  }

  @override
  String get activityEmpty => 'Sin actividad reciente';

  @override
  String get markAllRead => 'Marcar todo como leído';

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sin leer',
      one: '1 sin leer',
    );
    return '$_temp0';
  }

  @override
  String get activityPanelShow => 'Mostrar actividad';

  @override
  String get activityPanelHide => 'Ocultar actividad';

  @override
  String get toastNewPhoto => 'Foto nueva';

  @override
  String get toastNewVideo => 'Vídeo nuevo';

  @override
  String toastNewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos nuevos',
      one: '1 elemento nuevo',
    );
    return '$_temp0';
  }

  @override
  String toastNewPhotos(int count) {
    return '$count fotos nuevas';
  }

  @override
  String get toastView => 'Ver';

  @override
  String get toastSaved => 'Guardado en el PC';

  @override
  String get toastCopied => 'Copiado';

  @override
  String toastSentTo(String device) {
    return 'Enviado a $device';
  }

  @override
  String toastReceivedFrom(String device) {
    return 'Recibido de $device';
  }

  @override
  String toastDeviceConnected(String device) {
    return '$device conectado';
  }

  @override
  String toastDeviceOffline(String device) {
    return '$device sin conexión';
  }

  @override
  String toastDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos eliminados del móvil',
      one: '1 elemento eliminado del móvil',
    );
    return '$_temp0';
  }

  @override
  String toastClipboardReceived(String device) {
    return 'Texto copiado desde $device';
  }

  @override
  String toastClipboardSent(String device) {
    return 'Portapapeles enviado a $device';
  }

  @override
  String get clipboardEmpty => 'El portapapeles está vacío';

  @override
  String get clipboardNoTarget => 'Ningún PC conectado con el portapapeles compartido';

  @override
  String get clipboardQueued => 'Sin PC conectado: se enviará al conectar';

  @override
  String get toastUndo => 'Deshacer';

  @override
  String get errorGeneric => 'Algo ha fallado';

  @override
  String get errorNetwork => 'Sin conexión con el dispositivo';

  @override
  String get errorNotPaired => 'Este dispositivo ya no está emparejado';

  @override
  String get errorFileMissing => 'El archivo ya no existe';

  @override
  String get errorNoSpace => 'No queda espacio en el disco';

  @override
  String get errorPermission => 'PepoConnect no tiene permiso para acceder a las fotos';

  @override
  String get errorPermissionAction => 'Abrir ajustes';

  @override
  String get errorTimeout => 'El dispositivo no responde';

  @override
  String get errorCancelled => 'Cancelado';

  @override
  String get errorTryAgain => 'Inténtalo de nuevo';

  @override
  String get errorFolderMissing => 'La carpeta de descargas no existe';

  @override
  String get errorCode => 'Código incorrecto';

  @override
  String get errorDetails => 'Detalles';

  @override
  String get errorCopyDetails => 'Copiar detalles';

  @override
  String get onboardingTitle => 'Tu móvil, en el PC';

  @override
  String get onboardingBody =>
      'Las fotos que hagas aparecen aquí al instante. Y puedes enviar archivos en los dos sentidos';

  @override
  String get onboardingStart => 'Empezar';

  @override
  String get onboardingPairLater => 'Emparejar más tarde';

  @override
  String get onboardingNamePrompt => '¿Cómo se llama este PC?';

  @override
  String get onboardingFolderPrompt => '¿Dónde guardamos lo que llegue?';

  @override
  String get onboardingLocalOnly => 'Todo va por tu red local. Nada sale a internet';

  @override
  String get shortcutsTitle => 'Atajos de teclado';

  @override
  String get shortcutSections => 'Ctrl+1 a Ctrl+4 cambian de sección';

  @override
  String get shortcutSettings => 'Ctrl+, abre Ajustes';

  @override
  String get shortcutRefresh => 'F5 actualiza';

  @override
  String get shortcutEscape => 'Esc cierra menús y selecciones';

  @override
  String get trShareWithAnyone => 'Compartir con cualquiera';

  @override
  String get trGuestSend => 'Enviar';

  @override
  String get trGuestReceive => 'Recibir';

  @override
  String get trGuestSendBody =>
      'Quien abra el enlace podrá descargar estos archivos desde el navegador, sin instalar nada';

  @override
  String get trGuestReceiveBody =>
      'Quien abra el enlace podrá enviarte archivos desde el navegador';

  @override
  String get trGuestNoFiles => 'Añade al menos un archivo';

  @override
  String get trGuestMessage => 'Mensaje (opcional)';

  @override
  String get trGuestCreateLink => 'Crear enlace';

  @override
  String get trGuestReadyTitle => 'Tus archivos están listos';

  @override
  String get trGuestReceiveReadyTitle => 'Listo para recibir';

  @override
  String get trGuestScanHint =>
      'Escanea el QR o abre el enlace desde un dispositivo en la misma red Wi-Fi';

  @override
  String get trGuestCopyLink => 'Copiar enlace';

  @override
  String trGuestExpiresIn(String time) {
    return 'El enlace caduca en $time';
  }

  @override
  String get trGuestExpired => 'El enlace ha caducado';

  @override
  String get trGuestNewLink => 'Crear otro enlace';

  @override
  String get trGuestWaiting => 'Nadie ha abierto el enlace todavía';

  @override
  String trGuestOpenedBy(String remote) {
    return 'Abierto por $remote';
  }

  @override
  String trGuestDownloaded(String file) {
    return 'Descargado $file';
  }

  @override
  String trGuestReceived(String file) {
    return 'Recibido $file';
  }

  @override
  String trGuestUploadFailed(String file) {
    return 'No se pudo recibir $file';
  }

  @override
  String get trGuestNoAddress => 'No se ha encontrado ninguna red local';

  @override
  String get trGuestFailed => 'No se pudo crear el enlace';

  @override
  String get trHistory => 'Historial';

  @override
  String get trSendFailed => 'No se pudo enviar';

  @override
  String get trDroppedNothing => 'No hay archivos que enviar';

  @override
  String get trNoPcConnected => 'Conecta un PC para enviar archivos';

  @override
  String get galYourPhone => 'Tu móvil';

  @override
  String get galYourTablet => 'Tu tablet';

  @override
  String get galYourPc => 'Tu PC';

  @override
  String get galFullThumbnails => 'Miniaturas completas';

  @override
  String get galTileSize => 'Tamaño de las miniaturas';

  @override
  String get galSession => 'Sesión';

  @override
  String get galSessionTooltip => 'Modo sesión: el visor salta a cada foto nueva';

  @override
  String galSavedCopies(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos guardados en $folder',
      one: '1 archivo guardado en $folder',
    );
    return '$_temp0';
  }

  @override
  String galSaveFailed(String file) {
    return 'No se pudo guardar $file';
  }

  @override
  String galDownloadFailed(String file) {
    return 'No se pudo descargar $file';
  }

  @override
  String get galDeleteFailed => 'No se pudo eliminar del móvil';

  @override
  String galSelectGroup(String group) {
    return 'Seleccionar $group';
  }

  @override
  String get galSelectNew => 'Seleccionar nuevas';

  @override
  String galDownloadStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descargando $count elementos',
      one: 'Descargando 1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get galOfflineBody => 'Las fotos aparecerán en cuanto se conecte';

  @override
  String get vwDevice => 'Dispositivo';

  @override
  String get vwDate => 'Fecha';

  @override
  String get vwResolution => 'Resolución';

  @override
  String get vwDownloading => 'Descargando…';

  @override
  String vwSessionCounter(int photos, int downloaded) {
    String _temp0 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos fotos',
      one: '1 foto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      downloaded,
      locale: localeName,
      other: '$downloaded descargadas',
      one: '1 descargada',
    );
    return 'Sesión · $_temp0 · $_temp1';
  }

  @override
  String get vwSessionWaiting => 'Esperando fotos nuevas…';

  @override
  String get vwSessionHint => 'Espacio: descargar · Esc: salir';

  @override
  String get vwSessionExit => 'Salir de la sesión';

  @override
  String vwPosition(int index, int total) {
    return '$index de $total';
  }

  @override
  String get vwNotFound => 'Este elemento ya no está en la galería';

  @override
  String get vwPreviewFailed => 'No se pudo cargar la vista previa';

  @override
  String get vwVideoOpenFailed => 'No se pudo abrir el vídeo';

  @override
  String get vwStateOnPhone => 'Solo en el móvil';

  @override
  String get setStorage => 'Almacenamiento';

  @override
  String get setThisPhone => 'Este móvil';

  @override
  String get setRenameDeviceTitle => 'Cambiar el nombre del dispositivo';

  @override
  String setForgetConfirm(String device) {
    return '¿Quieres olvidar \"$device\"?';
  }

  @override
  String get setForgetBody => 'Tendrás que emparejarlo de nuevo';

  @override
  String setLastConnection(String when) {
    return 'Última conexión: $when';
  }

  @override
  String get setThemeBody => 'Elige cómo se ve PepoConnect';

  @override
  String get setStartWithSystem => 'Iniciar PepoConnect con el sistema';

  @override
  String get setStartWithSystemBody => 'Arranca minimizado, en la bandeja';

  @override
  String get setSeparateByDeviceBody => 'Crea una subcarpeta por cada móvil';

  @override
  String get setAllowExecutablesBody =>
      'Desactivado, no se envían ni se reciben programas (.exe, .msi, .apk…). Actívalo en los dos dispositivos solo si lo necesitas';

  @override
  String get setResetLocation => 'Restablecer';

  @override
  String get setDefaultLocation => 'Carpeta predeterminada';

  @override
  String get setChooseFolder => 'Elige dónde guardar los archivos recibidos';

  @override
  String get setBackgroundService => 'Servicio en segundo plano';

  @override
  String get setBackgroundServiceBody => 'Mantiene la conexión con el PC';

  @override
  String get setBackgroundServiceBodyIos =>
      'Mantiene PepoConnect en marcha con la app cerrada para que las fotos salgan solas. Gasta algo de batería.';

  @override
  String get setBackgroundEngine => 'Estado del segundo plano';

  @override
  String setBackgroundEngineOn(String uptime) {
    return 'Activo desde hace $uptime';
  }

  @override
  String get setBackgroundEngineStarting => 'Arrancando…';

  @override
  String get setBackgroundEngineRecovering => 'Recuperándose…';

  @override
  String get setBackgroundEngineOff => 'Parado';

  @override
  String get setBackgroundEngineBody =>
      'Si cierras PepoConnect desde el selector de apps, deja de funcionar hasta que la vuelvas a abrir.';

  @override
  String get setPermissionPhotosLimited =>
      'Acceso limitado: PepoConnect solo ve las fotos que elegiste, así que las nuevas no se envían.';

  @override
  String get setOpenSystemSettings => 'Abrir Ajustes';

  @override
  String get setAutoSendPhotos => 'Enviar fotos nuevas automáticamente';

  @override
  String get setAutoSendPhotosBody => 'Cada foto que hagas llega al PC principal al momento';

  @override
  String get setDefaultHub => 'PC principal';

  @override
  String get setDefaultHubBody => 'Recibe las fotos nuevas y lo que compartas';

  @override
  String get setDefaultHubNone => 'Sin elegir';

  @override
  String get setDefaultHubRequired => 'Elige primero un PC principal';

  @override
  String get setPermissions => 'Permisos';

  @override
  String get setPermissionPhotos => 'Fotos y vídeos';

  @override
  String get setPermissionPhotosBody => 'Para mostrar la galería en el PC';

  @override
  String get setPermissionNotificationsBody => 'Para avisar de lo que llega y sale';

  @override
  String get setPermissionBattery => 'Sin restricción de batería';

  @override
  String get setPermissionBatteryBody => 'Para no perder la conexión con la pantalla apagada';

  @override
  String get setAllow => 'Permitir';

  @override
  String get setGranted => 'Concedido';

  @override
  String get setDeviceId => 'ID de este dispositivo';

  @override
  String get setFastLane => 'Motor rápido';

  @override
  String setFastLaneOn(int port) {
    return 'Activo · Rust, AES-256-GCM, puerto $port';
  }

  @override
  String get setFastLaneOff => 'No disponible en este dispositivo; se usan los canales TLS';

  @override
  String get setCheckUpdates => 'Comprobar actualizaciones';

  @override
  String get setUpToDate => 'Tienes la última versión';

  @override
  String setUpdateAvailable(String version) {
    return 'Hay una versión nueva: $version';
  }

  @override
  String get setUpdateFailed => 'No se pudo comprobar';

  @override
  String get setUpdateFailedBody => 'Revisa la conexión a internet e inténtalo más tarde';

  @override
  String get setViewOnGitHub => 'Ver en GitHub';

  @override
  String get setSourceCode => 'Código fuente en GitHub';

  @override
  String get setResetConfirm => '¿Restablecer los ajustes?';

  @override
  String get setResetBody =>
      'Vuelven a los valores iniciales. Los dispositivos emparejados se conservan';

  @override
  String get setResetDone => 'Ajustes restablecidos';

  @override
  String get onbHowTitle => '¿Cómo quieres usar PepoConnect?';

  @override
  String get onbConnectPhone => 'Conecta tu móvil';

  @override
  String get onbConnectPhoneBody => 'Mira sus fotos y pásate archivos';

  @override
  String get onbAddPhone => 'Añadir móvil';

  @override
  String get onbShareTitle => 'Comparte con cualquiera';

  @override
  String get onbShareBody => 'Envía o recibe archivos con un enlace, sin instalar nada';

  @override
  String get onbSkipForNow => 'Saltar por ahora';

  @override
  String get onbSlide1 => 'Pasa fotos y archivos entre este móvil y tu PC';

  @override
  String get onbSlide2 => 'Cada foto nueva aparece en el PC al momento';

  @override
  String get onbSlide3 => 'Todo por tu red, cifrado, sin cuentas';

  @override
  String get onbPermissionsTitle => 'Permisos necesarios';

  @override
  String get onbPermissionsBody =>
      'PepoConnect los necesita para seguir funcionando con la pantalla apagada';

  @override
  String get onbPermissionsSkipWarning => 'Sin ellos, las fotos no llegarán solas al PC';

  @override
  String get onbContinue => 'Continuar';

  @override
  String onbPageOf(int current, int total) {
    return 'Página $current de $total';
  }

  @override
  String get pairInstallTitle => 'Instala PepoConnect en el móvil';

  @override
  String get pairDownloadApp => 'Descargar la app';

  @override
  String get pairScanStep => 'Abre la app y escanea este código';

  @override
  String pairExpiresInTime(String time) {
    return 'Caduca en $time';
  }

  @override
  String get pairGenerateAnother => 'Generar otro código';

  @override
  String get pairOtherPc => 'Conectar con otro PC';

  @override
  String pairYourPc(String address) {
    return 'Tu PC: $address';
  }

  @override
  String get pairCodeHint => 'Escríbelo en el otro PC en Emparejar › Introducir código';

  @override
  String get pairEnterCodeTitle => 'Introducir código';

  @override
  String get pairManualAddress => 'Dirección del PC (IP:puerto)';

  @override
  String get pairConnect => 'Emparejar';

  @override
  String get pairSelectPc => 'Elige el PC';

  @override
  String get pairScanTitle => 'Escanea el código del PC';

  @override
  String get pairScanHint => 'Abre PepoConnect en el PC y ve a Añadir dispositivo';

  @override
  String get pairEnterManually => 'Introducir a mano';

  @override
  String get pairPasteLink => 'Pega aquí el enlace pepoconnect://…';

  @override
  String get pairPairing => 'Emparejando…';

  @override
  String get pairTorch => 'Linterna';

  @override
  String get pairLinkExpired => 'El enlace ha caducado. Genera otro código en el PC';

  @override
  String get pairNotACode => 'Eso no es un código de PepoConnect';

  @override
  String get pairWrongCode => 'Código incorrecto. Comprueba los seis dígitos';

  @override
  String get pairPcNotFound =>
      'No se encuentra el PC. Comprueba que los dos están en la misma red Wi-Fi';

  @override
  String get pairIdentityChanged => 'La identidad del PC ha cambiado. Vuelve a buscarlo';

  @override
  String get pairCameraDenied => 'Sin acceso a la cámara';

  @override
  String get pairAddressInvalid => 'Escribe una dirección válida, por ejemplo 192.168.1.20:47473';

  @override
  String get pairCodeInvalid => 'El código tiene seis dígitos';
}
