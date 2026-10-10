import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import 'app_settings.dart';
import 'desktop.dart';
import 'images.dart';
import 'intent_url.dart';
import 'reply_target.dart';

String postCopiedNotification(int count) =>
    '$count枚をコピーしました。投稿画面で Ctrl+V で貼り付けてください（貼れない場合は開いたフォルダからドラッグ）';

const String captureFailedNotification = 'スクリーンショットに失敗しました';

enum CaptureStatus { saved, missingTarget, notFound, failed }

class CaptureAttempt {
  const CaptureAttempt(this.status, [this.path]);

  final CaptureStatus status;
  final String? path;
}

class SnapService {
  SnapService(this.desktop);

  final DesktopBridge desktop;

  Future<CaptureAttempt> captureToDirectory({
    required AppSettings settings,
    required String directory,
    DateTime? now,
  }) async {
    if (!settings.hasTarget) {
      return const CaptureAttempt(CaptureStatus.missingTarget);
    }
    final captured = await _capture(settings);
    if (captured.kind == _CaptureKind.notFound) {
      return const CaptureAttempt(CaptureStatus.notFound);
    }
    if (captured.kind != _CaptureKind.image || captured.saved == null) {
      return const CaptureAttempt(CaptureStatus.failed);
    }
    try {
      final file = _allocateFile(directory, now ?? DateTime.now());
      await file.parent.create(recursive: true);
      await file.writeAsBytes(captured.saved!.png, flush: true);
      return CaptureAttempt(CaptureStatus.saved, file.path);
    } catch (_) {
      return const CaptureAttempt(CaptureStatus.failed);
    }
  }

  /// Copies [sourcePaths] into a new folder, puts them on the clipboard, opens
  /// that folder, and opens the intent URL. Returns true when the clipboard
  /// and the browser both succeeded.
  Future<bool> openPost({
    required AppSettings settings,
    required List<String> sourcePaths,
    required String saveRoot,
    required Future<void> Function(String message) notify,
    DateTime? now,
  }) async {
    if (sourcePaths.isEmpty) return false;
    try {
      final folder = path.join(
        saveRoot,
        batchFolderName(now ?? DateTime.now()),
      );
      final staged = await _stageFiles(folder, sourcePaths);
      Uint8List? png;
      Uint8List? dib;
      if (staged.length == 1) {
        png = await File(staged.single).readAsBytes();
        dib = dibFromPngBytes(png);
      }
      await desktop.copyFilesToClipboard(staged, png: png, dib: dib);
      await desktop.openFolder(folder);
      final opened = await _openIntent(settings);
      final message = postCopiedNotification(staged.length);
      if (!opened) {
        await _notify(notify, '$message ブラウザを開けませんでした');
        return false;
      }
      await _notify(notify, message);
      return true;
    } catch (_) {
      await _notify(notify, '投稿画面を開けませんでした');
      return false;
    }
  }

  Future<List<String>> _stageFiles(String folder, List<String> sources) async {
    await Directory(folder).create(recursive: true);
    final staged = <String>[];
    for (final source in sources) {
      final name = path.basename(source);
      var dest = path.join(folder, name);
      var suffix = 2;
      while (File(dest).existsSync()) {
        final stem = path.basenameWithoutExtension(name);
        dest = path.join(folder, '${stem}_$suffix.png');
        suffix++;
      }
      await File(source).copy(dest);
      staged.add(dest);
    }
    return staged;
  }

  Future<bool> _openIntent(AppSettings settings) {
    final url = buildIntentUrl(
      hashtags: settings.hashtags,
      fixedText: settings.fixedText,
      inReplyTo: activeReplyStatusId(settings.replyTweet),
    );
    return launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  Future<_CaptureResult> _capture(AppSettings settings) async {
    final CaptureOutcome outcome;
    try {
      outcome = await desktop.captureMatching(settings.target);
    } catch (_) {
      return const _CaptureResult.failed();
    }
    if (!outcome.found) return const _CaptureResult.notFound();
    if (outcome.image == null) return const _CaptureResult.failed();
    final opaque = ensureOpaque(outcome.image!);
    return _CaptureResult.image(_SavedCapture(png: encodePngFromBgra(opaque)));
  }
}

enum _CaptureKind { image, notFound, failed }

class _CaptureResult {
  const _CaptureResult.image(this.saved) : kind = _CaptureKind.image;
  const _CaptureResult.notFound() : kind = _CaptureKind.notFound, saved = null;
  const _CaptureResult.failed() : kind = _CaptureKind.failed, saved = null;

  final _CaptureKind kind;
  final _SavedCapture? saved;
}

class _SavedCapture {
  const _SavedCapture({required this.png});

  final Uint8List png;
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
