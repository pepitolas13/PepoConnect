/// Control message type identifiers (`t` field of the JSON header).
class MsgType {
  const MsgType._();

  // Handshake / session
  static const hello = 'hello';
  static const authProof = 'auth.proof';
  static const authOk = 'auth.ok';
  static const authFail = 'auth.fail';
  static const authUnknown = 'auth.unknown';
  static const pairRequest = 'pair.request';
  static const pairAccept = 'pair.accept';
  static const pairReject = 'pair.reject';
  static const chanOk = 'chan.ok';
  static const chanOpen = 'chan.open';
  static const error = 'error';

  // Device
  static const deviceInfo = 'device.info';
  static const deviceUnpair = 'device.unpair';

  // Media / gallery
  static const mediaIndex = 'media.index';
  static const mediaIndexResult = 'media.index.result';
  static const mediaThumb = 'media.thumb';
  static const mediaThumbBatch = 'media.thumb.batch';
  static const mediaPreview = 'media.preview';
  static const mediaPreviewResult = 'media.preview.result';
  static const mediaNew = 'media.new';
  static const mediaRemoved = 'media.removed';
  static const mediaChanged = 'media.changed';
  static const mediaDelete = 'media.delete';
  static const mediaDeleteResult = 'media.delete.result';

  // Transfers
  static const fileRequest = 'file.request';
  static const fileOffer = 'file.offer';
  static const fileAccept = 'file.accept';
  static const fileReject = 'file.reject';
  static const fileDone = 'file.done';
  static const fileAck = 'file.ack';
  static const transferCancel = 'transfer.cancel';
  static const transferList = 'transfer.list';
  static const transferListResult = 'transfer.list.result';

  // Extras
  static const clipboardSet = 'clipboard.set';
}

/// Channel purposes declared in `hello.chan`.
class ChannelKind {
  const ChannelKind._();

  static const control = 'control';
  static const media = 'media';
  static const bulk = 'bulk';

  static bool isValid(String s) => s == control || s == media || s == bulk;
}

/// Error codes carried by `error` and `*.fail` messages.
class ErrorCode {
  const ErrorCode._();

  static const badRequest = 'bad_request';
  static const unauthorized = 'unauthorized';
  static const notFound = 'not_found';
  static const rejected = 'rejected';
  static const timeout = 'timeout';
  static const busy = 'busy';
  static const io = 'io';
  static const internal = 'internal';
  static const unsupported = 'unsupported';
}
