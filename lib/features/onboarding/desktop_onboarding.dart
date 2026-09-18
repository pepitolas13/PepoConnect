import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_card.dart';
import '../../shared/widgets/pepo_logo.dart';
import '../../state/app_settings.dart';

/// "How do you want to use PepoConnect?": pair a phone, or share with
/// anyone through a link. A discreet link skips for now.
class DesktopOnboarding extends ConsumerWidget {
  const DesktopOnboarding({super.key});

  /// Marks the onboarding as done and leaves it for [location].
  Future<void> _finish(BuildContext context, WidgetRef ref, String location) async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
    if (!context.mounted) return;
    context.go(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PepoLogo(size: 72),
                  const SizedBox(height: Space.xl),
                  Text(t.onbHowTitle, style: text.title, textAlign: TextAlign.center),
                  const SizedBox(height: Space.xs),
                  Text(
                    t.onboardingLocalOnly,
                    style: text.body.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.xxl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final sideBySide = constraints.maxWidth >= 600;
                      final phone = OnboardingChoiceCard(
                        icon: FluentIcons.phone_desktop_28_regular,
                        title: t.onbConnectPhone,
                        body: t.onbConnectPhoneBody,
                        buttonIcon: FluentIcons.add_16_regular,
                        buttonLabel: t.onbAddPhone,
                        primary: true,
                        fill: sideBySide,
                        onPressed: () => context.push(AppRoutes.pair),
                      );
                      final share = OnboardingChoiceCard(
                        icon: FluentIcons.share_28_regular,
                        title: t.onbShareTitle,
                        body: t.onbShareBody,
                        buttonIcon: FluentIcons.link_20_regular,
                        buttonLabel: t.share,
                        fill: sideBySide,
                        onPressed: () => _finish(context, ref, '${AppRoutes.transfers}?guest=1'),
                      );
                      if (!sideBySide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            phone,
                            const SizedBox(height: Space.l),
                            share,
                          ],
                        );
                      }
                      // Same height for both, buttons on the same baseline.
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: phone),
                            const SizedBox(width: Space.l),
                            Expanded(child: share),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: Space.xl),
                  FluentButton.subtle(
                    label: t.onbSkipForNow,
                    onPressed: () => _finish(context, ref, AppRoutes.transfers),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two big choices: icon, title, one line and a button.
class OnboardingChoiceCard extends StatelessWidget {
  const OnboardingChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
    this.buttonIcon,
    this.primary = false,
    this.fill = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String buttonLabel;
  final IconData? buttonIcon;
  final bool primary;

  /// True when the card is given a fixed height (side by side with another
  /// one): the button then sits at the bottom.
  final bool fill;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    return PepoCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: colors.accent),
          const SizedBox(height: Space.l),
          Text(title, style: text.subtitle),
          const SizedBox(height: Space.xs),
          Text(body, style: text.body.copyWith(color: colors.textSecondary)),
          if (fill) const Spacer(),
          const SizedBox(height: Space.xl),
          Align(
            alignment: Alignment.centerLeft,
            child: primary
                ? FluentButton.primary(icon: buttonIcon, label: buttonLabel, onPressed: onPressed)
                : FluentButton(icon: buttonIcon, label: buttonLabel, onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}
