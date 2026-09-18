import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/features/pairing/pairing_helpers.dart';
import 'package:pepoconnect/shared/i18n/l10n.dart';

void main() {
  late AppLocalizations t;

  setUpAll(() async {
    t = await AppLocalizations.delegate.load(const Locale('es'));
  });

  group('describePairingError', () {
    test('expired link', () {
      final message = describePairingError(
        HandshakeException('code expired', code: ErrorCode.timeout),
        t,
      );
      expect(message, 'El enlace ha caducado. Genera otro código en el PC');
    });

    test('not a PepoConnect code', () {
      final message = describePairingError(
        HandshakeException('not a PepoConnect code', code: ErrorCode.badRequest),
        t,
      );
      expect(message, 'Eso no es un código de PepoConnect');
    });

    test('rejected proof: wrong code in the code flow, stale link otherwise', () {
      final rejected = HandshakeException('pairing rejected', code: ErrorCode.rejected);
      expect(
        describePairingError(rejected, t, codeFlow: true),
        'Código incorrecto. Comprueba los seis dígitos',
      );
      expect(
        describePairingError(rejected, t),
        'El enlace ha caducado. Genera otro código en el PC',
      );
    });

    test('unreachable PC', () {
      const expected = 'No se encuentra el PC. Comprueba que los dos están en la misma red Wi-Fi';
      expect(describePairingError(const SocketException('refused'), t), expected);
      expect(describePairingError(TimeoutException('slow'), t), expected);
    });

    test('identity changed and unknown errors', () {
      expect(
        describePairingError(HandshakeException('device identity changed'), t),
        'La identidad del PC ha cambiado. Vuelve a buscarlo',
      );
      expect(describePairingError(StateError('x'), t), t.pairFailedBody);
    });
  });

  group('parseHostPort', () {
    test('host and port', () {
      expect(parseHostPort('192.168.1.20:47473'), (host: '192.168.1.20', port: 47473));
      expect(parseHostPort(' georgy.local:1234 '), (host: 'georgy.local', port: 1234));
    });

    test('host only', () {
      expect(parseHostPort('192.168.1.20'), (host: '192.168.1.20', port: null));
      expect(parseHostPort('fe80::1'), (host: 'fe80::1', port: null));
      expect(parseHostPort('[fe80::1]:47473'), (host: 'fe80::1', port: 47473));
    });

    test('rejects nonsense', () {
      expect(parseHostPort(''), isNull);
      expect(parseHostPort('192.168.1.20:'), isNull);
      expect(parseHostPort(':47473'), isNull);
      expect(parseHostPort('192.168.1.20:99999'), isNull);
      expect(parseHostPort('192.168.1.20:abc'), isNull);
      expect(parseHostPort('192.168.1 .20'), isNull);
    });
  });

  test('groupCode and platformLabel', () {
    expect(groupCode('482913'), '482 913');
    expect(groupCode('12'), '12');
    expect(platformLabel(DevicePlatform.windows), 'Windows');
    expect(platformLabel(DevicePlatform.unknown), '');
  });
}
