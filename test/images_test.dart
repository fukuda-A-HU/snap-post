import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_post/src/images.dart';

void main() {
  test('screenshot names use local yyyyMMdd_HHmmss', () {
    expect(
      screenshotFileName(DateTime(2026, 1, 2, 3, 4, 5)),
      '20260102_030405.png',
    );
  });

  test('crop drops the shadow margin', () {
    final source = CapturedImage(
      width: 4,
      height: 2,
      bgra: Uint8List.fromList(<int>[
        1, 1, 1, 255, 2, 2, 2, 255, 3, 3, 3, 255, 4, 4, 4, 255, //
        5, 5, 5, 255, 6, 6, 6, 255, 7, 7, 7, 255, 8, 8, 8, 255,
      ]),
    );
    final cropped = cropImage(source, 1, 0, 2, 2);
    expect(cropped.width, 2);
    expect(cropped.height, 2);
    expect(cropped.bgra, <int>[
      2, 2, 2, 255, 3, 3, 3, 255, //
      6, 6, 6, 255, 7, 7, 7, 255,
    ]);
  });

  test('fully transparent alpha is made opaque', () {
    final source = CapturedImage(
      width: 1,
      height: 1,
      bgra: Uint8List.fromList(<int>[9, 8, 7, 0]),
    );
    expect(ensureOpaque(source).bgra, <int>[9, 8, 7, 255]);
    final already = CapturedImage(
      width: 1,
      height: 1,
      bgra: Uint8List.fromList(<int>[1, 2, 3, 10]),
    );
    expect(identical(ensureOpaque(already), already), isTrue);
  });

  test('CF_DIB is a bottom-up 32-bit BITMAPINFOHEADER', () {
    final image = CapturedImage(
      width: 1,
      height: 2,
      bgra: Uint8List.fromList(<int>[
        1, 2, 3, 4, // top
        5, 6, 7, 8, // bottom
      ]),
    );
    final dib = buildDeviceIndependentBitmap(image);
    final header = ByteData.sublistView(dib);
    expect(header.getUint32(0, Endian.little), 40);
    expect(header.getInt32(4, Endian.little), 1);
    expect(header.getInt32(8, Endian.little), 2);
    expect(header.getUint16(14, Endian.little), 32);
    expect(dib.sublist(40, 44), <int>[5, 6, 7, 8]);
    expect(dib.sublist(44, 48), <int>[1, 2, 3, 4]);
  });
}
