import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:snap_post/src/app_settings.dart';
import 'package:snap_post/src/hashtags.dart';
import 'package:snap_post/src/images.dart';
import 'package:snap_post/src/intent_url.dart';
import 'package:snap_post/src/settings_store.dart';

void main() {
  test('Ctrl+Shift+S uses the logical key S id', () {
    expect(HotkeyConfig.ctrlShiftS.keyId, LogicalKeyboardKey.keyS.keyId);
    expect(HotkeyConfig.ctrlShiftD.keyId, LogicalKeyboardKey.keyD.keyId);
    expect(keySKeyId, 0x73);
    expect(keyDKeyId, 0x64);
  });

  test('defaults serialize and keep the preset hashtags', () {
    final settings = AppSettings.defaults();
    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.targetProcessExe, isEmpty);
    expect(restored.targetTitleSubstring, isEmpty);
    expect(restored.hotkey.keyId, HotkeyConfig.ctrlShiftS.keyId);
    expect(restored.hotkey.control, isTrue);
    expect(restored.hotkey.shift, isTrue);
    expect(restored.hotkey.alt, isFalse);
    expect(restored.hotkey.meta, isFalse);
    expect(restored.hashtags, defaultHashtags);
    expect(restored.fixedText, isEmpty);
    expect(restored.saveFolder, isEmpty);
    expect(restored.launchAtStartup, isFalse);
    expect(restored.replyTweet, isEmpty);
    expect(restored.continueThread, isFalse);
    expect(restored.batchMode, isTrue);
    expect(restored.finishHotkey.keyId, HotkeyConfig.ctrlShiftD.keyId);
    expect(restored.finishHotkey.control, isTrue);
    expect(restored.finishHotkey.shift, isTrue);
    expect(
      buildIntentUrl(
        hashtags: restored.hashtags,
        fixedText: restored.fixedText,
      ),
      'https://x.com/intent/post?text=%23VR%E6%B4%BB%E5%8B%95%E5%A0%B1%E5%91%8A%E5%A4%A7%E4%BC%9A2026%20%23NUMA',
    );
  });

  test('round-trips a configured window, hotkey, and Japanese text', () {
    const original = AppSettings(
      targetProcessExe: 'VRChat.exe',
      targetTitleSubstring: 'VRChat',
      hotkey: HotkeyConfig(
        keyId: 0x73,
        control: true,
        shift: false,
        alt: true,
        meta: false,
      ),
      hashtags: <String>['#VR活動報告大会2026', '#NUMA'],
      fixedText: 'こんにちは',
      saveFolder: r'C:\Users\me\Pictures\SnapPost',
      launchAtStartup: true,
      replyTweet: 'https://x.com/name/status/99?s=20',
      continueThread: true,
    );

    final restored = AppSettings.fromJson(original.toJson());
    expect(restored.targetProcessExe, 'VRChat.exe');
    expect(restored.targetTitleSubstring, 'VRChat');
    expect(restored.hotkey.alt, isTrue);
    expect(restored.hotkey.shift, isFalse);
    expect(restored.hashtags, original.hashtags);
    expect(restored.fixedText, 'こんにちは');
    expect(restored.saveFolder, original.saveFolder);
    expect(restored.launchAtStartup, isTrue);
    expect(restored.replyTweet, original.replyTweet);
    expect(restored.continueThread, isTrue);
  });

  test(
    'missing hashtags fall back to the preset, an empty list stays empty',
    () {
      final missing = AppSettings.fromJson(<String, dynamic>{
        'targetProcessExe': 'game.exe',
      });
      expect(missing.hashtags, defaultHashtags);
      expect(missing.hotkey.control, isTrue);
      expect(missing.hotkey.shift, isTrue);
      expect(missing.batchMode, isTrue);
      expect(missing.finishHotkey.keyId, keyDKeyId);

      final single = AppSettings.fromJson(<String, dynamic>{
        'batchMode': false,
      });
      expect(single.batchMode, isFalse);

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
