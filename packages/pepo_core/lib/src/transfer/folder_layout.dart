import 'package:path/path.dart' as p;

import '../protocol/models.dart';
import 'name_sanitizer.dart';

/// Where received files go.
///
/// Separate mode:  `<root>/<Device>/{Fotos,Vídeos,Archivos}`
/// Unified mode:   `<root>/{Fotos,Vídeos,Archivos}`
class FolderLayout {
  const FolderLayout({
    required this.root,
    this.separateByDevice = true,
    this.photosFolder = 'Fotos',
    this.videosFolder = 'Vídeos',
    this.filesFolder = 'Archivos',
    this.guestsFolder = 'Invitados',
  });

  final String root;
  final bool separateByDevice;
  final String photosFolder;
  final String videosFolder;
  final String filesFolder;
  final String guestsFolder;

  FolderLayout copyWith({String? root, bool? separateByDevice}) => FolderLayout(
    root: root ?? this.root,
    separateByDevice: separateByDevice ?? this.separateByDevice,
    photosFolder: photosFolder,
    videosFolder: videosFolder,
    filesFolder: filesFolder,
    guestsFolder: guestsFolder,
  );

  /// Directory for a file of [kind] coming from [deviceFolder].
  String directoryFor({required String? deviceFolder, MediaKind? kind}) {
    final sub = switch (kind) {
      MediaKind.image => photosFolder,
      MediaKind.video => videosFolder,
      null => filesFolder,
    };
    if (separateByDevice && deviceFolder != null) {
      return p.join(root, deviceFolder, sub);
    }
    return p.join(root, sub);
  }

  /// Directory for files received through the browser share feature.
  String guestsDirectory() => p.join(root, guestsFolder);

  /// Folder name for a device, unique among [existing].
  static String folderNameFor(String deviceName, Iterable<String> existing) {
    final base = NameSanitizer.sanitize(deviceName, fallback: 'Dispositivo');
    if (!existing.contains(base)) return base;
    var i = 2;
    while (existing.contains('$base-$i')) {
      i++;
    }
    return '$base-$i';
  }
}
