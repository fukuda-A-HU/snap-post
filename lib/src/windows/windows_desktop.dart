// Win32 capture and clipboard. This library is loaded only on Windows.
// The public win32 barrel opens unrelated DLLs at import time, so only the
// modules this file calls are imported.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:win32/src/callbacks.dart';
import 'package:win32/src/constants.dart';
import 'package:win32/src/structs.g.dart';
import 'package:win32/src/win32/dwmapi.g.dart';
import 'package:win32/src/win32/gdi32.g.dart';
import 'package:win32/src/win32/kernel32.g.dart';
import 'package:win32/src/win32/user32.g.dart';

import '../desktop.dart';
import '../file_drop.dart';
import '../images.dart';
import '../window_match.dart';

/// PW_RENDERFULLCONTENT. Not exported by win32 5.15.
const int pwRenderFullContent = 2;

const int _gmemMoveable = 0x0002;
const int _processQueryLimitedInformation = 0x1000;
const int _srcCopy = 0x00CC0020;
const int _dibRgbColors = 0;

class WindowsDesktopBridge implements DesktopBridge {
  Timer? _activationTimer;
  int _activationEvent = 0;
  @override
  Future<List<WindowSummary>> listVisibleWindows() async {
    return _listVisibleWindows();
  }

  @override
  Future<CaptureOutcome> captureMatching(WindowTarget target) async {
    final windows = _listVisibleWindows();
    final match = findMatchingWindow(
      windows,
      target,
      foregroundHwnd: GetForegroundWindow(),
    );
    if (match == null) return const CaptureOutcome.notFound();
    final image = _captureWindow(match.hwnd);
    if (image == null) return const CaptureOutcome.failed();
    return CaptureOutcome.success(image);
  }

  @override
  Future<void> copyImageToClipboard({
    required Uint8List png,
    required Uint8List dib,
  }) async {
    final formatName = 'PNG'.toNativeUtf16();
    var pngFormat = 0;
    try {
      pngFormat = RegisterClipboardFormat(formatName);
    } finally {
      malloc.free(formatName);
    }

    if (!await _openClipboard()) {
      throw StateError('OpenClipboard failed');
    }
    try {
      if (EmptyClipboard() == 0) {
        throw StateError('EmptyClipboard failed');
      }
      _setClipboardData(CF_DIB, dib);
      if (pngFormat != 0) {
        _setClipboardData(pngFormat, png);
      }
    } finally {
      CloseClipboard();
    }
  }

  @override
  Future<String?> readClipboardText() async {
    if (!await _openClipboard()) return null;
    try {
      final handle = GetClipboardData(CF_UNICODETEXT);
      if (handle == 0) return null;
      final memory = Pointer<Uint8>.fromAddress(handle);
      final locked = GlobalLock(memory);
      if (locked == nullptr) return null;
      try {
        return locked.cast<Utf16>().toDartString();
      } finally {
        GlobalUnlock(memory);
      }
    } finally {
      CloseClipboard();
    }
  }

  @override
  Future<void> copyFilesToClipboard(List<String> paths) async {
    final absolute = <String>[
      for (final file in paths) File(file).absolute.path,
    ];
    final hdrop = buildFileDropList(absolute);
    final effect = buildCopyDropEffect();
    final formatName = 'Preferred DropEffect'.toNativeUtf16();
    var effectFormat = 0;
    try {
      effectFormat = RegisterClipboardFormat(formatName);
    } finally {
      malloc.free(formatName);
    }
    if (!await _openClipboard()) {
      throw StateError('OpenClipboard failed');
    }
    try {
      if (EmptyClipboard() == 0) {
        throw StateError('EmptyClipboard failed');
      }
      _setClipboardData(CF_HDROP, hdrop);
      if (effectFormat != 0) {
        _setClipboardData(effectFormat, effect);
      }
    } finally {
      CloseClipboard();
    }
  }

  @override
  Future<void> openFolder(String folder) async {
    try {
      await Process.run('explorer', <String>[folder]);
    } catch (_) {}
  }

  @override
  void listenForActivation(void Function() onShowSettings) {
    if (_activationEvent != 0) return;
    final name = 'Local\\SnapPostShow'.toNativeUtf16();
    try {
      _activationEvent = CreateEvent(
        nullptr.cast<SECURITY_ATTRIBUTES>(),
        FALSE,
        FALSE,
        name,
      );
    } finally {
      malloc.free(name);
    }
    if (_activationEvent == 0) return;
    _activationTimer?.cancel();
    _activationTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (WaitForSingleObject(_activationEvent, 0) == 0) {
        onShowSettings();
      }
    });
  }
}

Future<bool> _openClipboard() async {
  for (var attempt = 0; attempt < 8; attempt++) {
    if (OpenClipboard(NULL) != 0) return true;
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
  return false;
}

void _setClipboardData(int format, Uint8List bytes) {
  final memory = GlobalAlloc(_gmemMoveable, bytes.length);
  if (memory == nullptr) {
    throw StateError('GlobalAlloc failed');
  }
  final locked = GlobalLock(memory);
  if (locked == nullptr) {
    GlobalFree(memory);
    throw StateError('GlobalLock failed');
  }
  try {
    locked.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
  } finally {
    GlobalUnlock(memory);
  }
  if (SetClipboardData(format, memory.address) == 0) {
    GlobalFree(memory);
    throw StateError('SetClipboardData failed');
  }
}

List<WindowSummary> _listVisibleWindows() {
  final found = <WindowSummary>[];
  int enumWindow(int hwnd, int lParam) {
    try {
      if (hwnd == 0 || IsWindowVisible(hwnd) == 0) return 1;
      if (_isCloaked(hwnd)) return 1;
      final exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
      if ((exStyle & WS_EX_TOOLWINDOW) != 0) return 1;
      final title = _windowText(hwnd).trim();
      if (title.isEmpty) return 1;
      final exe = _processExe(hwnd);
      if (exe.isEmpty) return 1;
      found.add(WindowSummary(hwnd: hwnd, title: title, processExe: exe));
    } catch (_) {
      return 1;
    }
    return 1;
  }

  final callback = NativeCallable<WNDENUMPROC>.isolateLocal(
    enumWindow,
    exceptionalReturn: 0,
  );
  try {
    EnumWindows(callback.nativeFunction, 0);
  } finally {
    callback.close();
  }
  found.sort((a, b) {
    final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (byTitle != 0) return byTitle;
    return a.processExe.toLowerCase().compareTo(b.processExe.toLowerCase());
  });
  return found;
}

bool _isCloaked(int hwnd) {
  final cloaked = calloc<Uint32>();
  try {
    final hr = DwmGetWindowAttribute(
      hwnd,
      DWMWA_CLOAKED,
      cloaked,
      sizeOf<Uint32>(),
    );
    return hr == S_OK && cloaked.value != 0;
  } finally {
    calloc.free(cloaked);
  }
}

String _windowText(int hwnd) {
  final length = GetWindowTextLength(hwnd);
  if (length <= 0) return '';
  final buffer = calloc<Uint16>(length + 1);
  try {
    GetWindowText(hwnd, buffer.cast<Utf16>(), length + 1);
    return buffer.cast<Utf16>().toDartString();
  } finally {
    calloc.free(buffer);
  }
}

String _processExe(int hwnd) {
  final pidPointer = calloc<Uint32>();
  try {
    GetWindowThreadProcessId(hwnd, pidPointer);
    final pid = pidPointer.value;
    if (pid == 0) return '';
    final process = OpenProcess(_processQueryLimitedInformation, FALSE, pid);
    if (process == 0) return '';
    try {
      const capacity = 32768;
      final size = calloc<Uint32>()..value = capacity;
      final buffer = calloc<Uint16>(capacity);
      try {
        final ok = QueryFullProcessImageName(
          process,
          0,
          buffer.cast<Utf16>(),
          size,
        );
        if (ok == 0) return '';
        return path.basename(buffer.cast<Utf16>().toDartString());
      } finally {
        calloc.free(buffer);
        calloc.free(size);
      }
    } finally {
      CloseHandle(process);
    }
  } finally {
    calloc.free(pidPointer);
  }
}

CapturedImage? _captureWindow(int hwnd) {
  if (IsWindow(hwnd) == 0) return null;
  final window = _readRect(hwnd, extendedFrame: false);
  if (window == null) return null;
  final frame = _readRect(hwnd, extendedFrame: true);

  final printed = _captureDc(
    width: window.width,
    height: window.height,
    draw: (hdc, _) => PrintWindow(hwnd, hdc, pwRenderFullContent),
  );
  if (printed != null) {
    if (frame == null) return printed;
    return cropImage(
      printed,
      frame.left - window.left,
      frame.top - window.top,
      frame.width,
      frame.height,
    );
  }

  final source = frame ?? window;
  return _captureDc(
    width: source.width,
    height: source.height,
    draw: (hdc, screenDc) => BitBlt(
      hdc,
      0,
      0,
      source.width,
      source.height,
      screenDc,
      source.left,
      source.top,
      _srcCopy,
    ),
  );
}

class _WinRect {
  const _WinRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;

  bool get valid =>
      width > 0 && height > 0 && width <= 16384 && height <= 16384;
}

_WinRect? _readRect(int hwnd, {required bool extendedFrame}) {
  final rect = calloc<RECT>();
  try {
    if (extendedFrame) {
      final hr = DwmGetWindowAttribute(
        hwnd,
        DWMWA_EXTENDED_FRAME_BOUNDS,
        rect,
        sizeOf<RECT>(),
      );
      if (hr != S_OK) return null;
    } else if (GetWindowRect(hwnd, rect) == 0) {
      return null;
    }
    final value = _WinRect(
      rect.ref.left,
      rect.ref.top,
      rect.ref.right,
      rect.ref.bottom,
    );
    return value.valid ? value : null;
  } finally {
    calloc.free(rect);
  }
}

typedef _Draw = int Function(int hdc, int screenDc);

CapturedImage? _captureDc({
  required int width,
  required int height,
  required _Draw draw,
}) {
  if (width <= 0 || height <= 0) return null;
  final screenDc = GetDC(NULL);
  if (screenDc == 0) return null;
  final memoryDc = CreateCompatibleDC(screenDc);
  if (memoryDc == 0) {
    ReleaseDC(NULL, screenDc);
    return null;
  }
  final bitmap = CreateCompatibleBitmap(screenDc, width, height);
  if (bitmap == 0) {
    DeleteDC(memoryDc);
    ReleaseDC(NULL, screenDc);
    return null;
  }
  final previous = SelectObject(memoryDc, bitmap);
  var restored = false;
  try {
    if (draw(memoryDc, screenDc) == 0) return null;
    // GetDIBits rejects a bitmap that is still selected into a DC.
    if (previous != 0) {
      SelectObject(memoryDc, previous);
      restored = true;
    }
    return _readBitmap(screenDc, bitmap, width, height);
  } finally {
    if (!restored && previous != 0) SelectObject(memoryDc, previous);
    DeleteObject(bitmap);
    DeleteDC(memoryDc);
    ReleaseDC(NULL, screenDc);
  }
}

CapturedImage? _readBitmap(int hdc, int bitmap, int width, int height) {
  final topDown = _getDiBits(hdc, bitmap, width, height, topDown: true);
  if (topDown != null) return topDown;
  final bottomUp = _getDiBits(hdc, bitmap, width, height, topDown: false);
  if (bottomUp == null) return null;
  return _flipVertical(bottomUp);
}

CapturedImage? _getDiBits(
  int hdc,
  int bitmap,
  int width,
  int height, {
  required bool topDown,
}) {
  final header = calloc<_BitmapHeader>();
  final pixels = calloc<Uint8>(width * height * 4);
  try {
    header.ref
      ..biSize = 40
      ..biWidth = width
      ..biHeight = topDown ? -height : height
      ..biPlanes = 1
      ..biBitCount = 32
      ..biCompression = BI_RGB;
    final lines = GetDIBits(
      hdc,
      bitmap,
      0,
      height,
      pixels,
      header.cast<BITMAPINFO>(),
      _dibRgbColors,
    );
    if (lines == 0) return null;
    return CapturedImage(
      width: width,
      height: height,
      bgra: Uint8List.fromList(pixels.asTypedList(width * height * 4)),
    );
  } finally {
    calloc.free(pixels);
    calloc.free(header);
  }
}

CapturedImage _flipVertical(CapturedImage image) {
  final stride = image.width * 4;
  final pixels = Uint8List(image.bgra.length);
  for (var row = 0; row < image.height; row++) {
    final source = row * stride;
    final dest = (image.height - 1 - row) * stride;
    pixels.setRange(dest, dest + stride, image.bgra, source);
  }
  return CapturedImage(width: image.width, height: image.height, bgra: pixels);
}

final class _BitmapHeader extends Struct {
  @Uint32()
  external int biSize;

  @Int32()
  external int biWidth;

  @Int32()
  external int biHeight;

  @Uint16()
  external int biPlanes;

  @Uint16()
  external int biBitCount;

  @Uint32()
  external int biCompression;

  @Uint32()
  external int biSizeImage;

  @Int32()
  external int biXPelsPerMeter;

  @Int32()
  external int biYPelsPerMeter;

  @Uint32()
  external int biClrUsed;

  @Uint32()
  external int biClrImportant;
}
