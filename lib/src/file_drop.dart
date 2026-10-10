import 'dart:typed_data';

/// DROPEFFECT_COPY. Chrome and Edge paste CF_HDROP files when this is set.
const int dropEffectCopy = 1;

/// CF_HDROP payload: DROPFILES header plus a double-null-terminated UTF-16 list.
Uint8List buildFileDropList(List<String> paths) {
  final files = BytesBuilder(copy: false);
  for (final path in paths) {
    for (final unit in path.codeUnits) {
      files.addByte(unit & 0xff);
      files.addByte((unit >> 8) & 0xff);
    }
    files.addByte(0);
    files.addByte(0);
  }
  files.addByte(0);
  files.addByte(0);
  final body = files.toBytes();

  const headerSize = 20;
  final bytes = Uint8List(headerSize + body.length);
  final header = ByteData.sublistView(bytes);
  header.setUint32(0, headerSize, Endian.little);
  header.setUint32(16, 1, Endian.little);
  bytes.setRange(headerSize, bytes.length, body);
  return bytes;
}

/// DWORD Preferred DropEffect value for a copy.
Uint8List buildCopyDropEffect() {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setUint32(0, dropEffectCopy, Endian.little);
  return bytes;
}
