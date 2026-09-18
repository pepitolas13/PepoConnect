// Standalone catalogue of the PepoFluent UI. No engine, fake providers.
//
//   flutter run -d windows -t lib/dev/widget_gallery.dart
//
// Add `--dart-define=GALLERY_TOUR=3` to walk through every section (3 s
// each) and, with `--dart-define=GALLERY_SHOTS=<dir>`, save a PNG of each
// step rendered by the app itself (no desktop capture, no window focus).
// The process exits when the tour ends.

import 'dart:async';
import 'dart:io' show File, exit;
import 'dart:ui' as ui;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pepo_core/pepo_core.dart' show TransferDirection;

import '../app/router.dart';
import '../app/shell/app_shell.dart';
import '../app/shell/hub_menu.dart';
import '../app/theme.dart';
import '../shared/i18n/l10n.dart';
import '../shared/util/format.dart';
import '../shared/widgets/widgets.dart';
import '../state/app_settings.dart';
import '../state/engine_providers.dart';
import 'fakes.dart';

final _toasts = ToastService();

/// Seconds per tour step; 0 disables the tour.
const int _tourSeconds = int.fromEnvironment('GALLERY_TOUR', defaultValue: 0);

/// Directory that receives one PNG per tour step (empty: no files).
const String _shotsDir = String.fromEnvironment('GALLERY_SHOTS', defaultValue: '');

/// Boundary around the whole app (toasts included) for the tour captures.
final GlobalKey _appBoundary = GlobalKey(debugLabel: 'gallery-app');

/// Boundary around the embedded shell, which may be wider than the window.
final GlobalKey _shellBoundary = GlobalKey(debugLabel: 'gallery-shell');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: fakeOverrides(
        unread: 3,
        transfers: TransfersState(
          active: [
            fakeTransfer(
              id: 1,
              deviceId: 'georgy',
              name: 'IMG_2041.jpg',
              bytesDone: 8 * 1024 * 1024,
            ),
            fakeTransfer(
              id: 2,
              deviceId: 'pixel8',
              name: 'video.mp4',
              size: 48 * 1024 * 1024,
              bytesDone: 3 * 1024 * 1024,
              direction: TransferDirection.receive,
            ),
          ],
        ),
      ),
      child: const WidgetGalleryApp(),
    ),
  );
}

class WidgetGalleryApp extends ConsumerWidget {
  const WidgetGalleryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'PepoConnect · Galería de widgets',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeModeOf(settings.themeMode),
      locale: localeFromSetting(settings.locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => RepaintBoundary(
        key: _appBoundary,
        child: MotionScope(
          enabled: settings.animations,
          child: ToastHost(service: _toasts, child: child ?? const SizedBox.shrink()),
        ),
      ),
      home: const _GalleryHome(),
    );
  }
}

class _Section {
  const _Section(this.title, this.icon, this.builder);

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

class _GalleryHome extends ConsumerStatefulWidget {
  const _GalleryHome();

  @override
  ConsumerState<_GalleryHome> createState() => _GalleryHomeState();
}

/// One step of the screenshot tour.
class _TourStep {
  const _TourStep(this.section, {this.shellWidth, this.dark, this.toast = false});

  final int section;
  final double? shellWidth;
  final bool? dark;
  final bool toast;
}

class _GalleryHomeState extends ConsumerState<_GalleryHome> {
  int _index = 0;
  double _shellWidth = 1100;
  Timer? _tour;
  int _tourStep = 0;

  static const List<_TourStep> _tourSteps = [
    _TourStep(0),
    _TourStep(1),
    _TourStep(2),
    _TourStep(3, toast: true),
    _TourStep(4),
    _TourStep(5, shellWidth: 1400),
    _TourStep(5, shellWidth: 1100),
    _TourStep(5, shellWidth: 700),
    _TourStep(5, shellWidth: 400),
    _TourStep(5, shellWidth: 1400, dark: true),
    _TourStep(6, dark: true),
    _TourStep(3, dark: true, toast: true),
    _TourStep(1, dark: true),
    _TourStep(6, dark: false),
    _TourStep(5, shellWidth: 1400, dark: false),
    _TourStep(0, dark: false),
  ];

  late final List<_Section> _sections = [
    _Section('Tokens', FluentIcons.color_20_regular, (_) => const _TokensSection()),
    _Section('Botones', FluentIcons.cursor_click_20_regular, (_) => const _ButtonsSection()),
    _Section('Controles', FluentIcons.toggle_left_20_regular, (_) => const _ControlsSection()),
    _Section('Feedback', FluentIcons.alert_20_regular, (_) => const _FeedbackSection()),
    _Section('Movimiento', FluentIcons.sparkle_20_regular, (_) => const _MotionSection()),
    _Section(
      'Shell',
      FluentIcons.window_20_regular,
      (_) =>
          _ShellSection(width: _shellWidth, onWidthChanged: (w) => setState(() => _shellWidth = w)),
    ),
    _Section('Superficies', FluentIcons.layer_20_regular, (_) => const _SurfacesSection()),
  ];

  @override
  void initState() {
    super.initState();
    if (_tourSeconds > 0) {
      _tour = Timer.periodic(Duration(seconds: _tourSeconds), (_) => _nextTourStep());
    }
  }

  Future<void> _nextTourStep() async {
    if (_tourStep >= _tourSteps.length) {
      _tour?.cancel();
      // Let the last capture finish, then leave so `flutter run` returns.
      await Future<void>.delayed(const Duration(seconds: 2));
      exit(0);
    }
    final step = _tourSteps[_tourStep++];
    final index = _tourStep;
    debugPrint(
      'TOUR step $index/${_tourSteps.length}: section ${step.section} '
      'width ${step.shellWidth} dark ${step.dark}',
    );
    setState(() {
      _index = step.section;
      if (step.shellWidth != null) _shellWidth = step.shellWidth!;
    });
    if (_shotsDir.isNotEmpty) {
      // Wait for transitions to settle before rasterising.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1500)).then((_) => _capture(index, step)),
      );
    }
    if (step.dark != null) {
      ref
          .read(settingsProvider.notifier)
          .update(
            (s) => s.copyWith(themeMode: step.dark! ? AppThemeMode.dark : AppThemeMode.light),
          );
    }
    if (step.toast) {
      final t = context.t;
      _toasts.show(
        ToastData(
          title: t.transferComplete,
          message: 'IMG_2041.jpg',
          detail: formatBytes(3 * 1024 * 1024 + 420 * 1024),
          severity: ToastSeverity.success,
          thumbnail: Container(color: const Color(0xFF7FB8E6)),
          actions: [
            ToastAction(label: t.open, onPressed: () {}),
            ToastAction(label: t.showInFolder, onPressed: () {}),
          ],
          duration: const Duration(seconds: 30),
        ),
      );
      _toasts.info(t.toastDeviceConnected('Pixel 8'));
    }
  }

  Future<void> _capture(int index, _TourStep step) async {
    if (!mounted) return;
    final key = step.section == 5 ? _shellBoundary : _appBoundary;
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    try {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final name =
          'step-${index.toString().padLeft(2, '0')}-s${step.section}'
          '${step.shellWidth == null ? '' : '-w${step.shellWidth!.round()}'}'
          '${step.dark == true ? '-dark' : ''}.png';
      final file = File('$_shotsDir/$name');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      debugPrint('TOUR saved ${file.path}');
    } catch (e) {
      debugPrint('TOUR capture failed: $e');
    }
  }

  @override
  void dispose() {
    _tour?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      body: Column(
        children: [
          // Toolbar.
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                const PepoLogo(size: 24),
                const SizedBox(width: Space.s),
                Text('Galería de widgets', style: text.bodyStrong),
                const Spacer(),
                DropdownButtonFluent<AppThemeMode>(
                  value: settings.themeMode,
                  items: const [
                    DropdownItem(
                      value: AppThemeMode.light,
                      label: 'Claro',
                      icon: FluentIcons.weather_sunny_20_regular,
                    ),
                    DropdownItem(
                      value: AppThemeMode.dark,
                      label: 'Oscuro',
                      icon: FluentIcons.weather_moon_20_regular,
                    ),
                    DropdownItem(value: AppThemeMode.system, label: 'Según el sistema'),
                  ],
                  onChanged: (v) => notifier.update((s) => s.copyWith(themeMode: v)),
                ),
                const SizedBox(width: Space.s),
                DropdownButtonFluent<String>(
                  value: settings.locale,
                  items: const [
                    DropdownItem(value: 'es', label: 'Español'),
                    DropdownItem(value: 'en', label: 'English'),
                    DropdownItem(value: 'system', label: 'Sistema'),
                  ],
                  onChanged: (v) => notifier.update((s) => s.copyWith(locale: v)),
                ),
                const SizedBox(width: Space.l),
                ToggleSwitch(
                  value: settings.animations,
                  label: 'Animaciones',
                  onChanged: (v) => notifier.update((s) => s.copyWith(animations: v)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 180,
                  child: ListView(
                    padding: const EdgeInsets.all(Space.s),
                    children: [
                      for (var i = 0; i < _sections.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Pressable(
                            onTap: () => setState(() => _index = i),
                            builder: (context, states, _) => Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: Space.m),
                              decoration: BoxDecoration(
                                color: i == _index ? colors.subtleHover : null,
                                borderRadius: Radii.controlRadius,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _sections[i].icon,
                                    size: 16,
                                    color: i == _index ? colors.accent : colors.textPrimary,
                                  ),
                                  const SizedBox(width: Space.m),
                                  Text(_sections[i].title, style: text.body),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                VerticalDivider(width: 1, color: colors.divider),
                Expanded(
                  child: FadeSlideSwitcher(
                    childKey: ValueKey(_index),
                    child: _sections[_index].builder(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helpers

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.xl),
      children: [
        Text(title, style: context.text.title),
        const SizedBox(height: Space.xl),
        ...children,
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, {required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.bodyStrong),
          const SizedBox(height: Space.m),
          child,
        ],
      ),
    );
  }
}

Widget _wrap(List<Widget> children) => Wrap(
  spacing: Space.m,
  runSpacing: Space.m,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

// -----------------------------------------------------------------------------
// Tokens

class _TokensSection extends StatelessWidget {
  const _TokensSection();

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    String hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final samples = <String, TextStyle>{
      'Caption 12/16': text.caption,
      'Body 14/20': text.body,
      'BodyStrong 14/20 · 600': text.bodyStrong,
      'BodyLarge 18/24': text.bodyLarge,
      'Subtitle 20/28 · 600': text.subtitle,
      'Title 28/36 · 600': text.title,
      'TitleLarge 40/52 · 600': text.titleLarge,
    };
    return _Page(
      title: 'Tokens',
      children: [
        _Group(
          'Colores (${colors.isDark ? 'oscuro' : 'claro'})',
          child: _wrap([
            for (final e in colors.toMap().entries)
              SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: e.value,
                        borderRadius: Radii.controlRadius,
                        border: Border.all(color: colors.cardStroke),
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(e.key, style: text.caption.copyWith(color: colors.textPrimary)),
                    Text(hex(e.value), style: text.caption.copyWith(color: colors.textTertiary)),
                  ],
                ),
              ),
          ]),
        ),
        _Group(
          'Tipografía',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in samples.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.m),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      SizedBox(width: 200, child: Text(e.key, style: text.caption)),
                      Expanded(child: Text('Transferir archivos al móvil', style: e.value)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _Group(
          'Radios y sombras',
          child: _wrap([
            for (final (label, radius, shadow) in [
              ('Control · 4', Radii.controlRadius, <BoxShadow>[]),
              ('Tarjeta · 8', Radii.cardRadius, <BoxShadow>[]),
              ('Zona de soltar · 12', Radii.dropZoneRadius, <BoxShadow>[]),
              ('Flyout', Radii.cardRadius, PepoShadows.flyout),
              ('Diálogo', Radii.cardRadius, PepoShadows.dialog),
              ('Toast', Radii.cardRadius, PepoShadows.toast),
            ])
              Container(
                width: 120,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.flyoutSurface,
                  borderRadius: radius,
                  border: Border.all(color: colors.cardStroke),
                  boxShadow: shadow,
                ),
                child: Text(label, style: text.caption),
              ),
          ]),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Buttons

class _ButtonsSection extends StatefulWidget {
  const _ButtonsSection();

  @override
  State<_ButtonsSection> createState() => _ButtonsSectionState();
}

class _ButtonsSectionState extends State<_ButtonsSection> {
  int _tab = 0;
  String _type = 'all';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return _Page(
      title: 'Botones',
      children: [
        _Group(
          'FluentButton',
          child: _wrap([
            FluentButton.primary(
              label: t.addToPhone,
              icon: FluentIcons.add_16_regular,
              onPressed: () {},
            ),
            FluentButton(label: t.addFiles, onPressed: () {}),
            FluentButton.subtle(label: t.cancel, onPressed: () {}),
            const FluentButton.primary(label: 'Deshabilitado'),
            const FluentButton(label: 'Deshabilitado'),
            const FluentButton.subtle(label: 'Deshabilitado'),
            FluentButton.primary(
              label: 'Cargando',
              loading: _loading,
              onPressed: () async {
                setState(() => _loading = true);
                await Future<void>.delayed(const Duration(seconds: 2));
                if (mounted) setState(() => _loading = false);
              },
            ),
            FluentButton(label: 'Pequeño', size: FluentButtonSize.small, onPressed: () {}),
            FluentButton(label: 'Grande', size: FluentButtonSize.large, onPressed: () {}),
            FluentButton(
              label: t.download,
              icon: FluentIcons.arrow_download_16_regular,
              tooltip: 'Ctrl+S',
              onPressed: () {},
            ),
          ]),
        ),
        _Group(
          'FluentIconButton',
          child: _wrap([
            FluentIconButton(
              icon: FluentIcons.more_horizontal_16_regular,
              tooltip: t.more,
              onPressed: () {},
            ),
            FluentIconButton(
              icon: FluentIcons.dismiss_16_regular,
              tooltip: t.close,
              onPressed: () {},
            ),
            FluentIconButton(
              icon: FluentIcons.grid_20_regular,
              tooltip: t.view,
              selected: true,
              onPressed: () {},
            ),
            FluentIconButton(
              icon: FluentIcons.arrow_sync_16_regular,
              tooltip: t.refresh,
              style: FluentButtonStyle.secondary,
              onPressed: () {},
            ),
            FluentIconButton(
              icon: FluentIcons.send_20_regular,
              tooltip: t.mobileSendToPc,
              style: FluentButtonStyle.primary,
              size: 40,
              iconSize: 20,
              onPressed: () {},
            ),
            const FluentIconButton(icon: FluentIcons.delete_16_regular, tooltip: 'Deshabilitado'),
          ]),
        ),
        _Group(
          'DropdownButtonFluent',
          child: _wrap([
            DropdownButtonFluent<String>(
              value: _type,
              items: [
                DropdownItem(value: 'all', label: t.all),
                DropdownItem(value: 'photos', label: t.photos, icon: FluentIcons.image_20_regular),
                DropdownItem(value: 'videos', label: t.videos, icon: FluentIcons.video_20_regular),
              ],
              labelBuilder: (s) => '${t.type}: ${s?.label ?? ''}',
              onChanged: (v) => setState(() => _type = v),
            ),
            DropdownButtonFluent<String>(
              value: 'pixel8',
              style: FluentButtonStyle.subtle,
              items: [
                DropdownItem(value: 'pixel8', label: t.galleryOf('Pixel 8')),
                DropdownItem(value: 'ipad', label: t.galleryOf('iPad de Daniel')),
                DropdownItem(value: 'all', label: t.allDevices),
              ],
              onChanged: (_) {},
            ),
          ]),
        ),
        _Group(
          'PillTabs',
          child: PillTabs(
            tabs: [t.photos, t.videos, t.all],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Controls

class _ControlsSection extends StatefulWidget {
  const _ControlsSection();

  @override
  State<_ControlsSection> createState() => _ControlsSectionState();
}

class _ControlsSectionState extends State<_ControlsSection> {
  bool _toggle = true;
  bool _check = false;
  bool _circle = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final t = context.t;
    return _Page(
      title: 'Controles',
      children: [
        _Group(
          'ToggleSwitch',
          child: _wrap([
            ToggleSwitch(
              value: _toggle,
              label: t.animations,
              onChanged: (v) => setState(() => _toggle = v),
            ),
            const ToggleSwitch(value: true, label: 'Deshabilitado', onChanged: null),
            const ToggleSwitch(value: false, onChanged: null),
          ]),
        ),
        _Group(
          'PepoCheckbox',
          child: _wrap([
            PepoCheckbox(
              value: _check,
              label: t.separateByDevice,
              onChanged: (v) => setState(() => _check = v),
            ),
            const PepoCheckbox(value: true, label: 'Deshabilitado', onChanged: null),
            Container(
              width: 120,
              height: 90,
              alignment: Alignment.topLeft,
              padding: const EdgeInsets.all(Space.s),
              decoration: BoxDecoration(
                color: const Color(0xFF5A6B7C),
                borderRadius: Radii.controlRadius,
              ),
              child: PepoCheckbox.circle(
                value: _circle,
                onChanged: (v) => setState(() => _circle = v),
              ),
            ),
          ]),
        ),
        _Group(
          'PepoTextField',
          child: _wrap([
            SizedBox(
              width: 240,
              child: PepoTextField(placeholder: t.pcNamePlaceholder, label: t.myPc),
            ),
            SizedBox(
              width: 240,
              child: PepoTextField(
                placeholder: t.search,
                leading: const Icon(FluentIcons.search_20_regular),
              ),
            ),
            const SizedBox(
              width: 240,
              child: PepoTextField(placeholder: 'Con error', errorText: 'Código incorrecto'),
            ),
            const SizedBox(
              width: 240,
              child: PepoTextField(placeholder: 'Deshabilitado', enabled: false),
            ),
          ]),
        ),
        _Group(
          'StatusPill · BatteryIndicator',
          child: _wrap([
            StatusPill(status: ConnectionStatus.connected, label: t.statusConnected),
            StatusPill(status: ConnectionStatus.connecting, label: t.statusConnecting),
            StatusPill(status: ConnectionStatus.offline, label: t.statusOffline),
            const BatteryIndicator(level: 100, charging: true),
            const BatteryIndicator(level: 64),
            const BatteryIndicator(level: 12),
          ]),
        ),
        _Group(
          'DeviceIcon',
          child: _wrap([
            for (final size in [20.0, 24.0, 32.0, 48.0])
              for (final kind in DeviceKind.values) DeviceIcon(kind: kind, size: size),
          ]),
        ),
        _Group(
          'PepoBadge',
          child: _wrap([
            const PepoBadge(count: 3),
            const PepoBadge(count: 120),
            const PepoBadge(count: 1, dot: true),
            Badged(
              count: 7,
              child: Icon(FluentIcons.alert_20_regular, size: 20, color: colors.textPrimary),
            ),
          ]),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Feedback

class _FeedbackSection extends StatefulWidget {
  const _FeedbackSection();

  @override
  State<_FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends State<_FeedbackSection> {
  double _progress = 0.4;
  int _glowKey = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final t = context.t;
    return _Page(
      title: 'Feedback',
      children: [
        _Group(
          'InfoBar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoBar(title: t.pairSubtitle, onClose: () {}),
              const SizedBox(height: Space.s),
              InfoBar(
                title: t.pairDone,
                message: t.pairDoneBody,
                severity: InfoBarSeverity.success,
                onClose: () {},
              ),
              const SizedBox(height: Space.s),
              InfoBar(
                title: t.errorPermission,
                severity: InfoBarSeverity.caution,
                action: FluentButton(
                  label: t.errorPermissionAction,
                  size: FluentButtonSize.small,
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: Space.s),
              InfoBar(
                title: t.errorNetwork,
                message: t.errorTryAgain,
                severity: InfoBarSeverity.critical,
                onClose: () {},
              ),
            ],
          ),
        ),
        _Group(
          'ThinProgressBar · ProgressRing',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 360,
                child: SmoothThinProgressBar(
                  value: _progress,
                  key: ValueKey(_progress >= 1 ? 'done' : 'run'),
                ),
              ),
              const SizedBox(height: Space.m),
              _wrap([
                FluentButton(
                  label: '−10 %',
                  size: FluentButtonSize.small,
                  onPressed: () => setState(() => _progress = (_progress - 0.1).clamp(0, 1)),
                ),
                FluentButton(
                  label: '+10 %',
                  size: FluentButtonSize.small,
                  onPressed: () => setState(() => _progress = (_progress + 0.1).clamp(0, 1)),
                ),
                FluentButton(
                  label: 'Completar',
                  size: FluentButtonSize.small,
                  onPressed: () => setState(() => _progress = 1),
                ),
                FluentButton(
                  label: 'Reiniciar',
                  size: FluentButtonSize.small,
                  onPressed: () => setState(() => _progress = 0.05),
                ),
                Text(formatPercent(_progress), style: context.text.caption),
                const SizedBox(width: Space.l),
                const ProgressRing(),
                ProgressRing(value: _progress),
                const SizedBox(width: 360, child: ThinProgressBar(value: null)),
              ]),
            ],
          ),
        ),
        _Group(
          'Skeleton',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _wrap([
                for (var i = 0; i < 4; i++)
                  const Skeleton(width: 120, height: 90, borderRadius: Radii.controlRadius),
              ]),
              const SizedBox(height: Space.s),
              const Skeleton(width: 240),
              const SizedBox(height: Space.xs),
              const Skeleton(width: 160, height: 12),
            ],
          ),
        ),
        _Group(
          'Toast · Dialog · ContextMenu',
          child: _wrap([
            FluentButton(label: 'Toast', onPressed: () => _toasts.info(t.toastCopied)),
            FluentButton(
              label: t.transferComplete,
              onPressed: () => _toasts.show(
                ToastData(
                  title: t.transferComplete,
                  message: 'IMG_2041.jpg',
                  detail: formatBytes(3 * 1024 * 1024 + 420 * 1024),
                  severity: ToastSeverity.success,
                  thumbnail: Container(color: const Color(0xFF7FB8E6)),
                  actions: [
                    ToastAction(label: t.open, onPressed: () {}),
                    ToastAction(label: t.showInFolder, onPressed: () {}),
                  ],
                ),
              ),
            ),
            FluentButton(
              label: 'Error',
              onPressed: () =>
                  _toasts.error(t.transferFailed('video.mp4'), message: t.errorNetwork),
            ),
            FluentButton(
              label: 'Diálogo',
              onPressed: () => showPepoDialog<void>(
                context,
                builder: (context) => PepoDialog(
                  title: t.forgetDeviceConfirm('Pixel 8'),
                  content: Text(t.forgetDeviceBody),
                  actions: [
                    FluentButton(label: t.cancel, onPressed: () => Navigator.of(context).pop()),
                    FluentButton.primary(
                      label: t.remove,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            ContextMenuRegion(
              items: (context) => [
                MenuItem(
                  label: t.open,
                  icon: FluentIcons.open_16_regular,
                  shortcut: 'Enter',
                  onTap: () {},
                ),
                MenuItem(
                  label: t.showInFolder,
                  icon: FluentIcons.folder_open_16_regular,
                  onTap: () {},
                ),
                MenuItem(
                  label: t.copy,
                  icon: FluentIcons.copy_16_regular,
                  shortcut: 'Ctrl+C',
                  onTap: () {},
                ),
                const MenuDivider(),
                MenuItem(
                  label: t.deleteFromPhone,
                  icon: FluentIcons.delete_16_regular,
                  destructive: true,
                  onTap: () {},
                ),
              ],
              child: PepoCard(
                onTap: () {},
                child: SizedBox(
                  width: 160,
                  child: Text('Clic derecho aquí', style: context.text.body),
                ),
              ),
            ),
          ]),
        ),
        _Group(
          'EmptyState',
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: Radii.cardRadius,
              border: Border.all(color: colors.cardStroke),
            ),
            child: EmptyState(
              icon: FluentIcons.image_48_regular,
              title: t.galleryEmptyTitle,
              message: t.galleryEmptyBody,
              actionLabel: t.addDevice,
              onAction: () {},
            ),
          ),
        ),
        _Group(
          'NewItemGlow',
          child: _wrap([
            NewItemGlow(
              key: ValueKey(_glowKey),
              child: Container(
                width: 160,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF9DB7C8),
                  borderRadius: Radii.controlRadius,
                ),
              ),
            ),
            FluentButton(label: 'Repetir', onPressed: () => setState(() => _glowKey++)),
          ]),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Motion

class _MotionSection extends StatefulWidget {
  const _MotionSection();

  @override
  State<_MotionSection> createState() => _MotionSectionState();
}

class _MotionSectionState extends State<_MotionSection> {
  bool _alt = false;
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final motion = Motion.of(context);
    return _Page(
      title: 'Movimiento',
      children: [
        _Group(
          'Motion: ${motion.enabled ? 'on' : 'off'} · fast ${motion.fast.inMilliseconds} · normal ${motion.normal.inMilliseconds} · page ${motion.page.inMilliseconds} · glow ${motion.glow.inMilliseconds}',
          child: const SizedBox.shrink(),
        ),
        _Group(
          'Pressable (tile con luz)',
          child: _wrap([
            Pressable(
              onTap: () => setState(() => _taps++),
              hoverLight: true,
              borderRadius: Radii.cardRadius,
              child: Container(
                width: 200,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: Radii.cardRadius,
                  border: Border.all(color: colors.cardStroke),
                ),
                child: Text('Pulsado $_taps', style: text.body),
              ),
            ),
            Pressable(
              onTap: () {},
              onSecondaryTap: (pos) => showContextMenu(
                context,
                position: pos,
                items: [MenuItem(label: 'Abrir', icon: FluentIcons.open_16_regular, onTap: () {})],
              ),
              child: Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF6E8CA0),
                  borderRadius: Radii.controlRadius,
                ),
                child: Text('Miniatura', style: text.caption.copyWith(color: Colors.white)),
              ),
            ),
            const Pressable(
              child: SizedBox(width: 120, height: 40, child: Center(child: Text('Sin callbacks'))),
            ),
          ]),
        ),
        _Group(
          'FadeSlideSwitcher',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FluentButton(label: 'Cambiar', onPressed: () => setState(() => _alt = !_alt)),
              const SizedBox(height: Space.m),
              SizedBox(
                height: 80,
                child: FadeSlideSwitcher(
                  childKey: ValueKey(_alt),
                  child: Text(_alt ? 'Galería' : 'Transferencias', style: text.title),
                ),
              ),
            ],
          ),
        ),
        _Group(
          'PepoLogo',
          child: _wrap([
            const PepoLogo(size: 128),
            const PepoLogo(size: 64),
            const PepoLogo(size: 32),
            const PepoLogo(size: 16),
            PepoLogo(size: 64, withBackground: false, color: colors.textPrimary),
            Container(
              padding: const EdgeInsets.all(Space.s),
              color: const Color(0xFF202020),
              child: const PepoLogo(size: 32, withBackground: false),
            ),
          ]),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Shell

class _ShellSection extends ConsumerStatefulWidget {
  const _ShellSection({required this.width, required this.onWidthChanged});

  final double width;
  final ValueChanged<double> onWidthChanged;

  @override
  ConsumerState<_ShellSection> createState() => _ShellSectionState();
}

class _ShellSectionState extends ConsumerState<_ShellSection> {
  late final GoRouter _router = buildRouter(
    actions: ShellActions(
      systemName: 'DESKTOP-GALLERY',
      onRefresh: (context) => _toasts.info('F5'),
      onOpenDownloads: (context) => _toasts.info('Abrir carpeta de descargas'),
      onClearActivity: (context) => _toasts.info('Borrar actividad'),
      activityPanelBuilder: (context) => ListView(
        padding: const EdgeInsets.all(Space.s),
        children: [
          for (var i = 0; i < 6; i++)
            Pressable(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(Space.s),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9DB7C8),
                        borderRadius: Radii.controlRadius,
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.t.activityNewPhoto('Pixel 8'), style: context.text.body),
                          Text('hoy, 15:5$i', style: context.text.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final transfers = ref.read(transfersProvider.notifier) as FakeTransfersNotifier;
    final width = widget.width;
    return _Page(
      title: 'Shell',
      children: [
        _wrap([
          for (final w in [400.0, 700.0, 1100.0, 1400.0])
            FluentButton(
              label: '${w.round()} px',
              style: width == w ? FluentButtonStyle.primary : FluentButtonStyle.secondary,
              onPressed: () => widget.onWidthChanged(w),
            ),
          const SizedBox(width: Space.l),
          FluentButton(label: 'Avanzar transferencias', onPressed: () => transfers.tick(0.25)),
          FluentButton(
            label: 'Nueva transferencia',
            onPressed: () => transfers.add(
              fakeTransfer(
                id: DateTime.now().millisecondsSinceEpoch % 100000,
                deviceId: 'pixel8',
                name: 'DSC_${DateTime.now().second}.jpg',
              ),
            ),
          ),
        ]),
        const SizedBox(height: Space.l),
        // In tour mode the shell may be wider than the window: the capture
        // rasterises the boundary itself, so it is laid out unconstrained.
        Align(
          alignment: Alignment.topLeft,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final box = RepaintBoundary(
                key: _shellBoundary,
                child: Container(
                  width: _tourSeconds > 0 ? width : width.clamp(320, constraints.maxWidth),
                  height: 720,
                  decoration: BoxDecoration(border: Border.all(color: colors.cardStroke)),
                  child: ClipRect(child: Router.withConfig(config: _router)),
                ),
              );
              if (_tourSeconds > 0) {
                return UnconstrainedBox(
                  alignment: Alignment.topLeft,
                  clipBehavior: Clip.hardEdge,
                  child: box,
                );
              }
              return box;
            },
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Floating surfaces, rendered inline so they can be inspected without a click.

class _SurfacesSection extends StatelessWidget {
  const _SurfacesSection();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final now = DateTime.now();
    return _Page(
      title: 'Superficies',
      children: [
        _Group(
          'HubMenu',
          child: HubMenu(
            pcName: 'PC de Daniel',
            systemName: 'DESKTOP-GALLERY',
            devices: [
              HubDevice(
                id: 'pixel8',
                name: 'Pixel 8',
                kind: DeviceKind.phone,
                connected: true,
                lastSeen: now.subtract(const Duration(minutes: 9)),
                battery: 100,
                charging: true,
              ),
              HubDevice(
                id: 'ipad',
                name: 'iPad de Daniel',
                kind: DeviceKind.tablet,
                lastSeen: now.subtract(const Duration(days: 1, hours: 3)),
                battery: 64,
              ),
              HubDevice(
                id: 'georgy',
                name: 'GeorGY',
                kind: DeviceKind.laptop,
                connecting: true,
                lastSeen: DateTime(2026, 3, 12, 18, 4),
              ),
            ],
            selectedDeviceId: 'pixel8',
            doNotDisturb: false,
            onRename: (_) {},
            onAddDevice: () {},
            onManageDevices: () {},
            onSelectDevice: (_) {},
            onDoNotDisturbChanged: (_) {},
          ),
        ),
        _Group(
          'ContextMenu',
          child: ContextMenu(
            width: 240,
            items: [
              MenuItem(
                label: t.open,
                icon: FluentIcons.open_16_regular,
                shortcut: 'Enter',
                onTap: () {},
              ),
              MenuItem(
                label: t.showInFolder,
                icon: FluentIcons.folder_open_16_regular,
                onTap: () {},
              ),
              MenuItem(
                label: t.copy,
                icon: FluentIcons.copy_16_regular,
                shortcut: 'Ctrl+C',
                onTap: () {},
              ),
              MenuItem(
                label: t.saveAs,
                icon: FluentIcons.save_16_regular,
                shortcut: 'Ctrl+S',
                onTap: () {},
              ),
              const MenuDivider(),
              MenuItem(label: t.viewLarge, checked: true, onTap: () {}),
              MenuItem(label: t.viewMedium, checked: false, onTap: () {}),
              const MenuDivider(),
              MenuItem(
                label: t.deleteFromPhone,
                icon: FluentIcons.delete_16_regular,
                destructive: true,
                onTap: () {},
              ),
              MenuItem(label: t.remove, icon: FluentIcons.dismiss_16_regular, enabled: false),
            ],
          ),
        ),
        _Group(
          'PepoDialog',
          child: SizedBox(
            height: 220,
            child: PepoDialog(
              title: t.forgetDeviceConfirm('Pixel 8'),
              content: Text(t.forgetDeviceBody),
              actions: [
                FluentButton(label: t.cancel, onPressed: () {}),
                FluentButton.primary(label: t.remove, onPressed: () {}),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
