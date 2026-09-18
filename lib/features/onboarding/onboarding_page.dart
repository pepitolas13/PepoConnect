import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_logo.dart';

/// Placeholder; replaced by the real onboarding flow.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PepoLogo(size: 96),
                const SizedBox(height: Space.xl),
                Text(t.onboardingTitle, style: text.title, textAlign: TextAlign.center),
                const SizedBox(height: Space.s),
                Text(
                  t.onboardingBody,
                  style: text.body.copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xl),
                FluentButton.primary(
                  label: t.onboardingStart,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
