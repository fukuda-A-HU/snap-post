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

  /// Puts [paths] on the clipboard as CF_HDROP with Preferred DropEffect copy.
  /// A single image can also include the bitmap ([png] and [dib]).
  Future<void> copyFilesToClipboard(
    List<String> paths, {
    Uint8List? png,
    Uint8List? dib,
  });

  /// Opens [folder] in Explorer. No-op off Windows.
  Future<void> openFolder(String folder);

  /// Asks to be told when another launch requests the settings window.
  void listenForActivation(void Function() onShowSettings);
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

  @override
  Future<void> copyFilesToClipboard(
    List<String> paths, {
    Uint8List? png,
    Uint8List? dib,
  }) async {}

  @override
  Future<void> openFolder(String folder) async {}

  @override
  void listenForActivation(void Function() onShowSettings) {}
}
