import 'dart:typed_data';

import 'images.dart';
import 'window_match.dart';

class CaptureOutcome {
  const CaptureOutcome.notFound() : image = null, found = false;

  const CaptureOutcome.failed() : image = null, found = true;

  const CaptureOutcome.success(this.image) : found = true;

  final CapturedImage? image;
  final bool found;
}

/// Window listing, capture, and clipboard. The Windows implementation is loaded
/// only on Windows so this library stays runnable under the analyzer on Linux.
abstract class DesktopBridge {
  Future<List<WindowSummary>> listVisibleWindows();

  Future<CaptureOutcome> captureMatching(WindowTarget target);

  Future<void> copyImageToClipboard({
    required Uint8List png,
    required Uint8List dib,
  });

  /// Clipboard text, or null when it is empty or unavailable.
  Future<String?> readClipboardText();
}

class UnsupportedDesktopBridge implements DesktopBridge {
  @override
  Future<List<WindowSummary>> listVisibleWindows() async =>
      const <WindowSummary>[];

  @override
  Future<CaptureOutcome> captureMatching(WindowTarget target) async {
    return const CaptureOutcome.notFound();
  }

  @override
  Future<void> copyImageToClipboard({
    required Uint8List png,
    required Uint8List dib,
  }) async {
    throw UnsupportedError('SnapPost capture is only available on Windows');
  }

  @override
  Future<String?> readClipboardText() async => null;
}
