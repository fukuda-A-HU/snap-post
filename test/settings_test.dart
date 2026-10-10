import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:snap_post/src/app_settings.dart';
import 'package:snap_post/src/hashtags.dart';
import 'package:snap_post/src/reply_target.dart';
import 'package:snap_post/src/images.dart';
import 'package:snap_post/src/intent_url.dart';
import 'package:snap_post/src/settings_store.dart';

void main() {
  test('defaults serialize and keep the preset hashtags', () {
    final settings = AppSettings.defaults();
    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.targetProcessExe, isEmpty);
    expect(restored.targetTitleSubstring, isEmpty);
    expect(restored.hashtags, defaultHashtags);
    expect(restored.fixedText, isEmpty);
    expect(restored.saveFolder, isEmpty);
    expect(restored.launchAtStartup, isFalse);
    expect(restored.replyTweet, isEmpty);
    expect(restored.toJson().containsKey('continueThread'), isFalse);
    expect(
      buildIntentUrl(
        hashtags: restored.hashtags,
        fixedText: restored.fixedText,
      ),
      'https://x.com/intent/post?text=%23VR%E6%B4%BB%E5%8B%95%E5%A0%B1%E5%91%8A%E5%A4%A7%E4%BC%9A2026%20%23NUMA',
    );
  });

  test('round-trips a configured window and Japanese text', () {
    const original = AppSettings(
      targetProcessExe: 'VRChat.exe',
      targetTitleSubstring: 'VRChat',
      hashtags: <String>['#VR活動報告大会2026', '#NUMA'],
      fixedText: 'こんにちは',
      saveFolder: r'C:\Users\me\Pictures\SnapPost',
      launchAtStartup: true,
      replyTweet: 'https://x.com/name/status/99?s=20',
    );

    final restored = AppSettings.fromJson(original.toJson());
    expect(restored.targetProcessExe, 'VRChat.exe');
    expect(restored.targetTitleSubstring, 'VRChat');
    expect(restored.hashtags, original.hashtags);
    expect(restored.fixedText, 'こんにちは');
    expect(restored.saveFolder, original.saveFolder);
    expect(restored.launchAtStartup, isTrue);
    expect(restored.replyTweet, original.replyTweet);
    expect(restored.toJson().containsKey('continueThread'), isFalse);
  });

  test(
    'missing hashtags fall back to the preset, an empty list stays empty',
    () {
      final missing = AppSettings.fromJson(<String, dynamic>{
        'targetProcessExe': 'game.exe',
      });
      expect(missing.hashtags, defaultHashtags);

      final legacy = AppSettings.fromJson(<String, dynamic>{
        'replyTweet': 'https://x.com/name/status/9',
        'continueThread': false,
      });
      expect(legacy.replyTweet, 'https://x.com/name/status/9');
      expect(activeReplyStatusId(legacy.replyTweet), '9');
      expect(legacy.toJson().containsKey('continueThread'), isFalse);

      final cleared = AppSettings.fromJson(<String, dynamic>{
        'hashtags': <String>[],
      });
      expect(cleared.hashtags, isEmpty);

      final raw = AppSettings.fromJson(<String, dynamic>{
        'hashtags': 'numa, #NUMA VR活動報告大会2026',
      });
      expect(raw.hashtags, <String>['#numa', '#VR活動報告大会2026']);
    },
  );

  test('settings file round-trip and a missing file use defaults', () async {
    final directory = await Directory.systemTemp.createTemp('snappost');
    addTearDown(() => directory.delete(recursive: true));
    final store = SettingsStore(File('${directory.path}/settings.json'));

    expect((await store.load()).hashtags, defaultHashtags);

    await store.save(
      AppSettings.defaults().copyWith(
        targetProcessExe: 'VRChat.exe',
        fixedText: '報告',
        launchAtStartup: true,
      ),
    );
    final loaded = await store.load();
    expect(loaded.targetProcessExe, 'VRChat.exe');
    expect(loaded.fixedText, '報告');
    expect(loaded.launchAtStartup, isTrue);
    expect(loaded.hashtags, defaultHashtags);

    await store.file.writeAsString('{');
    expect((await store.load()).hashtags, defaultHashtags);
  });

  test('settings live under APPDATA and pictures under USERPROFILE', () {
    expect(
      settingsJsonPath(<String, String>{'APPDATA': 'appdata'}),
      path.join('appdata', 'SnapPost', 'settings.json'),
    );
    expect(
      picturesDirectory(<String, String>{'USERPROFILE': 'home'}),
      path.join('home', 'Pictures', 'SnapPost'),
    );
  });
}
