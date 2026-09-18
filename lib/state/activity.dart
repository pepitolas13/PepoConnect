import 'package:flutter/foundation.dart';

/// Kinds of entries in the activity panel.
enum ActivityKind {
  newPhoto,
  newVideo,
  received,
  sent,
  failed,
  connected,
  disconnected,
  paired,
  forgotten,
  clipboard,
}

/// One row of the activity panel / history.
@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.at,
    required this.kind,
    required this.deviceId,
    required this.deviceName,
    this.fileName,
    this.mediaId,
    this.transferId,
    this.path,
    this.text,
    this.read = false,
  });

  final String id;
  final DateTime at;
  final ActivityKind kind;
  final String deviceId;
  final String deviceName;
  final String? fileName;
  final String? mediaId;
  final int? transferId;
  final String? path;
  final String? text;
  final bool read;

  ActivityEntry copyWith({bool? read}) => ActivityEntry(
    id: id,
    at: at,
    kind: kind,
    deviceId: deviceId,
    deviceName: deviceName,
    fileName: fileName,
    mediaId: mediaId,
    transferId: transferId,
    path: path,
    text: text,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'kind': kind.name,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'fileName': fileName,
    'mediaId': mediaId,
    'transferId': transferId,
    'path': path,
    'text': text,
    'read': read,
  };

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String).toLocal(),
    kind: ActivityKind.values.byName(j['kind'] as String),
    deviceId: j['deviceId'] as String,
    deviceName: j['deviceName'] as String? ?? '',
    fileName: j['fileName'] as String?,
    mediaId: j['mediaId'] as String?,
    transferId: j['transferId'] as int?,
    path: j['path'] as String?,
    text: j['text'] as String?,
    read: j['read'] as bool? ?? true,
  );
}
