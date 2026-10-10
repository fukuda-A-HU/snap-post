import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class CapturedImage {
  const CapturedImage({
    required this.width,
    required this.height,
    required this.bgra,
  });

  final int width;
  final int height;

  /// Top-down BGRA, 4 bytes per pixel.
  final Uint8List bgra;
}

/// `yyyyMMdd_HHmmss.png` in local time.
String screenshotFileName(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}${two(time.month)}${two(time.day)}_'
      '${two(time.hour)}${two(time.minute)}${two(time.second)}.png';
}

/// Subfolder for one multi-image post: `yyyyMMdd_HHmmss`.
String batchFolderName(DateTime time) {
  final fileName = screenshotFileName(time);
  return fileName.substring(0, fileName.length - 4);
}

/// `%USERPROFILE%\Pictures\SnapPost`, or the home directory when that variable
/// is absent (tests and non-Windows runs).
String picturesDirectory(Map<String, String> env) {
  final profile = env['USERPROFILE'];
  if (profile != null && profile.isNotEmpty) {
    return path.join(profile, 'Pictures', 'SnapPost');
  }
  final home = env['HOME'];
  if (home != null && home.isNotEmpty) {
    return path.join(home, 'Pictures', 'SnapPost');
  }
  return path.join('.', 'Pictures', 'SnapPost');
}

/// `%APPDATA%\SnapPost\settings.json`.
String settingsJsonPath(Map<String, String> env, {String? fallbackDirectory}) {
  final appData = env['APPDATA'];
  if (appData != null && appData.isNotEmpty) {
    return path.join(appData, 'SnapPost', 'settings.json');
  }
  return path.join(fallbackDirectory ?? '.', 'settings.json');
}

/// Crops a top-down BGRA image. Out-of-range edges are clamped. An empty crop
/// returns [source].
CapturedImage cropImage(
  CapturedImage source,
  int left,
  int top,
  int width,
  int height,
) {
  var x = left;
  var y = top;
  var cropWidth = width;
  var cropHeight = height;
  if (x < 0) {
    cropWidth += x;
    x = 0;
  }
  if (y < 0) {
    cropHeight += y;
    y = 0;
  }
  if (x >= source.width || y >= source.height) return source;
  if (x + cropWidth > source.width) cropWidth = source.width - x;
  if (y + cropHeight > source.height) cropHeight = source.height - y;
  if (cropWidth <= 0 || cropHeight <= 0) return source;
  if (x == 0 &&
      y == 0 &&
      cropWidth == source.width &&
      cropHeight == source.height) {
    return source;
  }

  final out = Uint8List(cropWidth * cropHeight * 4);
  final sourceStride = source.width * 4;
  final outStride = cropWidth * 4;
  for (var row = 0; row < cropHeight; row++) {
    final srcStart = (y + row) * sourceStride + x * 4;
    out.setRange(
      row * outStride,
      row * outStride + outStride,
      source.bgra,
      srcStart,
    );
  }
  return CapturedImage(width: cropWidth, height: cropHeight, bgra: out);
}

/// 32-bit BI_RGB captures often store 0 in the alpha byte. A PNG with alpha 0
/// would paste as a fully transparent image, so fill alpha when every pixel
/// is transparent.
CapturedImage ensureOpaque(CapturedImage source) {
  for (var i = 3; i < source.bgra.length; i += 4) {
    if (source.bgra[i] != 0) return source;
  }
  final pixels = Uint8List.fromList(source.bgra);
  for (var i = 3; i < pixels.length; i += 4) {
    pixels[i] = 0xFF;
  }
  return CapturedImage(
    width: source.width,
    height: source.height,
    bgra: pixels,
  );
}

Uint8List encodePngFromBgra(CapturedImage image) {
  final pixels = Uint8List.fromList(image.bgra);
  final decoded = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: pixels.buffer,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );
  return img.encodePng(decoded);
}

/// CF_DIB payload: BITMAPINFOHEADER (40 bytes) plus bottom-up 32-bit BGRA.
Uint8List buildDeviceIndependentBitmap(CapturedImage image) {
  const headerSize = 40;
  final stride = image.width * 4;
  final pixelBytes = stride * image.height;
  final bytes = Uint8List(headerSize + pixelBytes);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, headerSize, Endian.little);
  data.setInt32(4, image.width, Endian.little);
  data.setInt32(8, image.height, Endian.little);
  data.setUint16(12, 1, Endian.little);
  data.setUint16(14, 32, Endian.little);
  data.setUint32(16, 0, Endian.little); // BI_RGB
  data.setUint32(20, pixelBytes, Endian.little);
  for (var row = 0; row < image.height; row++) {
    final sourceRow = (image.height - 1 - row) * stride;
    final dest = headerSize + row * stride;
    bytes.setRange(dest, dest + stride, image.bgra, sourceRow);
  }
  return bytes;
}
