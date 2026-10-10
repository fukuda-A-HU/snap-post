import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import 'app_settings.dart';
import 'desktop.dart';
import 'images.dart';
import 'intent_url.dart';
import 'reply_target.dart';

const String copiedNotification = '画像をコピーしました。投稿画面で Ctrl+V で貼り付けてください';

String batchProgressNotification(int count) => '$count/4枚 たまりました';

String batchCopiedNotification(int count) =>
    '$count枚をコピーしました。投稿画面で Ctrl+V で貼り付けてください（貼れない場合は開いたフォルダからドラッグ）';

const String windowMissingNotification = '対象のウィンドウが見つかりません';

const String captureFailedNotification = 'スクリーンショットに失敗しました';

class SnapService {
  SnapService(this.desktop);

  final DesktopBridge desktop;

  /// Saves one screenshot into [directory]. Returns the file path, or null.
  Future<String?> captureToDirectory({
    required AppSettings settings,
    required String directory,
    required Future<void> Function(String message) notify,
    DateTime? now,
  }) async {
    final captured = await _capture(settings, notify);
    if (captured == null) return null;
    try {
      final file = _allocateFile(directory, now ?? DateTime.now());
      await file.parent.create(recursive: true);
      await file.writeAsBytes(captured.png, flush: true);
      return file.path;
    } catch (_) {
      await _notify(notify, captureFailedNotification);
      return null;
    }
  }

  Future<void> captureAndPost({
    required AppSettings settings,
    required Future<void> Function(String message) notify,
    DateTime? now,
  }) async {
    final captured = await _capture(settings, notify);
    if (captured == null) return;
    var saved = false;
    try {
      final folder = settings.saveFolder.trim().isEmpty
          ? picturesDirectory(Platform.environment)
          : settings.saveFolder.trim();
      final file = _allocateFile(folder, now ?? DateTime.now());
      await file.parent.create(recursive: true);
      await file.writeAsBytes(captured.png, flush: true);
      saved = true;
      await desktop.copyImageToClipboard(png: captured.png, dib: captured.dib);
      final opened = await _openIntent(settings);
      if (!opened) {
        await _notify(notify, '画像をコピーしました。ブラウザを開けませんでした');
        return;
      }
      await _notify(notify, copiedNotification);
    } catch (_) {
      await _notify(
        notify,
        saved ? '画像は保存しましたが、その後の処理に失敗しました' : captureFailedNotification,
      );
    }
  }

  /// Returns true when the files were placed on the clipboard.
  Future<bool> publishBatch({
    required AppSettings settings,
    required List<String> paths,
    required String folder,
    required Future<void> Function(String message) notify,
  }) async {
    if (paths.isEmpty) {
      await _notify(notify, '投稿待ちの画像がありません');
      return false;
    }
    try {
      await desktop.copyFilesToClipboard(paths);
      await desktop.openFolder(folder);
      final opened = await _openIntent(settings);
      final message = batchCopiedNotification(paths.length);
      if (!opened) {
        await _notify(notify, '$message ブラウザを開けませんでした');
        return true;
      }
      await _notify(notify, message);
      return true;
    } catch (_) {
      await _notify(notify, 'まとめて投稿に失敗しました');
      return false;
    }
  }

  Future<bool> _openIntent(AppSettings settings) {
    final url = buildIntentUrl(
      hashtags: settings.hashtags,
      fixedText: settings.fixedText,
      inReplyTo: activeReplyStatusId(
        continueThread: settings.continueThread,
        replyTweet: settings.replyTweet,
      ),
    );
    return launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  Future<_SavedCapture?> _capture(
    AppSettings settings,
    Future<void> Function(String message) notify,
  ) async {
    final CaptureOutcome outcome;
    try {
      outcome = await desktop.captureMatching(settings.target);
    } catch (_) {
      await _notify(notify, captureFailedNotification);
      return null;
    }
    if (!outcome.found || outcome.image == null) {
      await _notify(
        notify,
        outcome.found ? captureFailedNotification : windowMissingNotification,
      );
      return null;
    }
    final opaque = ensureOpaque(outcome.image!);
    return _SavedCapture(
      png: encodePngFromBgra(opaque),
      dib: buildDeviceIndependentBitmap(opaque),
    );
  }
}

class _SavedCapture {
  const _SavedCapture({required this.png, required this.dib});

  final Uint8List png;
  final Uint8List dib;
}

Future<void> _notify(
  Future<void> Function(String message) notify,
  String message,
) async {
  try {
    await notify(message);
  } catch (_) {}
}

File _allocateFile(String directory, DateTime time) {
  final name = screenshotFileName(time);
  final first = File(path.join(directory, name));
  if (!first.existsSync()) return first;
  final stem = path.basenameWithoutExtension(name);
  for (var index = 2; index < 1000; index++) {
    final candidate = File(path.join(directory, '${stem}_$index.png'));
    if (!candidate.existsSync()) return candidate;
  }
  return File(
    path.join(directory, '${stem}_${time.microsecondsSinceEpoch}.png'),
  );
}
