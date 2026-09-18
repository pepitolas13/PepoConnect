// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get executableBlocked => 'PepoConnect does not send executable programs';

  @override
  String executableWarning(String file) {
    return '$file is an executable. Send it anyway?';
  }

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
  String get sharedClipboardBody => 'What you copy on one device can be pasted on the other';

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
  String get allowExecutablesBody =>
      'Accepts .exe, .msi and similar files. Only if you know what you are doing';

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
}
