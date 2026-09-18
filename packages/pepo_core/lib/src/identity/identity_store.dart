import 'dart:convert';
import 'dart:io';

import 'certificate_factory.dart';
import 'identity.dart';

/// Persists the device identity. Platform layers provide secure variants
/// (Keystore/Keychain/Credential Manager); [FileIdentityStore] is the
/// portable default used on Linux and in tests.
abstract class IdentityStore {
  Future<Identity?> load();
  Future<void> save(Identity identity);
  Future<void> clear();

  /// Loads the stored identity or generates and stores a new one.
  Future<Identity> loadOrCreate({String commonName = 'PepoConnect'}) async {
    final existing = await load();
    if (existing != null) return existing;
    final fresh = const CertificateFactory().generate(commonName: commonName);
    await save(fresh);
    return fresh;
  }
}

/// Stores the identity as a JSON file. On POSIX systems the file is created
/// with mode 0600.
class FileIdentityStore extends IdentityStore {
  FileIdentityStore(this.path);

  final String path;

  @override
  Future<Identity?> load() async {
    final f = File(path);
    if (!await f.exists()) return null;
    try {
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return Identity.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(Identity identity) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(identity.toJson()), flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', path]);
      } catch (_) {
        // chmod missing: nothing else to do.
      }
    }
  }

  @override
  Future<void> clear() async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}

/// In-memory store for tests.
class MemoryIdentityStore extends IdentityStore {
  Identity? _identity;

  @override
  Future<Identity?> load() async => _identity;

  @override
  Future<void> save(Identity identity) async => _identity = identity;

  @override
  Future<void> clear() async => _identity = null;
}
