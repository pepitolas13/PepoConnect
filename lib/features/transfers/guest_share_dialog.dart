import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart'
    show EngineEvent, GuestMode, GuestSession, GuestShareChangedEvent, PepoEngine;
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_services.dart';
import '../../platform/open_helper.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/toast.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/util/format.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_dialog.dart';
import '../../shared/widgets/pepo_text_field.dart';
import '../../shared/widgets/pill_tabs.dart';
import '../../state/engine_providers.dart';
import 'file_type_icon.dart';
import 'send_files.dart';

enum _Step { compose, ready }

class _PickedFile {
  const _PickedFile(this.path, this.size);

  final String path;
  final int size;

  String get name => p.basename(path);
}

class _GuestLog {
  const _GuestLog({required this.icon, required this.text, this.path, this.critical = false});

  final IconData icon;
  final String text;
  final String? path;
  final bool critical;
}

/// "Share with anyone": a one-time link served by the PC so a guest without
/// the app can download (send mode) or upload (receive mode) files from a
/// browser on the same network. Shows the QR, the URL, the countdown and
/// what the guest does, live.
class GuestShareDialog extends ConsumerStatefulWidget {
  const GuestShareDialog({super.key, this.initialPaths = const []});

  /// Files pre-selected for send mode.
  final List<String> initialPaths;

  static const int messageLimit = 250;

  static Future<void> show(BuildContext context, {List<String> initialPaths = const []}) =>
      showPepoDialog<void>(context, builder: (_) => GuestShareDialog(initialPaths: initialPaths));

  @override
  ConsumerState<GuestShareDialog> createState() => _GuestShareDialogState();
}

class _GuestShareDialogState extends ConsumerState<GuestShareDialog> {
  _Step _step = _Step.compose;

  /// 0 = send, 1 = receive.
  int _mode = 0;
  final List<_PickedFile> _files = [];
  final TextEditingController _message = TextEditingController();
  bool _creating = false;
  List<String> _urls = const [];
  Duration? _remaining;
  bool _expired = false;
  final List<_GuestLog> _log = [];
  Timer? _tick;
  StreamSubscription<EngineEvent>? _events;

  PepoEngine get _engine => ref.read(engineProvider);

  @override
  void initState() {
    super.initState();
    _events = _engine.events.listen(_onEvent);
    final split = splitBlockedExecutables(ref, widget.initialPaths);
    split.allowed.forEach(_addPath);
    if (split.blocked.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(explainBlockedExecutables(context, split.blocked));
      });
    }
    final session = _engine.guestSession;
    if (session != null) unawaited(_restore(session));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _events?.cancel();
    _message.dispose();
    super.dispose();
  }

  /// The dialog was reopened while a link is still alive: show it again.
  Future<void> _restore(GuestSession session) async {
    final addresses = await _engine.localAddresses();
    if (!mounted) return;
    setState(() {
      _mode = session.mode == GuestMode.send ? 0 : 1;
      _urls = session.urls(addresses, _engine.guestPort);
      _step = _Step.ready;
      _expired = false;
      _remaining = session.remaining;
    });
    _startTicking();
  }

  void _addPath(String path) {
    if (_files.any((f) => f.path == path)) return;
    final file = File(path);
    if (!file.existsSync()) return;
    _files.add(_PickedFile(path, file.lengthSync()));
  }

  Future<void> _pickFiles() async {
    final picked = await FilePicker.pickFiles(dialogTitle: context.t.addFiles);
    if (!mounted) return;
    final split = splitBlockedExecutables(ref, [
      for (final f in picked)
        if (f.path != null) f.path!,
    ]);
    setState(() => split.allowed.forEach(_addPath));
    await explainBlockedExecutables(context, split.blocked);
  }

  Future<void> _create() async {
    final t = context.t;
    final toasts = ref.read(toastServiceProvider);
    setState(() => _creating = true);
    try {
      final text = _message.text.trim();
      final message = text.isEmpty ? null : text;
      final urls = _mode == 0
          ? await _engine.startGuestSend(_files.map((f) => f.path).toList(), message: message)
          : await _engine.startGuestReceive(message: message);
      if (!mounted) return;
      setState(() {
        _urls = urls;
        _step = _Step.ready;
        _expired = false;
        _log.clear();
        _remaining = _engine.guestSession?.remaining;
      });
      _startTicking();
    } catch (e) {
      toasts.show(
        ToastData(title: t.trGuestFailed, message: '$e', severity: ToastSeverity.critical),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _startTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final session = _engine.guestSession;
      setState(() {
        if (session == null) {
          _expired = true;
          _remaining = null;
        } else {
          _remaining = session.remaining;
        }
      });
    });
  }

  void _onEvent(EngineEvent e) {
    if (e is! GuestShareChangedEvent || !mounted) return;
    final t = context.t;
    setState(() {
      switch (e.kind) {
        case 'opened':
          _log.add(
            _GuestLog(
              icon: FluentIcons.people_20_regular,
              text: t.trGuestOpenedBy(e.remote ?? '?'),
            ),
          );
        case 'downloaded':
          _log.add(
            _GuestLog(
              icon: FluentIcons.arrow_download_20_regular,
              text: t.trGuestDownloaded(e.fileName ?? ''),
            ),
          );
        case 'uploaded':
          _log.add(
            _GuestLog(
              icon: FluentIcons.arrow_download_20_regular,
              text: t.trGuestReceived(e.fileName ?? ''),
              path: e.path,
            ),
          );
        case 'uploadFailed':
          _log.add(
            _GuestLog(
              icon: FluentIcons.error_circle_20_regular,
              text: t.trGuestUploadFailed(e.fileName ?? ''),
              critical: true,
            ),
          );
        case 'expired' || 'cancelled':
          _expired = true;
          _remaining = null;
          _tick?.cancel();
        default:
          break;
      }
      if (_log.length > 50) _log.removeRange(0, _log.length - 50);
    });
  }

  void _cancelShare() {
    _engine.cancelGuestShare();
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _step = _Step.compose;
      _urls = const [];
      _log.clear();
      _expired = false;
      _remaining = null;
    });
  }

  Future<void> _copy(String url) async {
    final title = context.t.toastCopied;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ref.read(toastServiceProvider).show(ToastData(title: title, message: url));
  }

  static String _clock(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) =>
      _step == _Step.compose ? _buildCompose(context) : _buildReady(context);

  Widget _buildCompose(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final locale = Localizations.localeOf(context).toString();
    final canCreate = !_creating && (_mode == 1 || _files.isNotEmpty);
    return PepoDialog(
      title: t.trShareWithAnyone,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PillTabs(
              tabs: [t.trGuestSend, t.trGuestReceive],
              index: _mode,
              onChanged: (i) => setState(() => _mode = i),
            ),
          ),
          const SizedBox(height: Space.m),
          Text(
            _mode == 0 ? t.trGuestSendBody : t.trGuestReceiveBody,
            style: text.caption.copyWith(color: colors.textSecondary),
          ),
          if (_mode == 0) ...[
            const SizedBox(height: Space.m),
            if (_files.isEmpty)
              Text(t.trGuestNoFiles, style: text.caption.copyWith(color: colors.textTertiary))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 176),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in _files)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            FileTypeIcon(name: f.name, size: 24),
                            const SizedBox(width: Space.s),
                            Expanded(
                              child: Text(
                                f.name,
                                style: text.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: Space.s),
                            Text(
                              formatBytes(f.size, locale: locale),
                              style: text.caption.copyWith(color: colors.textSecondary),
                            ),
                            FluentIconButton(
                              icon: FluentIcons.dismiss_16_regular,
                              tooltip: t.remove,
                              size: 28,
                              onPressed: () => setState(() => _files.remove(f)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: Space.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: FluentButton.subtle(
                icon: FluentIcons.add_16_regular,
                label: t.add,
                onPressed: _creating ? null : _pickFiles,
              ),
            ),
          ],
          const SizedBox(height: Space.m),
          PepoTextField(
            controller: _message,
            placeholder: t.trGuestMessage,
            maxLines: 3,
            maxLength: GuestShareDialog.messageLimit,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_message.text.characters.length}/${GuestShareDialog.messageLimit}',
              style: text.caption.copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ),
      actions: [
        FluentButton(label: t.cancel, onPressed: () => Navigator.of(context).pop()),
        FluentButton.primary(
          label: t.trGuestCreateLink,
          loading: _creating,
          onPressed: canCreate ? _create : null,
        ),
      ],
    );
  }

  Widget _buildReady(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final url = _urls.isEmpty ? null : _urls.first;
    final remaining = _remaining;
    return PepoDialog(
      title: _mode == 0 ? t.trGuestReadyTitle : t.trGuestReceiveReadyTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (url == null)
            Text(t.trGuestNoAddress, style: text.body, textAlign: TextAlign.center)
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(Space.m),
                decoration: BoxDecoration(color: Colors.white, borderRadius: Radii.cardRadius),
                child: QrImageView(
                  data: url,
                  size: 200,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.m),
            Text(
              t.trGuestScanHint,
              style: text.caption.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.m),
            Row(
              children: [
                Expanded(child: SelectableText(url, style: text.body, maxLines: 2)),
                const SizedBox(width: Space.s),
                FluentButton(
                  icon: FluentIcons.copy_16_regular,
                  label: t.trGuestCopyLink,
                  onPressed: () => _copy(url),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.s),
          Text(
            _expired
                ? t.trGuestExpired
                : t.trGuestExpiresIn(remaining == null ? '--:--' : _clock(remaining)),
            style: text.caption.copyWith(color: _expired ? colors.critical : colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.m),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: Space.m),
          if (_log.isEmpty)
            Text(t.trGuestWaiting, style: text.caption.copyWith(color: colors.textTertiary))
          else
            for (final entry in _log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      entry.icon,
                      size: 16,
                      color: entry.critical ? colors.critical : colors.textSecondary,
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Text(
                        entry.text,
                        style: text.body.copyWith(
                          color: entry.critical ? colors.critical : colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.path != null)
                      FluentButton.subtle(
                        label: t.showInFolder,
                        size: FluentButtonSize.small,
                        onPressed: () => OpenHelper.showInFolder(entry.path!),
                      ),
                  ],
                ),
              ),
        ],
      ),
      actions: _expired
          ? [
              FluentButton(label: t.close, onPressed: () => Navigator.of(context).pop()),
              FluentButton.primary(label: t.trGuestNewLink, onPressed: _reset),
            ]
          : [FluentButton(label: t.cancel, onPressed: _cancelShare)],
    );
  }
}
