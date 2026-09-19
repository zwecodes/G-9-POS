import 'package:flutter/widgets.dart';
import 'package:g9pos/l10n/app_localizations.dart';

export 'package:g9pos/l10n/app_localizations.dart';

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
