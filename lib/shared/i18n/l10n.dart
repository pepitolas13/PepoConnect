import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

export '../../l10n/generated/app_localizations.dart' show AppLocalizations;

/// `context.t.navGallery` instead of `AppLocalizations.of(context).navGallery`.
extension L10nX on BuildContext {
  AppLocalizations get t => AppLocalizations.of(this);
}

/// Locale to pass to `MaterialApp.locale` from the `settings.locale` string
/// (`system`, `es`, `en`).
Locale? localeFromSetting(String setting) => switch (setting) {
  'es' => const Locale('es'),
  'en' => const Locale('en'),
  _ => null,
};
