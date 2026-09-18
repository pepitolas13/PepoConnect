import 'package:pepo_core/pepo_core.dart' show ErrorCode;

import '../../shared/i18n/l10n.dart';

/// Text for a failed transfer: reasons the other device sends as a code
/// get a sentence, anything else is shown as it came.
String transferErrorLabel(AppLocalizations t, String? error) => switch (error) {
  null || '' => t.errorGeneric,
  ErrorCode.executable => t.trRejectedExecutable,
  _ => error,
};
