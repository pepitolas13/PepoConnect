import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pure Dart image helpers (used where no native decoder is available:
/// Linux, desktop tests). Heavy work runs in a short-lived isolate.
class ImageOps {
  const ImageOps._();

  /// Width and height without a full decode when the format allows it.
  static ({int width, int height})? dimensions(Uint8List bytes) {
    final decoder = img.findDecoderForData(bytes);
    if (decoder == null) return null;
    final info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return (width: info.width, height: info.height);
  }

  /// Decodes, applies EXIF orientation, fits the long edge into [maxPx] and
  /// re-encodes as JPEG. Returns null when the bytes are not an image.
  static Future<Uint8List?> resizeToJpeg(Uint8List bytes, int maxPx, {int quality = 80}) =>
      Isolate.run(() => resizeToJpegSync(bytes, maxPx, quality: quality));

  static Uint8List? resizeToJpegSync(Uint8List bytes, int maxPx, {int quality = 80}) {
    var image = img.decodeImage(bytes);
    if (image == null) return null;
    image = img.bakeOrientation(image);
    final long = image.width > image.height ? image.width : image.height;
    if (long > maxPx) {
      final scale = maxPx / long;
      image = img.copyResize(
        image,
        width: (image.width * scale).round().clamp(1, maxPx),
        height: (image.height * scale).round().clamp(1, maxPx),
        interpolation: img.Interpolation.average,
      );
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// A solid color JPEG (tests and placeholders).
  static Uint8List solidJpeg(int width, int height, {int r = 120, int g = 160, int b = 200}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(r, g, b));
    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  }

  /// Average color of a small decode, as `#rrggbb` (placeholder before the
  /// thumbnail arrives). Null if undecodable.
  static String? averageColorHex(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final small = img.copyResize(image, width: 8, height: 8);
    var r = 0, g = 0, b = 0, n = 0;
    for (final p in small) {
      r += p.r.toInt();
      g += p.g.toInt();
      b += p.b.toInt();
      n++;
    }
    if (n == 0) return null;
    String h(int v) => (v ~/ n).toRadixString(16).padLeft(2, '0');
    return '#${h(r)}${h(g)}${h(b)}';
  }
}
