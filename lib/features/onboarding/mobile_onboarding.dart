import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/motion.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/info_bar.dart';
import '../../shared/widgets/pepo_card.dart';
import '../../shared/widgets/pepo_logo.dart';
import '../settings/permissions.dart';

/// Three swipeable slides, then the permissions the phone needs.
class MobileOnboarding extends ConsumerStatefulWidget {
  const MobileOnboarding({super.key});

  static const int slides = 3;

  @override
  ConsumerState<MobileOnboarding> createState() => _MobileOnboardingState();
}

class _MobileOnboardingState extends ConsumerState<MobileOnboarding> {
  final PageController _controller = PageController();
  int _page = 0;

  /// Index of the permissions page.
  static const int _permissionsPage = MobileOnboarding.slides;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    final motion = Motion.of(context);
    if (!motion.enabled) {
      _controller.jumpToPage(page);
      return;
    }
    _controller.animateToPage(page, duration: motion.slow, curve: Motion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final onPermissions = _page >= _permissionsPage;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _Slide(text: t.onbSlide1),
                  _Slide(text: t.onbSlide2),
                  _Slide(text: t.onbSlide3),
                  const _PermissionsStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.l),
              child: onPermissions ? _PermissionsFooter(onContinue: _continue) : _slidesFooter(t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slidesFooter(AppLocalizations t) {
    return Row(
      children: [
        PageDots(count: MobileOnboarding.slides, index: _page),
        const Spacer(),
        FluentButton.subtle(label: t.skip, onPressed: () => _go(_permissionsPage)),
        const SizedBox(width: Space.s),
        FluentButton.primary(label: t.next, onPressed: () => _go(_page + 1)),
      ],
    );
  }

  void _continue() => context.push(AppRoutes.pair);
}

class _Slide extends StatelessWidget {
  const _Slide({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PepoLogo(size: 96),
          const SizedBox(height: Space.xxl),
          Text(text, style: context.text.subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _PermissionsStep extends StatelessWidget {
  const _PermissionsStep();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.xl, Space.l, Space.l),
      children: [
        Text(t.onbPermissionsTitle, style: text.title),
        const SizedBox(height: Space.xs),
        Text(t.onbPermissionsBody, style: text.body.copyWith(color: colors.textSecondary)),
        const SizedBox(height: Space.xl),
        const PepoCard(padding: EdgeInsets.zero, clip: true, child: PermissionRows()),
      ],
    );
  }
}

/// "Continue" with a warning when something is still missing.
class _PermissionsFooter extends ConsumerWidget {
  const _PermissionsFooter({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final permissions = ref.watch(mobilePermissionsProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (permissions != null && !permissions.allGranted)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.m),
            child: InfoBar(severity: InfoBarSeverity.caution, title: t.onbPermissionsSkipWarning),
          ),
        FluentButton.primary(
          label: t.onbContinue,
          size: FluentButtonSize.large,
          expand: true,
          onPressed: onContinue,
        ),
      ],
    );
  }
}

/// Page indicator: the active dot stretches to a short pill.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final motion = Motion.of(context);
    final current = index.clamp(0, count - 1);
    return Semantics(
      label: t.onbPageOf(current + 1, count),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: motion.normal,
              curve: Motion.emphasized,
              width: i == current ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.only(right: Space.s),
              decoration: BoxDecoration(
                color: i == current ? colors.accent : colors.textTertiary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
