import 'package:flutter/material.dart';

import '../../app/bootstrap.dart';
import 'desktop_onboarding.dart';
import 'mobile_onboarding.dart';

/// First run. Desktop asks how PepoConnect will be used; the phone shows
/// three slides and then the permissions it needs.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, this.mobile});

  /// Forces the phone or desktop variant (defaults to the running platform).
  final bool? mobile;

  @override
  Widget build(BuildContext context) {
    return (mobile ?? !isDesktop) ? const MobileOnboarding() : const DesktopOnboarding();
  }
}
