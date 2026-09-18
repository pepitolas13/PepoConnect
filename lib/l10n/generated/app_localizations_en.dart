// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get updateNotifications => 'Update notifications';

  @override
  String get updateNotificationsBody =>
      'Show a prompt when a new version is available. Daily update checks continue even when this is off.';

  @override
  String get updateDailyBody =>
      'We check every 24 hours while PepoConnect is running, including in the tray, and when you reopen it if a check is due.';

  @override
  String get updateInstall => 'Update';

  @override
  String get updateContinue => 'Continue installation';

  @override
  String get updateLater => 'Not now';

  @override
  String get updateDontNotify => 'Don\'t show update notifications again';

  @override
  String get updateDesktopBody =>
      'The new version will be downloaded and verified. PepoConnect will restart to install it, keeping your settings and devices.';

  @override
  String get updateAndroidBody =>
      'The app will download and verify the update. Android will ask you to confirm installation.';

  @override
  String get updateFlatpakBody =>
      'The update will be downloaded and verified. Confirm installation in your software manager, then reopen PepoConnect.';

  @override
  String get updateIosBody =>
      'This iPhone version is installed with AltStore or Sideloadly. iOS cannot let this unsigned package update itself: install the new version using the same account to keep your data.';

  @override
  String get updateUnavailableBody =>
      'A compatible, verifiable package is not available for this installation yet. You can view the release and its installation instructions.';

  @override
  String get updateInstructions => 'View instructions';

  @override
  String get updateDetails => 'What\'s new';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String get updateVerifying => 'Verifying download…';

  @override
  String get updateInstalling => 'Preparing installation…';

  @override
  String get updateCancelDownload => 'Cancel download';

  @override
  String get updatePermissionBody =>
      'Allow PepoConnect to install apps in Android\'s settings. Installation will continue automatically when you return. You can also select “Continue installation”.';

  @override
  String get updateInstallerOpened =>
      'The installer is open. Confirm the update; if you closed it, select “Update” to open it again.';

  @override
  String get updateInstallFailed => 'Could not update';

  @override
  String get updateDownloadFailed =>
      'The download did not finish. Check your connection and available storage, then try again.';

  @override
  String get updateVerificationFailed =>
      'The update did not pass integrity and compatibility checks. Nothing has been installed. Please read the instructions for this release.';

  @override
  String get updatePermissionFailed =>
      'This installation could not be updated due to permissions. Check the app folder or installer permissions, then try again.';

  @override
  String get updateGenericFailed =>
      'The update could not be prepared. Your current installation is still available. Try again or view the release instructions.';

  @override
  String get updateBusyBody =>
      'Finish or pause your transfers and close guest links before updating.';

  @override
  String get updateOpenFailed => 'Could not open the link. Check that a web browser is available.';

  @override
  String get appName => 'PepoConnect';

  @override
  String get appTagline => 'Photos and files between your phone and PC, instantly';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get save => 'Save';

  @override
  String get rename => 'Rename';

  @override
  String get remove => 'Remove';

  @override
  String get delete => 'Delete';

  @override
  String get open => 'Open';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get select => 'Select';

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Clear selection';

  @override
  String get more => 'More options';

  @override
  String get search => 'Search';

  @override
  String get loading => 'Loading…';

  @override
  String get refresh => 'Refresh';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get clearAll => 'Clear all';

  @override
  String get today => 'today';

  @override
  String get yesterday => 'yesterday';

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get showInFolder => 'Show in folder';

  @override
  String get saveAs => 'Save as…';

  @override
  String get download => 'Download';

  @override
  String get openFolder => 'Open folder';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navGallery => 'Gallery';

  @override
  String get navActivity => 'Activity';

  @override
  String get navSettings => 'Settings';

  @override
  String get navDownloads => 'Downloads';

  @override
  String navShortcutHint(int number) {
    return 'Ctrl+$number';
  }

  @override
  String get hubTooltip => 'Devices';

  @override
  String get thisPc => 'This PC';

  @override
  String get editPcName => 'Change the PC name';

  @override
  String get pcNamePlaceholder => 'PC name';

  @override
  String lastSync(String when) {
    return 'Last sync: $when';
  }

  @override
  String get neverSynced => 'Not synced yet';

  @override
  String get noDevicesPaired => 'No paired devices';

  @override
  String get addDevice => 'Add device';

  @override
  String get manageDevices => 'Manage devices';

  @override
  String get doNotDisturb => 'Do not disturb';

  @override
  String get doNotDisturbBody => 'Mutes notifications until you turn it off';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String deviceConnected(String device) {
    return '$device connected';
  }

  @override
  String deviceDisconnected(String device) {
    return '$device disconnected';
  }

  @override
  String batteryLevel(int percent) {
    return '$percent%';
  }

  @override
  String get batteryCharging => 'Charging';

  @override
  String get deviceKindPhone => 'Phone';

  @override
  String get deviceKindTablet => 'Tablet';

  @override
  String get deviceKindPc => 'PC';

  @override
  String get myPc => 'My PC';

  @override
  String get myDevices => 'My devices';

  @override
  String get changeName => 'Change name';

  @override
  String get forgetDevice => 'Remove';

  @override
  String forgetDeviceConfirm(String device) {
    return 'Remove $device?';
  }

  @override
  String get forgetDeviceBody => 'You will need to pair it again to use it';

  @override
  String get deviceNamePlaceholder => 'Device name';

  @override
  String get noDevicesYet => 'No devices yet';

  @override
  String get pairFirstDevice => 'Pair your phone to get started';

  @override
  String deviceOptions(String device) {
    return 'Options for $device';
  }

  @override
  String get reconnect => 'Reconnect';

  @override
  String get transfersTitle => 'Transfer files';

  @override
  String get transfersSubtitle => 'Drag or add files to send them to your device';

  @override
  String get addFiles => 'Add files…';

  @override
  String dropHere(String device) {
    return 'Drop to send to $device';
  }

  @override
  String get dropAnywhere => 'Drop files here';

  @override
  String sentTo(int percent, String device) {
    return '$percent% sent to $device';
  }

  @override
  String receivedFrom(int percent, String device) {
    return '$percent% received from $device';
  }

  @override
  String sendingTo(String device) {
    return 'Sending to $device';
  }

  @override
  String receivingFrom(String device) {
    return 'Receiving from $device';
  }

  @override
  String get transferComplete => 'Transfer complete';

  @override
  String transferFailed(String file) {
    return 'Could not transfer $file';
  }

  @override
  String get transferCancelled => 'Transfer cancelled';

  @override
  String get transferPaused => 'Paused';

  @override
  String get transferQueued => 'Queued';

  @override
  String get transfersEmptyTitle => 'No transfers';

  @override
  String get transfersEmptyBody => 'Files you send or receive will show up here';

  @override
  String get transfersRecent => 'Recent';

  @override
  String get transfersInProgress => 'In progress';

  @override
  String transfersActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers in progress',
      one: '1 transfer in progress',
    );
    return '$_temp0';
  }

  @override
  String get cancelTransfer => 'Cancel';

  @override
  String get pauseTransfer => 'Pause';

  @override
  String get resumeTransfer => 'Resume';

  @override
  String get removeFromList => 'Remove from list';

  @override
  String get clearHistory => 'Clear history';

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String sendingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sending $count files',
      one: 'Sending 1 file',
    );
    return '$_temp0';
  }

  @override
  String sendToDevice(String device) {
    return 'Send to $device';
  }

  @override
  String get chooseDevice => 'Choose a device';

  @override
  String get noDeviceConnected => 'No device connected';

  @override
  String get connectToSend => 'Connect your phone to send files';

  @override
  String get executableBlocked =>
      'PepoConnect does not send programs until you allow it in Settings';

  @override
  String executableBlockedOne(String file) {
    return '$file was not sent';
  }

  @override
  String executableBlockedMany(int count) {
    return '$count executables were not sent';
  }

  @override
  String get executableBlockedBody =>
      'PepoConnect does not send programs (.exe, .msi, .apk…) until you turn on “Allow executables” in Settings › Storage, on this device and on the one receiving them.';

  @override
  String get executableOpenSettings => 'Open settings';

  @override
  String executableRefusedTitle(String file, String device) {
    return '$file from $device was not accepted';
  }

  @override
  String get executableRefusedBody =>
      'Executables are off. Turn them on in Settings › Storage if you were expecting it';

  @override
  String get trRejectedExecutable => 'The other device does not accept executables';

  @override
  String speedAndEta(String speed, String eta) {
    return '$speed/s · $eta left';
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
    return '$device gallery';
  }

  @override
  String get allDevices => 'All devices';

  @override
  String get photos => 'Photos';

  @override
  String get videos => 'Videos';

  @override
  String get all => 'All';

  @override
  String get addToPhone => 'Add to phone';

  @override
  String get type => 'Type';

  @override
  String get view => 'View';

  @override
  String get viewLarge => 'Large';

  @override
  String get viewMedium => 'Medium';

  @override
  String get viewSmall => 'Small';

  @override
  String get squareThumbnails => 'Square thumbnails';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String selectedCountSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected ($size)',
      one: '1 selected ($size)',
    );
    return '$_temp0';
  }

  @override
  String get deleteFromPhone => 'Delete from phone';

  @override
  String deleteFromPhoneConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items from the phone?',
      one: 'Delete 1 item from the phone?',
    );
    return '$_temp0';
  }

  @override
  String get deleteFromPhoneBody => 'They are removed from the phone. Any copy on the PC stays';

  @override
  String get newLabel => 'New';

  @override
  String get onPc => 'On PC';

  @override
  String get galleryEmptyTitle => 'No photos yet';

  @override
  String get galleryEmptyBody => 'Photos you take with your phone will show up here';

  @override
  String get galleryOffline => 'Connect your phone to see the gallery';

  @override
  String get galleryLoadMore => 'Load more';

  @override
  String newPhotosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new photos',
      one: '1 new photo',
    );
    return '$_temp0';
  }

  @override
  String downloadedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get galleryRefreshTooltip => 'Refresh the gallery';

  @override
  String galleryItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get galleryGroupToday => 'Today';

  @override
  String get galleryGroupYesterday => 'Yesterday';

  @override
  String get galleryGroupThisWeek => 'This week';

  @override
  String get galleryGroupThisMonth => 'This month';

  @override
  String get dismissNew => 'Clear the new mark';

  @override
  String get viewerTitle => 'Viewer';

  @override
  String get viewerPrevious => 'Previous';

  @override
  String get viewerNext => 'Next';

  @override
  String get viewerZoomIn => 'Zoom in';

  @override
  String get viewerZoomOut => 'Zoom out';

  @override
  String get viewerFit => 'Fit to window';

  @override
  String get viewerActualSize => 'Actual size';

  @override
  String get viewerInfo => 'Info';

  @override
  String viewerTakenOn(String date) {
    return 'Taken on $date';
  }

  @override
  String viewerDimensions(int width, int height) {
    return '$width × $height';
  }

  @override
  String get viewerFileSize => 'Size';

  @override
  String get viewerFileName => 'Name';

  @override
  String get viewerPlay => 'Play';

  @override
  String get viewerLoadingFull => 'Loading the full-size photo…';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsAbout => 'About';

  @override
  String get keepInBackground => 'Let PepoConnect keep running in the background';

  @override
  String get keepInBackgroundBody => 'Closing the window keeps the app in the system tray';

  @override
  String get startWithWindows => 'Start PepoConnect with Windows';

  @override
  String get startWithSystem => 'Start PepoConnect at login';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'Use system setting';

  @override
  String get downloadsSavedIn => 'Received files are saved in:';

  @override
  String get changeLocation => 'Change location';

  @override
  String get separateByDevice => 'Separate by device';

  @override
  String get separateByDeviceBody => 'One folder per device inside that location';

  @override
  String get animations => 'Animations';

  @override
  String get animationsBody => 'Turn them off to save resources';

  @override
  String get autoDownloadPhotos => 'Download new photos automatically';

  @override
  String get autoDownloadPhotosBody => 'Every new photo is saved to the PC without asking';

  @override
  String get convertHeic => 'Convert HEIC to JPEG';

  @override
  String get convertHeicBody => 'iPhone photos are saved as JPEG';

  @override
  String get sharedClipboard => 'Shared clipboard';

  @override
  String get sharedClipboardBody =>
      'What you copy on one device can be pasted on the other. On the phone it is sent when you open PepoConnect, from the \"Send clipboard\" quick tile or from the icon shortcut.';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsBody => 'Alerts for new photos and transfers';

  @override
  String get sounds => 'Sounds';

  @override
  String get soundsBody => 'A short sound when a transfer finishes';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Use system setting';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get aboutBody =>
      'Photos and files between your phone and PC, on your local network. Nothing goes through the internet';

  @override
  String get allowExecutables => 'Allow executables';

  @override
  String get autoSendPhotos => 'Send new photos to the PC automatically';

  @override
  String get autoSendPhotosBody => 'Every photo you take reaches the PC right away';

  @override
  String get backgroundService => 'Keep the connection in the background';

  @override
  String get backgroundServiceBody => 'Needed so photos arrive while the app is closed';

  @override
  String get defaultHub => 'Default PC';

  @override
  String get deviceSettings => 'Device settings';

  @override
  String get openDownloadsFolder => 'Open the downloads folder';

  @override
  String get resetSettings => 'Reset settings';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get pairTitle => 'Pair your phone and PC';

  @override
  String get pairSubtitle => 'Both need to be on the same Wi-Fi network';

  @override
  String get pairStep1 => 'Install PepoConnect on the phone and tap Add PC';

  @override
  String get pairStep2 => 'Scan this code with the phone';

  @override
  String pairStepNumber(int number) {
    return 'Step $number';
  }

  @override
  String get pairCheckCode => 'Check the code';

  @override
  String get pairCheckCodeBody => 'Confirm the phone shows the same code';

  @override
  String get pairConfirm => 'Confirm';

  @override
  String get pairRescan => 'Scan again';

  @override
  String get pairDone => 'Paired';

  @override
  String get pairDoneBody => 'Your PC and phone are now connected';

  @override
  String get pairUseCode => 'Use a code instead of QR';

  @override
  String get pairUseQr => 'Use QR';

  @override
  String get pairCode => 'Code';

  @override
  String pairExpiresIn(int seconds) {
    return 'Expires in $seconds s';
  }

  @override
  String get pairExpired => 'The code has expired';

  @override
  String get pairNewCode => 'New code';

  @override
  String get pairEnterCode => 'Type the code shown on the PC';

  @override
  String get pairScanQr => 'Scan the QR on the PC';

  @override
  String get pairFailed => 'Could not pair';

  @override
  String get pairFailedBody => 'Check the code and that both are on the same network';

  @override
  String get pairCancel => 'Cancel pairing';

  @override
  String get pairSearching => 'Looking for PCs on the network…';

  @override
  String get pairFound => 'PCs found';

  @override
  String get pairManual => 'Type the address manually';

  @override
  String get pairAddress => 'Address';

  @override
  String get pairPort => 'Port';

  @override
  String pairConnecting(String device) {
    return 'Connecting to $device…';
  }

  @override
  String pairingWith(String device) {
    return 'Pairing with $device';
  }

  @override
  String pairRequestTitle(String device) {
    return '$device wants to pair';
  }

  @override
  String get pairCameraPermission => 'PepoConnect needs the camera to read the QR';

  @override
  String get mobileReceived => 'Received';

  @override
  String get mobileSent => 'Sent';

  @override
  String get mobileSendToPc => 'Send to PC';

  @override
  String get mobileFiles => 'Files';

  @override
  String get mobileGallery => 'Gallery';

  @override
  String get mobileClipboard => 'Clipboard';

  @override
  String get mobileCamera => 'Camera';

  @override
  String get mobileNoPc => 'No PC connected';

  @override
  String get mobileTapToChangePc => 'Tap to switch PC';

  @override
  String get mobileShareVia => 'Send with PepoConnect';

  @override
  String get mobileReceivedEmpty => 'Files the PC sends you will show up here';

  @override
  String get mobileSentEmpty => 'What you send to the PC will show up here';

  @override
  String get mobileAddPc => 'Add PC';

  @override
  String mobileServiceNotification(String device) {
    return 'PepoConnect is connected to $device';
  }

  @override
  String get mobileServiceIdle => 'PepoConnect is waiting for the PC';

  @override
  String get activityTitle => 'Activity';

  @override
  String activityNewPhoto(String device) {
    return 'New photo on $device';
  }

  @override
  String activityNewVideo(String device) {
    return 'New video on $device';
  }

  @override
  String activityReceived(String file, String device) {
    return 'Received $file from $device';
  }

  @override
  String activitySent(String file, String device) {
    return 'Sent $file to $device';
  }

  @override
  String activityFailed(String file) {
    return 'Could not transfer $file';
  }

  @override
  String activityConnected(String device) {
    return '$device connected';
  }

  @override
  String activityDisconnected(String device) {
    return '$device disconnected';
  }

  @override
  String activityPaired(String device) {
    return '$device paired';
  }

  @override
  String activityForgotten(String device) {
    return '$device removed';
  }

  @override
  String activityClipboard(String device) {
    return 'Text copied from $device';
  }

  @override
  String get activityEmpty => 'No recent activity';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$_temp0';
  }

  @override
  String get activityPanelShow => 'Show activity';

  @override
  String get activityPanelHide => 'Hide activity';

  @override
  String get toastNewPhoto => 'New photo';

  @override
  String get toastNewVideo => 'New video';

  @override
  String toastNewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new items',
      one: '1 new item',
    );
    return '$_temp0';
  }

  @override
  String toastNewPhotos(int count) {
    return '$count new photos';
  }

  @override
  String get toastView => 'View';

  @override
  String get toastSaved => 'Saved to the PC';

  @override
  String get toastCopied => 'Copied';

  @override
  String toastSentTo(String device) {
    return 'Sent to $device';
  }

  @override
  String toastReceivedFrom(String device) {
    return 'Received from $device';
  }

  @override
  String toastDeviceConnected(String device) {
    return '$device connected';
  }

  @override
  String toastDeviceOffline(String device) {
    return '$device offline';
  }

  @override
  String toastDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items deleted from the phone',
      one: '1 item deleted from the phone',
    );
    return '$_temp0';
  }

  @override
  String toastClipboardReceived(String device) {
    return 'Text copied from $device';
  }

  @override
  String toastClipboardSent(String device) {
    return 'Clipboard sent to $device';
  }

  @override
  String get clipboardEmpty => 'The clipboard is empty';

  @override
  String get clipboardNoTarget => 'No connected PC with shared clipboard';

  @override
  String get clipboardQueued => 'No PC connected: it will be sent on connect';

  @override
  String get toastUndo => 'Undo';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorNetwork => 'No connection to the device';

  @override
  String get errorNotPaired => 'This device is no longer paired';

  @override
  String get errorFileMissing => 'The file no longer exists';

  @override
  String get errorNoSpace => 'No space left on the disk';

  @override
  String get errorPermission => 'PepoConnect has no permission to access photos';

  @override
  String get errorPermissionAction => 'Open settings';

  @override
  String get errorTimeout => 'The device is not responding';

  @override
  String get errorCancelled => 'Cancelled';

  @override
  String get errorTryAgain => 'Try again';

  @override
  String get errorFolderMissing => 'The downloads folder does not exist';

  @override
  String get errorCode => 'Wrong code';

  @override
  String get errorDetails => 'Details';

  @override
  String get errorCopyDetails => 'Copy details';

  @override
  String get onboardingTitle => 'Your phone, on your PC';

  @override
  String get onboardingBody =>
      'Photos you take show up here instantly. And you can send files both ways';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingPairLater => 'Pair later';

  @override
  String get onboardingNamePrompt => 'What is this PC called?';

  @override
  String get onboardingFolderPrompt => 'Where should we save what arrives?';

  @override
  String get onboardingLocalOnly => 'Everything stays on your local network. Nothing goes online';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutSections => 'Ctrl+1 to Ctrl+4 switch section';

  @override
  String get shortcutSettings => 'Ctrl+, opens Settings';

  @override
  String get shortcutRefresh => 'F5 refreshes';

  @override
  String get shortcutEscape => 'Esc closes menus and selections';

  @override
  String get trShareWithAnyone => 'Share with anyone';

  @override
  String get trGuestSend => 'Send';

  @override
  String get trGuestReceive => 'Receive';

  @override
  String get trGuestSendBody =>
      'Whoever opens the link can download these files from a browser, without installing anything';

  @override
  String get trGuestReceiveBody => 'Whoever opens the link can send you files from a browser';

  @override
  String get trGuestNoFiles => 'Add at least one file';

  @override
  String get trGuestMessage => 'Message (optional)';

  @override
  String get trGuestCreateLink => 'Create link';

  @override
  String get trGuestReadyTitle => 'Your files are ready';

  @override
  String get trGuestReceiveReadyTitle => 'Ready to receive';

  @override
  String get trGuestScanHint =>
      'Scan the QR code or open the link from a device on the same Wi-Fi network';

  @override
  String get trGuestCopyLink => 'Copy link';

  @override
  String trGuestExpiresIn(String time) {
    return 'The link expires in $time';
  }

  @override
  String get trGuestExpired => 'The link has expired';

  @override
  String get trGuestNewLink => 'Create another link';

  @override
  String get trGuestWaiting => 'Nobody has opened the link yet';

  @override
  String trGuestOpenedBy(String remote) {
    return 'Opened by $remote';
  }

  @override
  String trGuestDownloaded(String file) {
    return '$file downloaded';
  }

  @override
  String trGuestReceived(String file) {
    return '$file received';
  }

  @override
  String trGuestUploadFailed(String file) {
    return 'Could not receive $file';
  }

  @override
  String get trGuestNoAddress => 'No local network found';

  @override
  String get trGuestFailed => 'Could not create the link';

  @override
  String get trHistory => 'History';

  @override
  String get trSendFailed => 'Could not send';

  @override
  String get trDroppedNothing => 'No files to send';

  @override
  String get trNoPcConnected => 'Connect a PC to send files';

  @override
  String get galYourPhone => 'Your phone';

  @override
  String get galYourTablet => 'Your tablet';

  @override
  String get galYourPc => 'Your PC';

  @override
  String get galFullThumbnails => 'Full thumbnails';

  @override
  String get galTileSize => 'Thumbnail size';

  @override
  String get galSession => 'Session';

  @override
  String get galSessionTooltip => 'Session mode: the viewer jumps to every new photo';

  @override
  String galSavedCopies(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files saved to $folder',
      one: '1 file saved to $folder',
    );
    return '$_temp0';
  }

  @override
  String galSaveFailed(String file) {
    return 'Could not save $file';
  }

  @override
  String galDownloadFailed(String file) {
    return 'Could not download $file';
  }

  @override
  String get galDeleteFailed => 'Could not delete from the phone';

  @override
  String galSelectGroup(String group) {
    return 'Select $group';
  }

  @override
  String get galSelectNew => 'Select new';

  @override
  String galDownloadStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloading $count items',
      one: 'Downloading 1 item',
    );
    return '$_temp0';
  }

  @override
  String get galOfflineBody => 'Photos will appear as soon as it connects';

  @override
  String get vwDevice => 'Device';

  @override
  String get vwDate => 'Date';

  @override
  String get vwResolution => 'Resolution';

  @override
  String get vwDownloading => 'Downloading…';

  @override
  String vwSessionCounter(int photos, int downloaded) {
    String _temp0 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos photos',
      one: '1 photo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      downloaded,
      locale: localeName,
      other: '$downloaded downloaded',
      one: '1 downloaded',
    );
    return 'Session · $_temp0 · $_temp1';
  }

  @override
  String get vwSessionWaiting => 'Waiting for new photos…';

  @override
  String get vwSessionHint => 'Space: download · Esc: exit';

  @override
  String get vwSessionExit => 'Exit session';

  @override
  String vwPosition(int index, int total) {
    return '$index of $total';
  }

  @override
  String get vwNotFound => 'This item is no longer in the gallery';

  @override
  String get vwPreviewFailed => 'Could not load the preview';

  @override
  String get vwVideoOpenFailed => 'Could not open the video';

  @override
  String get vwStateOnPhone => 'Only on the phone';

  @override
  String get setStorage => 'Storage';

  @override
  String get setThisPhone => 'This phone';

  @override
  String get setRenameDeviceTitle => 'Rename device';

  @override
  String setForgetConfirm(String device) {
    return 'Forget \"$device\"?';
  }

  @override
  String get setForgetBody => 'You will have to pair it again';

  @override
  String setLastConnection(String when) {
    return 'Last connection: $when';
  }

  @override
  String get setThemeBody => 'Choose how PepoConnect looks';

  @override
  String get setStartWithSystem => 'Start PepoConnect with the system';

  @override
  String get setStartWithSystemBody => 'Starts minimised, in the tray';

  @override
  String get setSeparateByDeviceBody => 'Creates a subfolder for each phone';

  @override
  String get setAllowExecutablesBody =>
      'Off, programs (.exe, .msi, .apk…) are neither sent nor received. Turn it on on both devices only if you need it';

  @override
  String get setResetLocation => 'Reset';

  @override
  String get setDefaultLocation => 'Default folder';

  @override
  String get setChooseFolder => 'Choose where to save received files';

  @override
  String get setBackgroundService => 'Background service';

  @override
  String get setBackgroundServiceBody => 'Keeps the connection to the PC';

  @override
  String get setAutoSendPhotos => 'Send new photos automatically';

  @override
  String get setAutoSendPhotosBody => 'Every photo you take reaches the main PC right away';

  @override
  String get setDefaultHub => 'Main PC';

  @override
  String get setDefaultHubBody => 'Receives new photos and whatever you share';

  @override
  String get setDefaultHubNone => 'Not chosen';

  @override
  String get setDefaultHubRequired => 'Choose a main PC first';

  @override
  String get setPermissions => 'Permissions';

  @override
  String get setPermissionPhotos => 'Photos and videos';

  @override
  String get setPermissionPhotosBody => 'To show your gallery on the PC';

  @override
  String get setPermissionNotificationsBody => 'To tell you what comes in and goes out';

  @override
  String get setPermissionBattery => 'No battery restriction';

  @override
  String get setPermissionBatteryBody => 'So the connection survives with the screen off';

  @override
  String get setAllow => 'Allow';

  @override
  String get setGranted => 'Granted';

  @override
  String get setDeviceId => 'Device ID';

  @override
  String get setFastLane => 'Fast lane';

  @override
  String setFastLaneOn(int port) {
    return 'On · Rust, AES-256-GCM, port $port';
  }

  @override
  String get setFastLaneOff => 'Not available on this device; the TLS channels are used';

  @override
  String get setCheckUpdates => 'Check for updates';

  @override
  String get setUpToDate => 'You have the latest version';

  @override
  String setUpdateAvailable(String version) {
    return 'A new version is available: $version';
  }

  @override
  String get setUpdateFailed => 'Could not check';

  @override
  String get setUpdateFailedBody => 'Check your internet connection and try again later';

  @override
  String get setViewOnGitHub => 'View on GitHub';

  @override
  String get setSourceCode => 'Source code on GitHub';

  @override
  String get setResetConfirm => 'Reset settings?';

  @override
  String get setResetBody => 'Everything goes back to the defaults. Paired devices are kept';

  @override
  String get setResetDone => 'Settings reset';

  @override
  String get onbHowTitle => 'How do you want to use PepoConnect?';

  @override
  String get onbConnectPhone => 'Connect your phone';

  @override
  String get onbConnectPhoneBody => 'See its photos and pass files around';

  @override
  String get onbAddPhone => 'Add phone';

  @override
  String get onbShareTitle => 'Share with anyone';

  @override
  String get onbShareBody => 'Send or receive files with a link, nothing to install';

  @override
  String get onbSkipForNow => 'Skip for now';

  @override
  String get onbSlide1 => 'Move photos and files between this phone and your PC';

  @override
  String get onbSlide2 => 'Every new photo shows up on the PC right away';

  @override
  String get onbSlide3 => 'All over your network, encrypted, no accounts';

  @override
  String get onbPermissionsTitle => 'Required permissions';

  @override
  String get onbPermissionsBody => 'PepoConnect needs them to keep working with the screen off';

  @override
  String get onbPermissionsSkipWarning => 'Without them, photos will not reach the PC on their own';

  @override
  String get onbContinue => 'Continue';

  @override
  String onbPageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get pairInstallTitle => 'Install PepoConnect on the phone';

  @override
  String get pairDownloadApp => 'Download the app';

  @override
  String get pairScanStep => 'Open the app and scan this code';

  @override
  String pairExpiresInTime(String time) {
    return 'Expires in $time';
  }

  @override
  String get pairGenerateAnother => 'Generate another code';

  @override
  String get pairOtherPc => 'Connect to another PC';

  @override
  String pairYourPc(String address) {
    return 'Your PC: $address';
  }

  @override
  String get pairCodeHint => 'Type it on the other PC under Pair › Enter code';

  @override
  String get pairEnterCodeTitle => 'Enter code';

  @override
  String get pairManualAddress => 'PC address (IP:port)';

  @override
  String get pairConnect => 'Pair';

  @override
  String get pairSelectPc => 'Choose the PC';

  @override
  String get pairScanTitle => 'Scan the code on the PC';

  @override
  String get pairScanHint => 'Open PepoConnect on the PC and go to Add device';

  @override
  String get pairEnterManually => 'Enter manually';

  @override
  String get pairPasteLink => 'Paste the pepoconnect://… link here';

  @override
  String get pairPairing => 'Pairing…';

  @override
  String get pairTorch => 'Torch';

  @override
  String get pairLinkExpired => 'The link has expired. Generate a new code on the PC';

  @override
  String get pairNotACode => 'That is not a PepoConnect code';

  @override
  String get pairWrongCode => 'Wrong code. Check the six digits';

  @override
  String get pairPcNotFound => 'Cannot find the PC. Check that both are on the same Wi-Fi network';

  @override
  String get pairIdentityChanged => 'The PC\'s identity has changed. Look for it again';

  @override
  String get pairCameraDenied => 'No camera access';

  @override
  String get pairAddressInvalid => 'Type a valid address, for example 192.168.1.20:47473';

  @override
  String get pairCodeInvalid => 'The code has six digits';
}
