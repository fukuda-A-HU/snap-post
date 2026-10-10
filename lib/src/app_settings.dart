import 'hashtags.dart';
import 'window_match.dart';

/// LogicalKeyboardKey.keyS. Kept here so settings JSON does not depend on
/// Flutter's services library.
const int keySKeyId = 0x73;

/// LogicalKeyboardKey.keyD.
const int keyDKeyId = 0x64;

class HotkeyConfig {
  const HotkeyConfig({
    required this.keyId,
    required this.control,
    required this.shift,
    required this.alt,
    required this.meta,
  });

  static const HotkeyConfig ctrlShiftS = HotkeyConfig(
    keyId: keySKeyId,
    control: true,
    shift: true,
    alt: false,
    meta: false,
  );

  static const HotkeyConfig ctrlShiftD = HotkeyConfig(
    keyId: keyDKeyId,
    control: true,
    shift: true,
    alt: false,
    meta: false,
  );

  final int keyId;
  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;

  Map<String, Object> toJson() => <String, Object>{
    'keyId': keyId,
    'control': control,
    'shift': shift,
    'alt': alt,
    'meta': meta,
  };

  factory HotkeyConfig.fromJson(Map<String, dynamic> json) {
    final keyId = json['keyId'];
    return HotkeyConfig(
      keyId: keyId is int ? keyId : ctrlShiftS.keyId,
      control: json['control'] == true,
      shift: json['shift'] == true,
      alt: json['alt'] == true,
      meta: json['meta'] == true,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.targetProcessExe,
    required this.targetTitleSubstring,
    required this.hotkey,
    required this.hashtags,
    required this.fixedText,
    required this.saveFolder,
    required this.launchAtStartup,
    this.replyTweet = '',
    this.continueThread = false,
    this.finishHotkey = HotkeyConfig.ctrlShiftD,
    this.batchMode = true,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      targetProcessExe: '',
      targetTitleSubstring: '',
      hotkey: HotkeyConfig.ctrlShiftS,
      hashtags: defaultHashtags,
      fixedText: '',
      saveFolder: '',
      launchAtStartup: false,
      replyTweet: '',
      continueThread: false,
      finishHotkey: HotkeyConfig.ctrlShiftD,
      batchMode: true,
    );
  }

  /// Executable file name, for example `VRChat.exe`. Empty when unset.
  final String targetProcessExe;

  /// Optional case-insensitive substring of the window title.
  final String targetTitleSubstring;

  final HotkeyConfig hotkey;

  /// Normalized tags, each starting with `#`.
  final List<String> hashtags;

  final String fixedText;

  /// Empty means `%USERPROFILE%\Pictures\SnapPost`.
  final String saveFolder;

  final bool launchAtStartup;

  /// Tweet URL or numeric status id. Used when [continueThread] is on.
  final String replyTweet;

  /// When true, the intent URL includes `in_reply_to` for [replyTweet].
  final bool continueThread;

  /// Hotkey that posts the pending batch. Default is Ctrl+Shift+D.
  final HotkeyConfig finishHotkey;

  /// When true, captures accumulate up to four images before posting.
  final bool batchMode;

  WindowTarget get target => WindowTarget(
    processExe: targetProcessExe,
    titleSubstring: targetTitleSubstring,
  );

  AppSettings copyWith({
    String? targetProcessExe,
    String? targetTitleSubstring,
    HotkeyConfig? hotkey,
    List<String>? hashtags,
    String? fixedText,
    String? saveFolder,
    bool? launchAtStartup,
    String? replyTweet,
    bool? continueThread,
    HotkeyConfig? finishHotkey,
    bool? batchMode,
  }) {
    return AppSettings(
      targetProcessExe: targetProcessExe ?? this.targetProcessExe,
      targetTitleSubstring: targetTitleSubstring ?? this.targetTitleSubstring,
      hotkey: hotkey ?? this.hotkey,
      hashtags: hashtags ?? this.hashtags,
      fixedText: fixedText ?? this.fixedText,
      saveFolder: saveFolder ?? this.saveFolder,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      replyTweet: replyTweet ?? this.replyTweet,
      continueThread: continueThread ?? this.continueThread,
      finishHotkey: finishHotkey ?? this.finishHotkey,
      batchMode: batchMode ?? this.batchMode,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'targetProcessExe': targetProcessExe,
    'targetTitleSubstring': targetTitleSubstring,
    'hotkey': hotkey.toJson(),
    'hashtags': hashtags,
    'fixedText': fixedText,
    'saveFolder': saveFolder,
    'launchAtStartup': launchAtStartup,
    'replyTweet': replyTweet,
    'continueThread': continueThread,
    'finishHotkey': finishHotkey.toJson(),
    'batchMode': batchMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final hotkeyJson = json['hotkey'];
    final finishJson = json['finishHotkey'];
    return AppSettings(
      targetProcessExe: _string(json['targetProcessExe']),
      targetTitleSubstring: _string(json['targetTitleSubstring']),
      hotkey: hotkeyJson is Map
          ? HotkeyConfig.fromJson(_stringKeyMap(hotkeyJson))
          : HotkeyConfig.ctrlShiftS,
      hashtags: json.containsKey('hashtags')
          ? _readHashtags(json['hashtags'])
          : List<String>.from(defaultHashtags),
      fixedText: _string(json['fixedText']),
      saveFolder: _string(json['saveFolder']),
      launchAtStartup: json['launchAtStartup'] == true,
      replyTweet: _string(json['replyTweet']),
      continueThread: json['continueThread'] == true,
      finishHotkey: finishJson is Map
          ? HotkeyConfig.fromJson(_stringKeyMap(finishJson))
          : HotkeyConfig.ctrlShiftD,
      batchMode: json.containsKey('batchMode')
          ? json['batchMode'] == true
          : true,
    );
  }
}

String _string(Object? value) => value is String ? value : '';

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((dynamic key, dynamic item) => MapEntry('$key', item));
}

List<String> _readHashtags(Object? value) {
  if (value is String) return normalizeHashtags(value);
  if (value is List) {
    return normalizeHashtags(value.map((dynamic item) => '$item').join(' '));
  }
  return const <String>[];
}
