import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import 'app_settings.dart';
import 'desktop.dart';
import 'images.dart';
import 'intent_url.dart';
import 'reply_target.dart';

const String copiedNotification = '画像をコピーしました。投稿画面で Ctrl+V で貼り付けてください';

const String windowMissingNotification = '対象のウィンドウが見つかりません';

const String captureFailedNotification = 'スクリーンショットに失敗しました';

class SnapService {
  SnapService(this.desktop);

  final DesktopBridge desktop;

  Future<void> captureAndPost({
    required AppSettings settings,
    required Future<void> Function(String message) notify,
    DateTime? now,
  }) async {
    final CaptureOutcome outcome;
    try {
      outcome = await desktop.captureMatching(settings.target);
    } catch (_) {
      await _notify(notify, captureFailedNotification);
      return;
    }
    if (!outcome.found || outcome.image == null) {
      await _notify(
        notify,
        outcome.found ? captureFailedNotification : windowMissingNotification,
      );
      return;
    }

    var saved = false;
    try {
      final opaque = ensureOpaque(outcome.image!);
      final png = encodePngFromBgra(opaque);
      final folder = settings.saveFolder.trim().isEmpty
          ? picturesDirectory(Platform.environment)
          : settings.saveFolder.trim();
      final file = _allocateFile(folder, now ?? DateTime.now());
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png, flush: true);
      saved = true;
      await desktop.copyImageToClipboard(
        png: png,
        dib: buildDeviceIndependentBitmap(opaque),
      );
      final url = buildIntentUrl(
        hashtags: settings.hashtags,
        fixedText: settings.fixedText,
        inReplyTo: activeReplyStatusId(
          continueThread: settings.continueThread,
          replyTweet: settings.replyTweet,
        ),
      );
      final opened = await launchUrlString(
        url,
        mode: LaunchMode.externalApplication,
      );
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
