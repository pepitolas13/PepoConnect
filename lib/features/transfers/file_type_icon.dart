import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../shared/theme/tokens.dart';

/// Broad family of a file, from its MIME type or extension.
enum FileFamily { image, video, audio, archive, document, other }

FileFamily fileFamilyOf(String name, [String? mime]) {
  final m = (mime ?? '').toLowerCase();
  if (m.startsWith('image/')) return FileFamily.image;
  if (m.startsWith('video/')) return FileFamily.video;
  if (m.startsWith('audio/')) return FileFamily.audio;
  final ext = p.extension(name).toLowerCase();
  return switch (ext) {
    '.jpg' ||
    '.jpeg' ||
    '.png' ||
    '.gif' ||
    '.webp' ||
    '.heic' ||
    '.heif' ||
    '.bmp' => FileFamily.image,
    '.mp4' || '.mov' || '.mkv' || '.avi' || '.webm' || '.m4v' || '.3gp' => FileFamily.video,
    '.mp3' || '.m4a' || '.aac' || '.flac' || '.wav' || '.ogg' || '.opus' => FileFamily.audio,
    '.zip' || '.rar' || '.7z' || '.tar' || '.gz' => FileFamily.archive,
    '.pdf' ||
    '.doc' ||
    '.docx' ||
    '.xls' ||
    '.xlsx' ||
    '.ppt' ||
    '.pptx' ||
    '.txt' ||
    '.odt' ||
    '.ods' ||
    '.csv' ||
    '.rtf' => FileFamily.document,
    _ => FileFamily.other,
  };
}

/// Upper-case extension without the dot ("DOCX"), at most four characters.
String fileExtensionLabel(String name) {
  final ext = p.extension(name);
  if (ext.length < 2) return '';
  final label = ext.substring(1).toUpperCase();
  return label.length > 4 ? label.substring(0, 4) : label;
}

/// Thin Fluent glyph for a file, with the extension printed inside the
/// document silhouette for anything that is not a photo, video or song.
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({super.key, required this.name, this.mime, this.size = 32, this.color});

  final String name;
  final String? mime;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final tint = color ?? colors.textSecondary;
    final family = fileFamilyOf(name, mime);
    final icon = switch (family) {
      FileFamily.image => FluentIcons.image_24_regular,
      FileFamily.video => FluentIcons.video_clip_24_regular,
      FileFamily.audio => FluentIcons.music_note_2_24_regular,
      FileFamily.archive => FluentIcons.folder_zip_24_regular,
      FileFamily.document || FileFamily.other => FluentIcons.document_24_regular,
    };
    final label = switch (family) {
      FileFamily.document || FileFamily.other || FileFamily.archive => fileExtensionLabel(name),
      _ => '',
    };
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: size * 0.75, color: tint),
          if (label.isNotEmpty)
            Positioned(
              bottom: size * 0.16,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: label.length > 3 ? size * 0.19 : size * 0.22,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: tint,
                  fontFamily: context.text.caption.fontFamily,
                  fontFamilyFallback: context.text.caption.fontFamilyFallback,
                  letterSpacing: -0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
