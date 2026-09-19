import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('es')];

  /// No description provided for @updateNotifications.
  ///
  /// In es, this message translates to:
  /// **'Avisos de actualizaciones'**
  String get updateNotifications;

  /// No description provided for @updateNotificationsBody.
  ///
  /// In es, this message translates to:
  /// **'Mostrar un aviso cuando haya una versión nueva. Aunque lo desactives, seguiremos comprobando las actualizaciones cada día.'**
  String get updateNotificationsBody;

  /// No description provided for @updateDailyBody.
  ///
  /// In es, this message translates to:
  /// **'Buscamos actualizaciones cada 24 horas mientras PepoConnect está abierto, también en la bandeja, y al volver a abrirlo si toca comprobar.'**
  String get updateDailyBody;

  /// No description provided for @updateInstall.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get updateInstall;

  /// No description provided for @updateContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar instalación'**
  String get updateContinue;

  /// No description provided for @updateLater.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get updateLater;

  /// No description provided for @updateDontNotify.
  ///
  /// In es, this message translates to:
  /// **'No mostrar más avisos de actualizaciones'**
  String get updateDontNotify;

  /// No description provided for @updateDesktopBody.
  ///
  /// In es, this message translates to:
  /// **'Se descargará y verificará la nueva versión. PepoConnect se reiniciará para instalarla y conservará tus ajustes y dispositivos.'**
  String get updateDesktopBody;

  /// No description provided for @updateAndroidBody.
  ///
  /// In es, this message translates to:
  /// **'La app descargará y verificará la actualización. Android te pedirá confirmar la instalación.'**
  String get updateAndroidBody;

  /// No description provided for @updateFlatpakBody.
  ///
  /// In es, this message translates to:
  /// **'Se descargará y verificará la actualización. Confirma la instalación en el gestor de software y vuelve a abrir PepoConnect.'**
  String get updateFlatpakBody;

  /// No description provided for @updateIosBody.
  ///
  /// In es, this message translates to:
  /// **'Esta versión de iPhone se instala con AltStore o Sideloadly. iOS no permite que este paquete sin firmar se actualice solo: instala la nueva versión con la misma cuenta para conservar tus datos.'**
  String get updateIosBody;

  /// No description provided for @updateUnavailableBody.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay un paquete compatible y verificable para esta instalación. Puedes consultar la versión publicada y las instrucciones de instalación.'**
  String get updateUnavailableBody;

  /// No description provided for @updateInstructions.
  ///
  /// In es, this message translates to:
  /// **'Ver instrucciones'**
  String get updateInstructions;

  /// No description provided for @updateDetails.
  ///
  /// In es, this message translates to:
  /// **'Ver novedades'**
  String get updateDetails;

  /// No description provided for @updateDownloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando actualización…'**
  String get updateDownloading;

  /// No description provided for @updateVerifying.
  ///
  /// In es, this message translates to:
  /// **'Verificando la descarga…'**
  String get updateVerifying;

  /// No description provided for @updateInstalling.
  ///
  /// In es, this message translates to:
  /// **'Preparando la instalación…'**
  String get updateInstalling;

  /// No description provided for @updateCancelDownload.
  ///
  /// In es, this message translates to:
  /// **'Cancelar descarga'**
  String get updateCancelDownload;

  /// No description provided for @updatePermissionBody.
  ///
  /// In es, this message translates to:
  /// **'Permite que PepoConnect instale aplicaciones en la pantalla de Android. Al volver, continuaremos automáticamente. También puedes pulsar «Continuar instalación».'**
  String get updatePermissionBody;

  /// No description provided for @updateInstallerOpened.
  ///
  /// In es, this message translates to:
  /// **'El instalador está abierto. Confirma la actualización; si lo cerraste, puedes volver a abrirlo con «Actualizar».'**
  String get updateInstallerOpened;

  /// No description provided for @updateInstallFailed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido actualizar'**
  String get updateInstallFailed;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In es, this message translates to:
  /// **'La descarga no se completó. Comprueba la conexión y el espacio disponible y vuelve a intentarlo.'**
  String get updateDownloadFailed;

  /// No description provided for @updateVerificationFailed.
  ///
  /// In es, this message translates to:
  /// **'La actualización no ha superado las comprobaciones de integridad y compatibilidad. No se ha instalado nada. Consulta las instrucciones de esta versión.'**
  String get updateVerificationFailed;

  /// No description provided for @updatePermissionFailed.
  ///
  /// In es, this message translates to:
  /// **'No hay permiso para actualizar esta instalación. Comprueba los permisos de su carpeta o del instalador y vuelve a intentarlo.'**
  String get updatePermissionFailed;

  /// No description provided for @updateGenericFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo preparar la actualización. Tu instalación actual sigue disponible. Vuelve a intentarlo o consulta las instrucciones de la versión.'**
  String get updateGenericFailed;

  /// No description provided for @updateBusyBody.
  ///
  /// In es, this message translates to:
  /// **'Termina o pausa las transferencias y cierra los enlaces de invitado antes de actualizar.'**
  String get updateBusyBody;

  /// No description provided for @updateOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido abrir el enlace. Comprueba que tienes un navegador disponible.'**
  String get updateOpenFailed;

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'PepoConnect'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In es, this message translates to:
  /// **'Fotos y archivos entre el móvil y el PC, al instante'**
  String get appTagline;

  /// No description provided for @ok.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @done.
  ///
  /// In es, this message translates to:
  /// **'Hecho'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get back;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get skip;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @rename.
  ///
  /// In es, this message translates to:
  /// **'Cambiar nombre'**
  String get rename;

  /// No description provided for @remove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get remove;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @open.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get open;

  /// No description provided for @copy.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get share;

  /// No description provided for @select.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar'**
  String get select;

  /// No description provided for @selectAll.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todo'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In es, this message translates to:
  /// **'Quitar selección'**
  String get deselectAll;

  /// No description provided for @more.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get more;

  /// No description provided for @search.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get loading;

  /// No description provided for @refresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get refresh;

  /// No description provided for @add.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @pause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In es, this message translates to:
  /// **'Reanudar'**
  String get resume;

  /// No description provided for @clearAll.
  ///
  /// In es, this message translates to:
  /// **'Borrar todo'**
  String get clearAll;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'hoy'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In es, this message translates to:
  /// **'ayer'**
  String get yesterday;

  /// No description provided for @unknownDevice.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo desconocido'**
  String get unknownDevice;

  /// No description provided for @dismiss.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get dismiss;

  /// No description provided for @showInFolder.
  ///
  /// In es, this message translates to:
  /// **'Mostrar en carpeta'**
  String get showInFolder;

  /// No description provided for @saveAs.
  ///
  /// In es, this message translates to:
  /// **'Guardar como…'**
  String get saveAs;

  /// No description provided for @download.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get download;

  /// No description provided for @openFolder.
  ///
  /// In es, this message translates to:
  /// **'Abrir carpeta'**
  String get openFolder;

  /// No description provided for @navTransfers.
  ///
  /// In es, this message translates to:
  /// **'Transferencias'**
  String get navTransfers;

  /// No description provided for @navGallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get navGallery;

  /// No description provided for @navActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get navActivity;

  /// No description provided for @navSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get navSettings;

  /// No description provided for @navDownloads.
  ///
  /// In es, this message translates to:
  /// **'Descargas'**
  String get navDownloads;

  /// No description provided for @navShortcutHint.
  ///
  /// In es, this message translates to:
  /// **'Ctrl+{number}'**
  String navShortcutHint(int number);

  /// No description provided for @hubTooltip.
  ///
  /// In es, this message translates to:
  /// **'Dispositivos'**
  String get hubTooltip;

  /// No description provided for @thisPc.
  ///
  /// In es, this message translates to:
  /// **'Este PC'**
  String get thisPc;

  /// No description provided for @editPcName.
  ///
  /// In es, this message translates to:
  /// **'Cambiar el nombre del PC'**
  String get editPcName;

  /// No description provided for @pcNamePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Nombre del PC'**
  String get pcNamePlaceholder;

  /// No description provided for @lastSync.
  ///
  /// In es, this message translates to:
  /// **'Última sincronización: {when}'**
  String lastSync(String when);

  /// No description provided for @neverSynced.
  ///
  /// In es, this message translates to:
  /// **'Sin sincronizar todavía'**
  String get neverSynced;

  /// No description provided for @noDevicesPaired.
  ///
  /// In es, this message translates to:
  /// **'No hay dispositivos emparejados'**
  String get noDevicesPaired;

  /// No description provided for @addDevice.
  ///
  /// In es, this message translates to:
  /// **'Añadir dispositivo'**
  String get addDevice;

  /// No description provided for @manageDevices.
  ///
  /// In es, this message translates to:
  /// **'Gestionar dispositivos'**
  String get manageDevices;

  /// No description provided for @doNotDisturb.
  ///
  /// In es, this message translates to:
  /// **'No molestar'**
  String get doNotDisturb;

  /// No description provided for @doNotDisturbBody.
  ///
  /// In es, this message translates to:
  /// **'Silencia los avisos hasta que lo desactives'**
  String get doNotDisturbBody;

  /// No description provided for @statusConnected.
  ///
  /// In es, this message translates to:
  /// **'Conectado'**
  String get statusConnected;

  /// No description provided for @statusOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión'**
  String get statusOffline;

  /// No description provided for @statusConnecting.
  ///
  /// In es, this message translates to:
  /// **'Conectando…'**
  String get statusConnecting;

  /// No description provided for @deviceConnected.
  ///
  /// In es, this message translates to:
  /// **'{device} conectado'**
  String deviceConnected(String device);

  /// No description provided for @deviceDisconnected.
  ///
  /// In es, this message translates to:
  /// **'{device} desconectado'**
  String deviceDisconnected(String device);

  /// No description provided for @batteryLevel.
  ///
  /// In es, this message translates to:
  /// **'{percent} %'**
  String batteryLevel(int percent);

  /// No description provided for @batteryCharging.
  ///
  /// In es, this message translates to:
  /// **'Cargando'**
  String get batteryCharging;

  /// No description provided for @deviceKindPhone.
  ///
  /// In es, this message translates to:
  /// **'Móvil'**
  String get deviceKindPhone;

  /// No description provided for @deviceKindTablet.
  ///
  /// In es, this message translates to:
  /// **'Tablet'**
  String get deviceKindTablet;

  /// No description provided for @deviceKindPc.
  ///
  /// In es, this message translates to:
  /// **'PC'**
  String get deviceKindPc;

  /// No description provided for @myPc.
  ///
  /// In es, this message translates to:
  /// **'Mi PC'**
  String get myPc;

  /// No description provided for @myDevices.
  ///
  /// In es, this message translates to:
  /// **'Mis dispositivos'**
  String get myDevices;

  /// No description provided for @changeName.
  ///
  /// In es, this message translates to:
  /// **'Cambiar nombre'**
  String get changeName;

  /// No description provided for @forgetDevice.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get forgetDevice;

  /// No description provided for @forgetDeviceConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar {device}?'**
  String forgetDeviceConfirm(String device);

  /// No description provided for @forgetDeviceBody.
  ///
  /// In es, this message translates to:
  /// **'Tendrás que volver a emparejarlo para usarlo'**
  String get forgetDeviceBody;

  /// No description provided for @deviceNamePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Nombre del dispositivo'**
  String get deviceNamePlaceholder;

  /// No description provided for @noDevicesYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay dispositivos'**
  String get noDevicesYet;

  /// No description provided for @pairFirstDevice.
  ///
  /// In es, this message translates to:
  /// **'Empareja tu móvil para empezar'**
  String get pairFirstDevice;

  /// No description provided for @deviceOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones de {device}'**
  String deviceOptions(String device);

  /// No description provided for @reconnect.
  ///
  /// In es, this message translates to:
  /// **'Volver a conectar'**
  String get reconnect;

  /// No description provided for @transfersTitle.
  ///
  /// In es, this message translates to:
  /// **'Transferir archivos'**
  String get transfersTitle;

  /// No description provided for @transfersSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Arrastra o añade archivos para enviarlos a tu dispositivo'**
  String get transfersSubtitle;

  /// No description provided for @addFiles.
  ///
  /// In es, this message translates to:
  /// **'Añadir archivos…'**
  String get addFiles;

  /// No description provided for @dropHere.
  ///
  /// In es, this message translates to:
  /// **'Suelta para enviar a {device}'**
  String dropHere(String device);

  /// No description provided for @dropAnywhere.
  ///
  /// In es, this message translates to:
  /// **'Suelta los archivos aquí'**
  String get dropAnywhere;

  /// No description provided for @sentTo.
  ///
  /// In es, this message translates to:
  /// **'{percent} % enviado a {device}'**
  String sentTo(int percent, String device);

  /// No description provided for @receivedFrom.
  ///
  /// In es, this message translates to:
  /// **'{percent} % recibido de {device}'**
  String receivedFrom(int percent, String device);

  /// No description provided for @sendingTo.
  ///
  /// In es, this message translates to:
  /// **'Enviando a {device}'**
  String sendingTo(String device);

  /// No description provided for @receivingFrom.
  ///
  /// In es, this message translates to:
  /// **'Recibiendo de {device}'**
  String receivingFrom(String device);

  /// No description provided for @transferComplete.
  ///
  /// In es, this message translates to:
  /// **'Transferencia completada'**
  String get transferComplete;

  /// No description provided for @transferFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo transferir {file}'**
  String transferFailed(String file);

  /// No description provided for @transferCancelled.
  ///
  /// In es, this message translates to:
  /// **'Transferencia cancelada'**
  String get transferCancelled;

  /// No description provided for @transferPaused.
  ///
  /// In es, this message translates to:
  /// **'En pausa'**
  String get transferPaused;

  /// No description provided for @transferQueued.
  ///
  /// In es, this message translates to:
  /// **'En cola'**
  String get transferQueued;

  /// No description provided for @transfersEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'No hay transferencias'**
  String get transfersEmptyTitle;

  /// No description provided for @transfersEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Los archivos que envíes o recibas aparecerán aquí'**
  String get transfersEmptyBody;

  /// No description provided for @transfersRecent.
  ///
  /// In es, this message translates to:
  /// **'Recientes'**
  String get transfersRecent;

  /// No description provided for @transfersInProgress.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get transfersInProgress;

  /// No description provided for @transfersActiveCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 transferencia en curso} other{{count} transferencias en curso}}'**
  String transfersActiveCount(int count);

  /// No description provided for @cancelTransfer.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelTransfer;

  /// No description provided for @pauseTransfer.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get pauseTransfer;

  /// No description provided for @resumeTransfer.
  ///
  /// In es, this message translates to:
  /// **'Reanudar'**
  String get resumeTransfer;

  /// No description provided for @removeFromList.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la lista'**
  String get removeFromList;

  /// No description provided for @clearHistory.
  ///
  /// In es, this message translates to:
  /// **'Borrar historial'**
  String get clearHistory;

  /// No description provided for @filesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 archivo} other{{count} archivos}}'**
  String filesCount(int count);

  /// No description provided for @sendingFiles.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Enviando 1 archivo} other{Enviando {count} archivos}}'**
  String sendingFiles(int count);

  /// No description provided for @sendToDevice.
  ///
  /// In es, this message translates to:
  /// **'Enviar a {device}'**
  String sendToDevice(String device);

  /// No description provided for @chooseDevice.
  ///
  /// In es, this message translates to:
  /// **'Elige un dispositivo'**
  String get chooseDevice;

  /// No description provided for @noDeviceConnected.
  ///
  /// In es, this message translates to:
  /// **'No hay ningún dispositivo conectado'**
  String get noDeviceConnected;

  /// No description provided for @connectToSend.
  ///
  /// In es, this message translates to:
  /// **'Conecta el móvil para enviar archivos'**
  String get connectToSend;

  /// No description provided for @executableBlocked.
  ///
  /// In es, this message translates to:
  /// **'PepoConnect no envía programas hasta que lo permitas en Ajustes'**
  String get executableBlocked;

  /// No description provided for @executableBlockedOne.
  ///
  /// In es, this message translates to:
  /// **'No se ha enviado {file}'**
  String executableBlockedOne(String file);

  /// No description provided for @executableBlockedMany.
  ///
  /// In es, this message translates to:
  /// **'No se han enviado {count} ejecutables'**
  String executableBlockedMany(int count);

  /// No description provided for @executableBlockedBody.
  ///
  /// In es, this message translates to:
  /// **'PepoConnect no envía programas (.exe, .msi, .apk…) hasta que actives «Permitir ejecutables» en Ajustes › Almacenamiento, en este dispositivo y en el que los recibe.'**
  String get executableBlockedBody;

  /// No description provided for @executableOpenSettings.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get executableOpenSettings;

  /// No description provided for @executableRefusedTitle.
  ///
  /// In es, this message translates to:
  /// **'No se ha aceptado {file} de {device}'**
  String executableRefusedTitle(String file, String device);

  /// No description provided for @executableRefusedBody.
  ///
  /// In es, this message translates to:
  /// **'Los ejecutables están desactivados. Actívalos en Ajustes › Almacenamiento si lo esperabas'**
  String get executableRefusedBody;

  /// No description provided for @trRejectedExecutable.
  ///
  /// In es, this message translates to:
  /// **'El otro dispositivo no acepta ejecutables'**
  String get trRejectedExecutable;

  /// No description provided for @speedAndEta.
  ///
  /// In es, this message translates to:
  /// **'{speed}/s · quedan {eta}'**
  String speedAndEta(String speed, String eta);

  /// No description provided for @etaSeconds.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 s} other{{count} s}}'**
  String etaSeconds(int count);

  /// No description provided for @etaMinutes.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 min} other{{count} min}}'**
  String etaMinutes(int count);

  /// No description provided for @galleryOf.
  ///
  /// In es, this message translates to:
  /// **'Galería de {device}'**
  String galleryOf(String device);

  /// No description provided for @allDevices.
  ///
  /// In es, this message translates to:
  /// **'Todos los dispositivos'**
  String get allDevices;

  /// No description provided for @photos.
  ///
  /// In es, this message translates to:
  /// **'Fotos'**
  String get photos;

  /// No description provided for @videos.
  ///
  /// In es, this message translates to:
  /// **'Vídeos'**
  String get videos;

  /// No description provided for @all.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get all;

  /// No description provided for @addToPhone.
  ///
  /// In es, this message translates to:
  /// **'Añadir al móvil'**
  String get addToPhone;

  /// No description provided for @type.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get type;

  /// No description provided for @view.
  ///
  /// In es, this message translates to:
  /// **'Vista'**
  String get view;

  /// No description provided for @viewLarge.
  ///
  /// In es, this message translates to:
  /// **'Grande'**
  String get viewLarge;

  /// No description provided for @viewMedium.
  ///
  /// In es, this message translates to:
  /// **'Mediana'**
  String get viewMedium;

  /// No description provided for @viewSmall.
  ///
  /// In es, this message translates to:
  /// **'Pequeña'**
  String get viewSmall;

  /// No description provided for @squareThumbnails.
  ///
  /// In es, this message translates to:
  /// **'Miniaturas cuadradas'**
  String get squareThumbnails;

  /// No description provided for @selectedCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 seleccionado} other{{count} seleccionados}}'**
  String selectedCount(int count);

  /// No description provided for @selectedCountSize.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 seleccionado ({size})} other{{count} seleccionados ({size})}}'**
  String selectedCountSize(int count, String size);

  /// No description provided for @deleteFromPhone.
  ///
  /// In es, this message translates to:
  /// **'Eliminar del móvil'**
  String get deleteFromPhone;

  /// No description provided for @deleteFromPhoneConfirm.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{¿Eliminar 1 elemento del móvil?} other{¿Eliminar {count} elementos del móvil?}}'**
  String deleteFromPhoneConfirm(int count);

  /// No description provided for @deleteFromPhoneBody.
  ///
  /// In es, this message translates to:
  /// **'Se borran del móvil. La copia del PC, si la hay, no se toca'**
  String get deleteFromPhoneBody;

  /// No description provided for @newLabel.
  ///
  /// In es, this message translates to:
  /// **'Nuevo'**
  String get newLabel;

  /// No description provided for @onPc.
  ///
  /// In es, this message translates to:
  /// **'En el PC'**
  String get onPc;

  /// No description provided for @galleryEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'No hay fotos todavía'**
  String get galleryEmptyTitle;

  /// No description provided for @galleryEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Las fotos que hagas con el móvil aparecerán aquí'**
  String get galleryEmptyBody;

  /// No description provided for @galleryOffline.
  ///
  /// In es, this message translates to:
  /// **'Conecta el móvil para ver la galería'**
  String get galleryOffline;

  /// No description provided for @galleryLoadMore.
  ///
  /// In es, this message translates to:
  /// **'Cargar más'**
  String get galleryLoadMore;

  /// No description provided for @newPhotosCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 foto nueva} other{{count} fotos nuevas}}'**
  String newPhotosCount(int count);

  /// No description provided for @downloadedTo.
  ///
  /// In es, this message translates to:
  /// **'Guardado en {path}'**
  String downloadedTo(String path);

  /// No description provided for @galleryRefreshTooltip.
  ///
  /// In es, this message translates to:
  /// **'Actualizar la galería'**
  String get galleryRefreshTooltip;

  /// No description provided for @galleryItemsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 elemento} other{{count} elementos}}'**
  String galleryItemsCount(int count);

  /// No description provided for @galleryGroupToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get galleryGroupToday;

  /// No description provided for @galleryGroupYesterday.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get galleryGroupYesterday;

  /// No description provided for @galleryGroupThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get galleryGroupThisWeek;

  /// No description provided for @galleryGroupThisMonth.
  ///
  /// In es, this message translates to:
  /// **'Este mes'**
  String get galleryGroupThisMonth;

  /// No description provided for @dismissNew.
  ///
  /// In es, this message translates to:
  /// **'Quitar la marca de nuevo'**
  String get dismissNew;

  /// No description provided for @viewerTitle.
  ///
  /// In es, this message translates to:
  /// **'Visor'**
  String get viewerTitle;

  /// No description provided for @viewerPrevious.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get viewerPrevious;

  /// No description provided for @viewerNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get viewerNext;

  /// No description provided for @viewerZoomIn.
  ///
  /// In es, this message translates to:
  /// **'Acercar'**
  String get viewerZoomIn;

  /// No description provided for @viewerZoomOut.
  ///
  /// In es, this message translates to:
  /// **'Alejar'**
  String get viewerZoomOut;

  /// No description provided for @viewerFit.
  ///
  /// In es, this message translates to:
  /// **'Ajustar a la ventana'**
  String get viewerFit;

  /// No description provided for @viewerActualSize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño real'**
  String get viewerActualSize;

  /// No description provided for @viewerInfo.
  ///
  /// In es, this message translates to:
  /// **'Información'**
  String get viewerInfo;

  /// No description provided for @viewerTakenOn.
  ///
  /// In es, this message translates to:
  /// **'Hecha el {date}'**
  String viewerTakenOn(String date);

  /// No description provided for @viewerDimensions.
  ///
  /// In es, this message translates to:
  /// **'{width} × {height}'**
  String viewerDimensions(int width, int height);

  /// No description provided for @viewerFileSize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño'**
  String get viewerFileSize;

  /// No description provided for @viewerFileName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get viewerFileName;

  /// No description provided for @viewerPlay.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get viewerPlay;

  /// No description provided for @viewerLoadingFull.
  ///
  /// In es, this message translates to:
  /// **'Cargando la foto a tamaño completo…'**
  String get viewerLoadingFull;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get settingsNotifications;

  /// No description provided for @settingsAbout.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get settingsAbout;

  /// No description provided for @keepInBackground.
  ///
  /// In es, this message translates to:
  /// **'Permitir que PepoConnect siga en segundo plano'**
  String get keepInBackground;

  /// No description provided for @keepInBackgroundBody.
  ///
  /// In es, this message translates to:
  /// **'Al cerrar la ventana, la app sigue en la bandeja del sistema'**
  String get keepInBackgroundBody;

  /// No description provided for @startWithWindows.
  ///
  /// In es, this message translates to:
  /// **'Iniciar PepoConnect con Windows'**
  String get startWithWindows;

  /// No description provided for @startWithSystem.
  ///
  /// In es, this message translates to:
  /// **'Iniciar PepoConnect al arrancar'**
  String get startWithSystem;

  /// No description provided for @theme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Según el sistema'**
  String get themeSystem;

  /// No description provided for @downloadsSavedIn.
  ///
  /// In es, this message translates to:
  /// **'Los archivos recibidos se guardan en:'**
  String get downloadsSavedIn;

  /// No description provided for @changeLocation.
  ///
  /// In es, this message translates to:
  /// **'Cambiar ubicación'**
  String get changeLocation;

  /// No description provided for @separateByDevice.
  ///
  /// In es, this message translates to:
  /// **'Separar por dispositivo'**
  String get separateByDevice;

  /// No description provided for @separateByDeviceBody.
  ///
  /// In es, this message translates to:
  /// **'Una carpeta por dispositivo dentro de esa ubicación'**
  String get separateByDeviceBody;

  /// No description provided for @animations.
  ///
  /// In es, this message translates to:
  /// **'Animaciones'**
  String get animations;

  /// No description provided for @animationsBody.
  ///
  /// In es, this message translates to:
  /// **'Desactívalas para ahorrar recursos'**
  String get animationsBody;

  /// No description provided for @autoDownloadPhotos.
  ///
  /// In es, this message translates to:
  /// **'Descargar fotos nuevas automáticamente'**
  String get autoDownloadPhotos;

  /// No description provided for @autoDownloadPhotosBody.
  ///
  /// In es, this message translates to:
  /// **'Cada foto nueva se guarda en el PC sin preguntar'**
  String get autoDownloadPhotosBody;

  /// No description provided for @convertHeic.
  ///
  /// In es, this message translates to:
  /// **'Convertir HEIC a JPEG'**
  String get convertHeic;

  /// No description provided for @convertHeicBody.
  ///
  /// In es, this message translates to:
  /// **'Las fotos del iPhone se guardan como JPEG'**
  String get convertHeicBody;

  /// No description provided for @sharedClipboard.
  ///
  /// In es, this message translates to:
  /// **'Portapapeles compartido'**
  String get sharedClipboard;

  /// No description provided for @sharedClipboardBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que copies en un dispositivo se puede pegar en el otro. En el móvil se envía al abrir PepoConnect, con el tile «Enviar portapapeles» de los ajustes rápidos o con el acceso directo del icono.'**
  String get sharedClipboardBody;

  /// No description provided for @notifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notifications;

  /// No description provided for @notificationsBody.
  ///
  /// In es, this message translates to:
  /// **'Avisos de fotos nuevas y transferencias'**
  String get notificationsBody;

  /// No description provided for @sounds.
  ///
  /// In es, this message translates to:
  /// **'Sonidos'**
  String get sounds;

  /// No description provided for @soundsBody.
  ///
  /// In es, this message translates to:
  /// **'Un sonido corto al terminar una transferencia'**
  String get soundsBody;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Según el sistema'**
  String get languageSystem;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @version.
  ///
  /// In es, this message translates to:
  /// **'Versión {version}'**
  String version(String version);

  /// No description provided for @aboutBody.
  ///
  /// In es, this message translates to:
  /// **'Fotos y archivos entre el móvil y el PC, en tu red local. Nada pasa por internet'**
  String get aboutBody;

  /// No description provided for @allowExecutables.
  ///
  /// In es, this message translates to:
  /// **'Permitir ejecutables'**
  String get allowExecutables;

  /// No description provided for @autoSendPhotos.
  ///
  /// In es, this message translates to:
  /// **'Enviar fotos nuevas al PC automáticamente'**
  String get autoSendPhotos;

  /// No description provided for @autoSendPhotosBody.
  ///
  /// In es, this message translates to:
  /// **'Cada foto que hagas llega al PC al momento'**
  String get autoSendPhotosBody;

  /// No description provided for @backgroundService.
  ///
  /// In es, this message translates to:
  /// **'Mantener la conexión en segundo plano'**
  String get backgroundService;

  /// No description provided for @backgroundServiceBody.
  ///
  /// In es, this message translates to:
  /// **'Necesario para que las fotos lleguen con la app cerrada'**
  String get backgroundServiceBody;

  /// No description provided for @defaultHub.
  ///
  /// In es, this message translates to:
  /// **'PC predeterminado'**
  String get defaultHub;

  /// No description provided for @deviceSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes del dispositivo'**
  String get deviceSettings;

  /// No description provided for @openDownloadsFolder.
  ///
  /// In es, this message translates to:
  /// **'Abrir la carpeta de descargas'**
  String get openDownloadsFolder;

  /// No description provided for @resetSettings.
  ///
  /// In es, this message translates to:
  /// **'Restablecer ajustes'**
  String get resetSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In es, this message translates to:
  /// **'Ajustes guardados'**
  String get settingsSaved;

  /// No description provided for @pairTitle.
  ///
  /// In es, this message translates to:
  /// **'Empareja tu móvil y tu PC'**
  String get pairTitle;

  /// No description provided for @pairSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Los dos deben estar en la misma red Wi-Fi'**
  String get pairSubtitle;

  /// No description provided for @pairStep1.
  ///
  /// In es, this message translates to:
  /// **'Instala PepoConnect en el móvil y toca Añadir PC'**
  String get pairStep1;

  /// No description provided for @pairStep2.
  ///
  /// In es, this message translates to:
  /// **'Escanea este código con el móvil'**
  String get pairStep2;

  /// No description provided for @pairStepNumber.
  ///
  /// In es, this message translates to:
  /// **'Paso {number}'**
  String pairStepNumber(int number);

  /// No description provided for @pairCheckCode.
  ///
  /// In es, this message translates to:
  /// **'Comprueba el código'**
  String get pairCheckCode;

  /// No description provided for @pairCheckCodeBody.
  ///
  /// In es, this message translates to:
  /// **'Confirma que el móvil muestra el mismo código'**
  String get pairCheckCodeBody;

  /// No description provided for @pairConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get pairConfirm;

  /// No description provided for @pairRescan.
  ///
  /// In es, this message translates to:
  /// **'Volver a escanear'**
  String get pairRescan;

  /// No description provided for @pairDone.
  ///
  /// In es, this message translates to:
  /// **'Emparejado'**
  String get pairDone;

  /// No description provided for @pairDoneBody.
  ///
  /// In es, this message translates to:
  /// **'Tu PC y tu móvil ya están conectados'**
  String get pairDoneBody;

  /// No description provided for @pairUseCode.
  ///
  /// In es, this message translates to:
  /// **'Usar código en lugar de QR'**
  String get pairUseCode;

  /// No description provided for @pairUseQr.
  ///
  /// In es, this message translates to:
  /// **'Usar QR'**
  String get pairUseQr;

  /// No description provided for @pairCode.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get pairCode;

  /// No description provided for @pairExpiresIn.
  ///
  /// In es, this message translates to:
  /// **'Caduca en {seconds} s'**
  String pairExpiresIn(int seconds);

  /// No description provided for @pairExpired.
  ///
  /// In es, this message translates to:
  /// **'El código ha caducado'**
  String get pairExpired;

  /// No description provided for @pairNewCode.
  ///
  /// In es, this message translates to:
  /// **'Nuevo código'**
  String get pairNewCode;

  /// No description provided for @pairEnterCode.
  ///
  /// In es, this message translates to:
  /// **'Escribe el código que muestra el PC'**
  String get pairEnterCode;

  /// No description provided for @pairScanQr.
  ///
  /// In es, this message translates to:
  /// **'Escanea el QR del PC'**
  String get pairScanQr;

  /// No description provided for @pairFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo emparejar'**
  String get pairFailed;

  /// No description provided for @pairFailedBody.
  ///
  /// In es, this message translates to:
  /// **'Comprueba el código y que los dos estén en la misma red'**
  String get pairFailedBody;

  /// No description provided for @pairCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar emparejamiento'**
  String get pairCancel;

  /// No description provided for @pairSearching.
  ///
  /// In es, this message translates to:
  /// **'Buscando PCs en la red…'**
  String get pairSearching;

  /// No description provided for @pairFound.
  ///
  /// In es, this message translates to:
  /// **'PCs encontrados'**
  String get pairFound;

  /// No description provided for @pairManual.
  ///
  /// In es, this message translates to:
  /// **'Escribir la dirección a mano'**
  String get pairManual;

  /// No description provided for @pairAddress.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get pairAddress;

  /// No description provided for @pairPort.
  ///
  /// In es, this message translates to:
  /// **'Puerto'**
  String get pairPort;

  /// No description provided for @pairConnecting.
  ///
  /// In es, this message translates to:
  /// **'Conectando con {device}…'**
  String pairConnecting(String device);

  /// No description provided for @pairingWith.
  ///
  /// In es, this message translates to:
  /// **'Emparejando con {device}'**
  String pairingWith(String device);

  /// No description provided for @pairRequestTitle.
  ///
  /// In es, this message translates to:
  /// **'{device} quiere emparejarse'**
  String pairRequestTitle(String device);

  /// No description provided for @pairCameraPermission.
  ///
  /// In es, this message translates to:
  /// **'PepoConnect necesita la cámara para leer el QR'**
  String get pairCameraPermission;

  /// No description provided for @mobileReceived.
  ///
  /// In es, this message translates to:
  /// **'Recibidos'**
  String get mobileReceived;

  /// No description provided for @mobileSent.
  ///
  /// In es, this message translates to:
  /// **'Enviados'**
  String get mobileSent;

  /// No description provided for @mobileSendToPc.
  ///
  /// In es, this message translates to:
  /// **'Enviar al PC'**
  String get mobileSendToPc;

  /// No description provided for @mobileFiles.
  ///
  /// In es, this message translates to:
  /// **'Archivos'**
  String get mobileFiles;

  /// No description provided for @mobileGallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get mobileGallery;

  /// No description provided for @mobileClipboard.
  ///
  /// In es, this message translates to:
  /// **'Portapapeles'**
  String get mobileClipboard;

  /// No description provided for @mobileCamera.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get mobileCamera;

  /// No description provided for @mobileNoPc.
  ///
  /// In es, this message translates to:
  /// **'Sin PC conectado'**
  String get mobileNoPc;

  /// No description provided for @mobileTapToChangePc.
  ///
  /// In es, this message translates to:
  /// **'Toca para cambiar de PC'**
  String get mobileTapToChangePc;

  /// No description provided for @mobileShareVia.
  ///
  /// In es, this message translates to:
  /// **'Enviar con PepoConnect'**
  String get mobileShareVia;

  /// No description provided for @mobileReceivedEmpty.
  ///
  /// In es, this message translates to:
  /// **'Los archivos que te envíe el PC aparecerán aquí'**
  String get mobileReceivedEmpty;

  /// No description provided for @mobileSentEmpty.
  ///
  /// In es, this message translates to:
  /// **'Lo que envíes al PC aparecerá aquí'**
  String get mobileSentEmpty;

  /// No description provided for @mobileAddPc.
  ///
  /// In es, this message translates to:
  /// **'Añadir PC'**
  String get mobileAddPc;

  /// No description provided for @mobileServiceNotification.
  ///
  /// In es, this message translates to:
  /// **'PepoConnect está conectado con {device}'**
  String mobileServiceNotification(String device);

  /// No description provided for @mobileServiceIdle.
  ///
  /// In es, this message translates to:
  /// **'PepoConnect espera al PC'**
  String get mobileServiceIdle;

  /// No description provided for @activityTitle.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get activityTitle;

  /// No description provided for @activityNewPhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto nueva en {device}'**
  String activityNewPhoto(String device);

  /// No description provided for @activityNewVideo.
  ///
  /// In es, this message translates to:
  /// **'Vídeo nuevo en {device}'**
  String activityNewVideo(String device);

  /// No description provided for @activityReceived.
  ///
  /// In es, this message translates to:
  /// **'Recibido {file} de {device}'**
  String activityReceived(String file, String device);

  /// No description provided for @activitySent.
  ///
  /// In es, this message translates to:
  /// **'Enviado {file} a {device}'**
  String activitySent(String file, String device);

  /// No description provided for @activityFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo transferir {file}'**
  String activityFailed(String file);

  /// No description provided for @activityConnected.
  ///
  /// In es, this message translates to:
  /// **'{device} conectado'**
  String activityConnected(String device);

  /// No description provided for @activityDisconnected.
  ///
  /// In es, this message translates to:
  /// **'{device} desconectado'**
  String activityDisconnected(String device);

  /// No description provided for @activityPaired.
  ///
  /// In es, this message translates to:
  /// **'{device} emparejado'**
  String activityPaired(String device);

  /// No description provided for @activityForgotten.
  ///
  /// In es, this message translates to:
  /// **'{device} quitado'**
  String activityForgotten(String device);

  /// No description provided for @activityClipboard.
  ///
  /// In es, this message translates to:
  /// **'Texto copiado de {device}'**
  String activityClipboard(String device);

  /// No description provided for @activityEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin actividad reciente'**
  String get activityEmpty;

  /// No description provided for @markAllRead.
  ///
  /// In es, this message translates to:
  /// **'Marcar todo como leído'**
  String get markAllRead;

  /// No description provided for @unreadCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 sin leer} other{{count} sin leer}}'**
  String unreadCount(int count);

  /// No description provided for @activityPanelShow.
  ///
  /// In es, this message translates to:
  /// **'Mostrar actividad'**
  String get activityPanelShow;

  /// No description provided for @activityPanelHide.
  ///
  /// In es, this message translates to:
  /// **'Ocultar actividad'**
  String get activityPanelHide;

  /// No description provided for @toastNewPhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto nueva'**
  String get toastNewPhoto;

  /// No description provided for @toastNewVideo.
  ///
  /// In es, this message translates to:
  /// **'Vídeo nuevo'**
  String get toastNewVideo;

  /// No description provided for @toastNewItems.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 elemento nuevo} other{{count} elementos nuevos}}'**
  String toastNewItems(int count);

  /// No description provided for @toastNewPhotos.
  ///
  /// In es, this message translates to:
  /// **'{count} fotos nuevas'**
  String toastNewPhotos(int count);

  /// No description provided for @toastView.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get toastView;

  /// No description provided for @toastSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardado en el PC'**
  String get toastSaved;

  /// No description provided for @toastCopied.
  ///
  /// In es, this message translates to:
  /// **'Copiado'**
  String get toastCopied;

  /// No description provided for @toastSentTo.
  ///
  /// In es, this message translates to:
  /// **'Enviado a {device}'**
  String toastSentTo(String device);

  /// No description provided for @toastReceivedFrom.
  ///
  /// In es, this message translates to:
  /// **'Recibido de {device}'**
  String toastReceivedFrom(String device);

  /// No description provided for @toastDeviceConnected.
  ///
  /// In es, this message translates to:
  /// **'{device} conectado'**
  String toastDeviceConnected(String device);

  /// No description provided for @toastDeviceOffline.
  ///
  /// In es, this message translates to:
  /// **'{device} sin conexión'**
  String toastDeviceOffline(String device);

  /// No description provided for @toastDeleted.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 elemento eliminado del móvil} other{{count} elementos eliminados del móvil}}'**
  String toastDeleted(int count);

  /// No description provided for @toastClipboardReceived.
  ///
  /// In es, this message translates to:
  /// **'Texto copiado desde {device}'**
  String toastClipboardReceived(String device);

  /// No description provided for @toastClipboardSent.
  ///
  /// In es, this message translates to:
  /// **'Portapapeles enviado a {device}'**
  String toastClipboardSent(String device);

  /// No description provided for @clipboardEmpty.
  ///
  /// In es, this message translates to:
  /// **'El portapapeles está vacío'**
  String get clipboardEmpty;

  /// No description provided for @clipboardNoTarget.
  ///
  /// In es, this message translates to:
  /// **'Ningún PC conectado con el portapapeles compartido'**
  String get clipboardNoTarget;

  /// No description provided for @clipboardQueued.
  ///
  /// In es, this message translates to:
  /// **'Sin PC conectado: se enviará al conectar'**
  String get clipboardQueued;

  /// No description provided for @toastUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get toastUndo;

  /// No description provided for @errorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Algo ha fallado'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión con el dispositivo'**
  String get errorNetwork;

  /// No description provided for @errorNotPaired.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo ya no está emparejado'**
  String get errorNotPaired;

  /// No description provided for @errorFileMissing.
  ///
  /// In es, this message translates to:
  /// **'El archivo ya no existe'**
  String get errorFileMissing;

  /// No description provided for @errorNoSpace.
  ///
  /// In es, this message translates to:
  /// **'No queda espacio en el disco'**
  String get errorNoSpace;

  /// No description provided for @errorPermission.
  ///
  /// In es, this message translates to:
  /// **'PepoConnect no tiene permiso para acceder a las fotos'**
  String get errorPermission;

  /// No description provided for @errorPermissionAction.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get errorPermissionAction;

  /// No description provided for @errorTimeout.
  ///
  /// In es, this message translates to:
  /// **'El dispositivo no responde'**
  String get errorTimeout;

  /// No description provided for @errorCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get errorCancelled;

  /// No description provided for @errorTryAgain.
  ///
  /// In es, this message translates to:
  /// **'Inténtalo de nuevo'**
  String get errorTryAgain;

  /// No description provided for @errorFolderMissing.
  ///
  /// In es, this message translates to:
  /// **'La carpeta de descargas no existe'**
  String get errorFolderMissing;

  /// No description provided for @errorCode.
  ///
  /// In es, this message translates to:
  /// **'Código incorrecto'**
  String get errorCode;

  /// No description provided for @errorDetails.
  ///
  /// In es, this message translates to:
  /// **'Detalles'**
  String get errorDetails;

  /// No description provided for @errorCopyDetails.
  ///
  /// In es, this message translates to:
  /// **'Copiar detalles'**
  String get errorCopyDetails;

  /// No description provided for @onboardingTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu móvil, en el PC'**
  String get onboardingTitle;

  /// No description provided for @onboardingBody.
  ///
  /// In es, this message translates to:
  /// **'Las fotos que hagas aparecen aquí al instante. Y puedes enviar archivos en los dos sentidos'**
  String get onboardingBody;

  /// No description provided for @onboardingStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get onboardingStart;

  /// No description provided for @onboardingPairLater.
  ///
  /// In es, this message translates to:
  /// **'Emparejar más tarde'**
  String get onboardingPairLater;

  /// No description provided for @onboardingNamePrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo se llama este PC?'**
  String get onboardingNamePrompt;

  /// No description provided for @onboardingFolderPrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde guardamos lo que llegue?'**
  String get onboardingFolderPrompt;

  /// No description provided for @onboardingLocalOnly.
  ///
  /// In es, this message translates to:
  /// **'Todo va por tu red local. Nada sale a internet'**
  String get onboardingLocalOnly;

  /// No description provided for @shortcutsTitle.
  ///
  /// In es, this message translates to:
  /// **'Atajos de teclado'**
  String get shortcutsTitle;

  /// No description provided for @shortcutSections.
  ///
  /// In es, this message translates to:
  /// **'Ctrl+1 a Ctrl+4 cambian de sección'**
  String get shortcutSections;

  /// No description provided for @shortcutSettings.
  ///
  /// In es, this message translates to:
  /// **'Ctrl+, abre Ajustes'**
  String get shortcutSettings;

  /// No description provided for @shortcutRefresh.
  ///
  /// In es, this message translates to:
  /// **'F5 actualiza'**
  String get shortcutRefresh;

  /// No description provided for @shortcutEscape.
  ///
  /// In es, this message translates to:
  /// **'Esc cierra menús y selecciones'**
  String get shortcutEscape;

  /// No description provided for @trShareWithAnyone.
  ///
  /// In es, this message translates to:
  /// **'Compartir con cualquiera'**
  String get trShareWithAnyone;

  /// No description provided for @trGuestSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get trGuestSend;

  /// No description provided for @trGuestReceive.
  ///
  /// In es, this message translates to:
  /// **'Recibir'**
  String get trGuestReceive;

  /// No description provided for @trGuestSendBody.
  ///
  /// In es, this message translates to:
  /// **'Quien abra el enlace podrá descargar estos archivos desde el navegador, sin instalar nada'**
  String get trGuestSendBody;

  /// No description provided for @trGuestReceiveBody.
  ///
  /// In es, this message translates to:
  /// **'Quien abra el enlace podrá enviarte archivos desde el navegador'**
  String get trGuestReceiveBody;

  /// No description provided for @trGuestNoFiles.
  ///
  /// In es, this message translates to:
  /// **'Añade al menos un archivo'**
  String get trGuestNoFiles;

  /// No description provided for @trGuestMessage.
  ///
  /// In es, this message translates to:
  /// **'Mensaje (opcional)'**
  String get trGuestMessage;

  /// No description provided for @trGuestCreateLink.
  ///
  /// In es, this message translates to:
  /// **'Crear enlace'**
  String get trGuestCreateLink;

  /// No description provided for @trGuestReadyTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus archivos están listos'**
  String get trGuestReadyTitle;

  /// No description provided for @trGuestReceiveReadyTitle.
  ///
  /// In es, this message translates to:
  /// **'Listo para recibir'**
  String get trGuestReceiveReadyTitle;

  /// No description provided for @trGuestScanHint.
  ///
  /// In es, this message translates to:
  /// **'Escanea el QR o abre el enlace desde un dispositivo en la misma red Wi-Fi'**
  String get trGuestScanHint;

  /// No description provided for @trGuestCopyLink.
  ///
  /// In es, this message translates to:
  /// **'Copiar enlace'**
  String get trGuestCopyLink;

  /// No description provided for @trGuestExpiresIn.
  ///
  /// In es, this message translates to:
  /// **'El enlace caduca en {time}'**
  String trGuestExpiresIn(String time);

  /// No description provided for @trGuestExpired.
  ///
  /// In es, this message translates to:
  /// **'El enlace ha caducado'**
  String get trGuestExpired;

  /// No description provided for @trGuestNewLink.
  ///
  /// In es, this message translates to:
  /// **'Crear otro enlace'**
  String get trGuestNewLink;

  /// No description provided for @trGuestWaiting.
  ///
  /// In es, this message translates to:
  /// **'Nadie ha abierto el enlace todavía'**
  String get trGuestWaiting;

  /// No description provided for @trGuestOpenedBy.
  ///
  /// In es, this message translates to:
  /// **'Abierto por {remote}'**
  String trGuestOpenedBy(String remote);

  /// No description provided for @trGuestDownloaded.
  ///
  /// In es, this message translates to:
  /// **'Descargado {file}'**
  String trGuestDownloaded(String file);

  /// No description provided for @trGuestReceived.
  ///
  /// In es, this message translates to:
  /// **'Recibido {file}'**
  String trGuestReceived(String file);

  /// No description provided for @trGuestUploadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo recibir {file}'**
  String trGuestUploadFailed(String file);

  /// No description provided for @trGuestNoAddress.
  ///
  /// In es, this message translates to:
  /// **'No se ha encontrado ninguna red local'**
  String get trGuestNoAddress;

  /// No description provided for @trGuestFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el enlace'**
  String get trGuestFailed;

  /// No description provided for @trHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get trHistory;

  /// No description provided for @trSendFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar'**
  String get trSendFailed;

  /// No description provided for @trDroppedNothing.
  ///
  /// In es, this message translates to:
  /// **'No hay archivos que enviar'**
  String get trDroppedNothing;

  /// No description provided for @trNoPcConnected.
  ///
  /// In es, this message translates to:
  /// **'Conecta un PC para enviar archivos'**
  String get trNoPcConnected;

  /// No description provided for @galYourPhone.
  ///
  /// In es, this message translates to:
  /// **'Tu móvil'**
  String get galYourPhone;

  /// No description provided for @galYourTablet.
  ///
  /// In es, this message translates to:
  /// **'Tu tablet'**
  String get galYourTablet;

  /// No description provided for @galYourPc.
  ///
  /// In es, this message translates to:
  /// **'Tu PC'**
  String get galYourPc;

  /// No description provided for @galFullThumbnails.
  ///
  /// In es, this message translates to:
  /// **'Miniaturas completas'**
  String get galFullThumbnails;

  /// No description provided for @galTileSize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño de las miniaturas'**
  String get galTileSize;

  /// No description provided for @galSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión'**
  String get galSession;

  /// No description provided for @galSessionTooltip.
  ///
  /// In es, this message translates to:
  /// **'Modo sesión: el visor salta a cada foto nueva'**
  String get galSessionTooltip;

  /// No description provided for @galSavedCopies.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 archivo guardado en {folder}} other{{count} archivos guardados en {folder}}}'**
  String galSavedCopies(int count, String folder);

  /// No description provided for @galSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar {file}'**
  String galSaveFailed(String file);

  /// No description provided for @galDownloadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar {file}'**
  String galDownloadFailed(String file);

  /// No description provided for @galDeleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar del móvil'**
  String get galDeleteFailed;

  /// No description provided for @galSelectGroup.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar {group}'**
  String galSelectGroup(String group);

  /// No description provided for @galSelectNew.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar nuevas'**
  String get galSelectNew;

  /// No description provided for @galDownloadStarted.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Descargando 1 elemento} other{Descargando {count} elementos}}'**
  String galDownloadStarted(int count);

  /// No description provided for @galOfflineBody.
  ///
  /// In es, this message translates to:
  /// **'Las fotos aparecerán en cuanto se conecte'**
  String get galOfflineBody;

  /// No description provided for @vwDevice.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo'**
  String get vwDevice;

  /// No description provided for @vwDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get vwDate;

  /// No description provided for @vwResolution.
  ///
  /// In es, this message translates to:
  /// **'Resolución'**
  String get vwResolution;

  /// No description provided for @vwDownloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando…'**
  String get vwDownloading;

  /// No description provided for @vwSessionCounter.
  ///
  /// In es, this message translates to:
  /// **'Sesión · {photos, plural, =1{1 foto} other{{photos} fotos}} · {downloaded, plural, =1{1 descargada} other{{downloaded} descargadas}}'**
  String vwSessionCounter(int photos, int downloaded);

  /// No description provided for @vwSessionWaiting.
  ///
  /// In es, this message translates to:
  /// **'Esperando fotos nuevas…'**
  String get vwSessionWaiting;

  /// No description provided for @vwSessionHint.
  ///
  /// In es, this message translates to:
  /// **'Espacio: descargar · Esc: salir'**
  String get vwSessionHint;

  /// No description provided for @vwSessionExit.
  ///
  /// In es, this message translates to:
  /// **'Salir de la sesión'**
  String get vwSessionExit;

  /// No description provided for @vwPosition.
  ///
  /// In es, this message translates to:
  /// **'{index} de {total}'**
  String vwPosition(int index, int total);

  /// No description provided for @vwNotFound.
  ///
  /// In es, this message translates to:
  /// **'Este elemento ya no está en la galería'**
  String get vwNotFound;

  /// No description provided for @vwPreviewFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la vista previa'**
  String get vwPreviewFailed;

  /// No description provided for @vwVideoOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el vídeo'**
  String get vwVideoOpenFailed;

  /// No description provided for @vwStateOnPhone.
  ///
  /// In es, this message translates to:
  /// **'Solo en el móvil'**
  String get vwStateOnPhone;

  /// No description provided for @setStorage.
  ///
  /// In es, this message translates to:
  /// **'Almacenamiento'**
  String get setStorage;

  /// No description provided for @setThisPhone.
  ///
  /// In es, this message translates to:
  /// **'Este móvil'**
  String get setThisPhone;

  /// No description provided for @setRenameDeviceTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar el nombre del dispositivo'**
  String get setRenameDeviceTitle;

  /// No description provided for @setForgetConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres olvidar \"{device}\"?'**
  String setForgetConfirm(String device);

  /// No description provided for @setForgetBody.
  ///
  /// In es, this message translates to:
  /// **'Tendrás que emparejarlo de nuevo'**
  String get setForgetBody;

  /// No description provided for @setLastConnection.
  ///
  /// In es, this message translates to:
  /// **'Última conexión: {when}'**
  String setLastConnection(String when);

  /// No description provided for @setThemeBody.
  ///
  /// In es, this message translates to:
  /// **'Elige cómo se ve PepoConnect'**
  String get setThemeBody;

  /// No description provided for @setStartWithSystem.
  ///
  /// In es, this message translates to:
  /// **'Iniciar PepoConnect con el sistema'**
  String get setStartWithSystem;

  /// No description provided for @setStartWithSystemBody.
  ///
  /// In es, this message translates to:
  /// **'Arranca minimizado, en la bandeja'**
  String get setStartWithSystemBody;

  /// No description provided for @setSeparateByDeviceBody.
  ///
  /// In es, this message translates to:
  /// **'Crea una subcarpeta por cada móvil'**
  String get setSeparateByDeviceBody;

  /// No description provided for @setAllowExecutablesBody.
  ///
  /// In es, this message translates to:
  /// **'Desactivado, no se envían ni se reciben programas (.exe, .msi, .apk…). Actívalo en los dos dispositivos solo si lo necesitas'**
  String get setAllowExecutablesBody;

  /// No description provided for @setResetLocation.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get setResetLocation;

  /// No description provided for @setDefaultLocation.
  ///
  /// In es, this message translates to:
  /// **'Carpeta predeterminada'**
  String get setDefaultLocation;

  /// No description provided for @setChooseFolder.
  ///
  /// In es, this message translates to:
  /// **'Elige dónde guardar los archivos recibidos'**
  String get setChooseFolder;

  /// No description provided for @setBackgroundService.
  ///
  /// In es, this message translates to:
  /// **'Servicio en segundo plano'**
  String get setBackgroundService;

  /// No description provided for @setBackgroundServiceBody.
  ///
  /// In es, this message translates to:
  /// **'Mantiene la conexión con el PC'**
  String get setBackgroundServiceBody;

  /// No description provided for @setBackgroundServiceBodyIos.
  ///
  /// In es, this message translates to:
  /// **'Mantiene PepoConnect en marcha con la app cerrada para que las fotos salgan solas. Gasta algo de batería.'**
  String get setBackgroundServiceBodyIos;

  /// No description provided for @setBackgroundEngine.
  ///
  /// In es, this message translates to:
  /// **'Estado del segundo plano'**
  String get setBackgroundEngine;

  /// No description provided for @setBackgroundEngineOn.
  ///
  /// In es, this message translates to:
  /// **'Activo desde hace {uptime}'**
  String setBackgroundEngineOn(String uptime);

  /// No description provided for @setBackgroundEngineStarting.
  ///
  /// In es, this message translates to:
  /// **'Arrancando…'**
  String get setBackgroundEngineStarting;

  /// No description provided for @setBackgroundEngineRecovering.
  ///
  /// In es, this message translates to:
  /// **'Recuperándose…'**
  String get setBackgroundEngineRecovering;

  /// No description provided for @setBackgroundEngineOff.
  ///
  /// In es, this message translates to:
  /// **'Parado'**
  String get setBackgroundEngineOff;

  /// No description provided for @setBackgroundEngineBody.
  ///
  /// In es, this message translates to:
  /// **'Si cierras PepoConnect desde el selector de apps, deja de funcionar hasta que la vuelvas a abrir.'**
  String get setBackgroundEngineBody;

  /// No description provided for @setPermissionPhotosLimited.
  ///
  /// In es, this message translates to:
  /// **'Acceso limitado: PepoConnect solo ve las fotos que elegiste, así que las nuevas no se envían.'**
  String get setPermissionPhotosLimited;

  /// No description provided for @setOpenSystemSettings.
  ///
  /// In es, this message translates to:
  /// **'Abrir Ajustes'**
  String get setOpenSystemSettings;

  /// No description provided for @setAutoSendPhotos.
  ///
  /// In es, this message translates to:
  /// **'Enviar fotos nuevas automáticamente'**
  String get setAutoSendPhotos;

  /// No description provided for @setAutoSendPhotosBody.
  ///
  /// In es, this message translates to:
  /// **'Cada foto que hagas llega al PC principal al momento'**
  String get setAutoSendPhotosBody;

  /// No description provided for @setDefaultHub.
  ///
  /// In es, this message translates to:
  /// **'PC principal'**
  String get setDefaultHub;

  /// No description provided for @setDefaultHubBody.
  ///
  /// In es, this message translates to:
  /// **'Recibe las fotos nuevas y lo que compartas'**
  String get setDefaultHubBody;

  /// No description provided for @setDefaultHubNone.
  ///
  /// In es, this message translates to:
  /// **'Sin elegir'**
  String get setDefaultHubNone;

  /// No description provided for @setDefaultHubRequired.
  ///
  /// In es, this message translates to:
  /// **'Elige primero un PC principal'**
  String get setDefaultHubRequired;

  /// No description provided for @setPermissions.
  ///
  /// In es, this message translates to:
  /// **'Permisos'**
  String get setPermissions;

  /// No description provided for @setPermissionPhotos.
  ///
  /// In es, this message translates to:
  /// **'Fotos y vídeos'**
  String get setPermissionPhotos;

  /// No description provided for @setPermissionPhotosBody.
  ///
  /// In es, this message translates to:
  /// **'Para mostrar la galería en el PC'**
  String get setPermissionPhotosBody;

  /// No description provided for @setPermissionNotificationsBody.
  ///
  /// In es, this message translates to:
  /// **'Para avisar de lo que llega y sale'**
  String get setPermissionNotificationsBody;

  /// No description provided for @setPermissionBattery.
  ///
  /// In es, this message translates to:
  /// **'Sin restricción de batería'**
  String get setPermissionBattery;

  /// No description provided for @setPermissionBatteryBody.
  ///
  /// In es, this message translates to:
  /// **'Para no perder la conexión con la pantalla apagada'**
  String get setPermissionBatteryBody;

  /// No description provided for @setAllow.
  ///
  /// In es, this message translates to:
  /// **'Permitir'**
  String get setAllow;

  /// No description provided for @setGranted.
  ///
  /// In es, this message translates to:
  /// **'Concedido'**
  String get setGranted;

  /// No description provided for @setDeviceId.
  ///
  /// In es, this message translates to:
  /// **'ID de este dispositivo'**
  String get setDeviceId;

  /// No description provided for @setFastLane.
  ///
  /// In es, this message translates to:
  /// **'Motor rápido'**
  String get setFastLane;

  /// No description provided for @setFastLaneOn.
  ///
  /// In es, this message translates to:
  /// **'Activo · Rust, AES-256-GCM, puerto {port}'**
  String setFastLaneOn(int port);

  /// No description provided for @setFastLaneOff.
  ///
  /// In es, this message translates to:
  /// **'No disponible en este dispositivo; se usan los canales TLS'**
  String get setFastLaneOff;

  /// No description provided for @setCheckUpdates.
  ///
  /// In es, this message translates to:
  /// **'Comprobar actualizaciones'**
  String get setCheckUpdates;

  /// No description provided for @setUpToDate.
  ///
  /// In es, this message translates to:
  /// **'Tienes la última versión'**
  String get setUpToDate;

  /// No description provided for @setUpdateAvailable.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión nueva: {version}'**
  String setUpdateAvailable(String version);

  /// No description provided for @setUpdateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo comprobar'**
  String get setUpdateFailed;

  /// No description provided for @setUpdateFailedBody.
  ///
  /// In es, this message translates to:
  /// **'Revisa la conexión a internet e inténtalo más tarde'**
  String get setUpdateFailedBody;

  /// No description provided for @setViewOnGitHub.
  ///
  /// In es, this message translates to:
  /// **'Ver en GitHub'**
  String get setViewOnGitHub;

  /// No description provided for @setSourceCode.
  ///
  /// In es, this message translates to:
  /// **'Código fuente en GitHub'**
  String get setSourceCode;

  /// No description provided for @setResetConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Restablecer los ajustes?'**
  String get setResetConfirm;

  /// No description provided for @setResetBody.
  ///
  /// In es, this message translates to:
  /// **'Vuelven a los valores iniciales. Los dispositivos emparejados se conservan'**
  String get setResetBody;

  /// No description provided for @setResetDone.
  ///
  /// In es, this message translates to:
  /// **'Ajustes restablecidos'**
  String get setResetDone;

  /// No description provided for @onbHowTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo quieres usar PepoConnect?'**
  String get onbHowTitle;

  /// No description provided for @onbConnectPhone.
  ///
  /// In es, this message translates to:
  /// **'Conecta tu móvil'**
  String get onbConnectPhone;

  /// No description provided for @onbConnectPhoneBody.
  ///
  /// In es, this message translates to:
  /// **'Mira sus fotos y pásate archivos'**
  String get onbConnectPhoneBody;

  /// No description provided for @onbAddPhone.
  ///
  /// In es, this message translates to:
  /// **'Añadir móvil'**
  String get onbAddPhone;

  /// No description provided for @onbShareTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparte con cualquiera'**
  String get onbShareTitle;

  /// No description provided for @onbShareBody.
  ///
  /// In es, this message translates to:
  /// **'Envía o recibe archivos con un enlace, sin instalar nada'**
  String get onbShareBody;

  /// No description provided for @onbSkipForNow.
  ///
  /// In es, this message translates to:
  /// **'Saltar por ahora'**
  String get onbSkipForNow;

  /// No description provided for @onbSlide1.
  ///
  /// In es, this message translates to:
  /// **'Pasa fotos y archivos entre este móvil y tu PC'**
  String get onbSlide1;

  /// No description provided for @onbSlide2.
  ///
  /// In es, this message translates to:
  /// **'Cada foto nueva aparece en el PC al momento'**
  String get onbSlide2;

  /// No description provided for @onbSlide3.
  ///
  /// In es, this message translates to:
  /// **'Todo por tu red, cifrado, sin cuentas'**
  String get onbSlide3;

  /// No description provided for @onbPermissionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Permisos necesarios'**
  String get onbPermissionsTitle;

  /// No description provided for @onbPermissionsBody.
  ///
  /// In es, this message translates to:
  /// **'PepoConnect los necesita para seguir funcionando con la pantalla apagada'**
  String get onbPermissionsBody;

  /// No description provided for @onbPermissionsSkipWarning.
  ///
  /// In es, this message translates to:
  /// **'Sin ellos, las fotos no llegarán solas al PC'**
  String get onbPermissionsSkipWarning;

  /// No description provided for @onbContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get onbContinue;

  /// No description provided for @onbPageOf.
  ///
  /// In es, this message translates to:
  /// **'Página {current} de {total}'**
  String onbPageOf(int current, int total);

  /// No description provided for @pairInstallTitle.
  ///
  /// In es, this message translates to:
  /// **'Instala PepoConnect en el móvil'**
  String get pairInstallTitle;

  /// No description provided for @pairDownloadApp.
  ///
  /// In es, this message translates to:
  /// **'Descargar la app'**
  String get pairDownloadApp;

  /// No description provided for @pairScanStep.
  ///
  /// In es, this message translates to:
  /// **'Abre la app y escanea este código'**
  String get pairScanStep;

  /// No description provided for @pairExpiresInTime.
  ///
  /// In es, this message translates to:
  /// **'Caduca en {time}'**
  String pairExpiresInTime(String time);

  /// No description provided for @pairGenerateAnother.
  ///
  /// In es, this message translates to:
  /// **'Generar otro código'**
  String get pairGenerateAnother;

  /// No description provided for @pairOtherPc.
  ///
  /// In es, this message translates to:
  /// **'Conectar con otro PC'**
  String get pairOtherPc;

  /// No description provided for @pairYourPc.
  ///
  /// In es, this message translates to:
  /// **'Tu PC: {address}'**
  String pairYourPc(String address);

  /// No description provided for @pairCodeHint.
  ///
  /// In es, this message translates to:
  /// **'Escríbelo en el otro PC en Emparejar › Introducir código'**
  String get pairCodeHint;

  /// No description provided for @pairEnterCodeTitle.
  ///
  /// In es, this message translates to:
  /// **'Introducir código'**
  String get pairEnterCodeTitle;

  /// No description provided for @pairManualAddress.
  ///
  /// In es, this message translates to:
  /// **'Dirección del PC (IP:puerto)'**
  String get pairManualAddress;

  /// No description provided for @pairConnect.
  ///
  /// In es, this message translates to:
  /// **'Emparejar'**
  String get pairConnect;

  /// No description provided for @pairSelectPc.
  ///
  /// In es, this message translates to:
  /// **'Elige el PC'**
  String get pairSelectPc;

  /// No description provided for @pairScanTitle.
  ///
  /// In es, this message translates to:
  /// **'Escanea el código del PC'**
  String get pairScanTitle;

  /// No description provided for @pairScanHint.
  ///
  /// In es, this message translates to:
  /// **'Abre PepoConnect en el PC y ve a Añadir dispositivo'**
  String get pairScanHint;

  /// No description provided for @pairEnterManually.
  ///
  /// In es, this message translates to:
  /// **'Introducir a mano'**
  String get pairEnterManually;

  /// No description provided for @pairPasteLink.
  ///
  /// In es, this message translates to:
  /// **'Pega aquí el enlace pepoconnect://…'**
  String get pairPasteLink;

  /// No description provided for @pairPairing.
  ///
  /// In es, this message translates to:
  /// **'Emparejando…'**
  String get pairPairing;

  /// No description provided for @pairTorch.
  ///
  /// In es, this message translates to:
  /// **'Linterna'**
  String get pairTorch;

  /// No description provided for @pairLinkExpired.
  ///
  /// In es, this message translates to:
  /// **'El enlace ha caducado. Genera otro código en el PC'**
  String get pairLinkExpired;

  /// No description provided for @pairNotACode.
  ///
  /// In es, this message translates to:
  /// **'Eso no es un código de PepoConnect'**
  String get pairNotACode;

  /// No description provided for @pairWrongCode.
  ///
  /// In es, this message translates to:
  /// **'Código incorrecto. Comprueba los seis dígitos'**
  String get pairWrongCode;

  /// No description provided for @pairPcNotFound.
  ///
  /// In es, this message translates to:
  /// **'No se encuentra el PC. Comprueba que los dos están en la misma red Wi-Fi'**
  String get pairPcNotFound;

  /// No description provided for @pairIdentityChanged.
  ///
  /// In es, this message translates to:
  /// **'La identidad del PC ha cambiado. Vuelve a buscarlo'**
  String get pairIdentityChanged;

  /// No description provided for @pairCameraDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin acceso a la cámara'**
  String get pairCameraDenied;

  /// No description provided for @pairAddressInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe una dirección válida, por ejemplo 192.168.1.20:47473'**
  String get pairAddressInvalid;

  /// No description provided for @pairCodeInvalid.
  ///
  /// In es, this message translates to:
  /// **'El código tiene seis dígitos'**
  String get pairCodeInvalid;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
