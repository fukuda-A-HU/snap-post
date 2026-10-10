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

  /// Tweet URL or numeric status id. A valid value is always sent as
  /// `in_reply_to`. Empty or invalid values are ignored.
  final String replyTweet;

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
  }) {
    return AppSettings(
      targetProcessExe: targetProcessExe ?? this.targetProcessExe,
      targetTitleSubstring: targetTitleSubstring ?? this.targetTitleSubstring,
      hashtags: hashtags ?? this.hashtags,
      fixedText: fixedText ?? this.fixedText,
      saveFolder: saveFolder ?? this.saveFolder,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      replyTweet: replyTweet ?? this.replyTweet,
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
