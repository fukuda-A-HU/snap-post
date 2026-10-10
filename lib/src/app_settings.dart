import 'hashtags.dart';
import 'window_match.dart';

class AppSettings {
  const AppSettings({
    required this.targetProcessExe,
    required this.targetTitleSubstring,
    required this.hashtags,
    required this.fixedText,
    required this.saveFolder,
    required this.launchAtStartup,
    this.replyTweet = '',
    this.continueThread = false,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      targetProcessExe: '',
      targetTitleSubstring: '',
      hashtags: defaultHashtags,
      fixedText: '',
      saveFolder: '',
      launchAtStartup: false,
      replyTweet: '',
      continueThread: false,
    );
  }

  /// Executable file name, for example `VRChat.exe`. Empty when unset.
  final String targetProcessExe;

  /// Optional case-insensitive substring of the window title.
  final String targetTitleSubstring;

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

  WindowTarget get target => WindowTarget(
    processExe: targetProcessExe,
    titleSubstring: targetTitleSubstring,
  );

  bool get hasTarget => targetProcessExe.trim().isNotEmpty;

  AppSettings copyWith({
    String? targetProcessExe,
    String? targetTitleSubstring,
    List<String>? hashtags,
    String? fixedText,
    String? saveFolder,
    bool? launchAtStartup,
    String? replyTweet,
    bool? continueThread,
  }) {
    return AppSettings(
      targetProcessExe: targetProcessExe ?? this.targetProcessExe,
      targetTitleSubstring: targetTitleSubstring ?? this.targetTitleSubstring,
      hashtags: hashtags ?? this.hashtags,
      fixedText: fixedText ?? this.fixedText,
      saveFolder: saveFolder ?? this.saveFolder,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      replyTweet: replyTweet ?? this.replyTweet,
      continueThread: continueThread ?? this.continueThread,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'targetProcessExe': targetProcessExe,
    'targetTitleSubstring': targetTitleSubstring,
    'hashtags': hashtags,
    'fixedText': fixedText,
    'saveFolder': saveFolder,
    'launchAtStartup': launchAtStartup,
    'replyTweet': replyTweet,
    'continueThread': continueThread,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      targetProcessExe: _string(json['targetProcessExe']),
      targetTitleSubstring: _string(json['targetTitleSubstring']),
      hashtags: json.containsKey('hashtags')
          ? _readHashtags(json['hashtags'])
          : List<String>.from(defaultHashtags),
      fixedText: _string(json['fixedText']),
      saveFolder: _string(json['saveFolder']),
      launchAtStartup: json['launchAtStartup'] == true,
      replyTweet: _string(json['replyTweet']),
      continueThread: json['continueThread'] == true,
    );
  }
}

String _string(Object? value) => value is String ? value : '';

List<String> _readHashtags(Object? value) {
  if (value is String) return normalizeHashtags(value);
  if (value is List) {
    return normalizeHashtags(value.map((dynamic item) => '$item').join(' '));
  }
  return const <String>[];
}
