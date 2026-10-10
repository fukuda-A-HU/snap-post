final RegExp _bareStatusId = RegExp(r'^\d{1,20}$');
final RegExp _statusInPath = RegExp(r'/status/(\d{1,20})');
final RegExp _embeddedUrl = RegExp(r'https?://\S+', caseSensitive: false);

/// Numeric status id from a tweet URL or a bare id. Query strings are ignored.
///
/// Accepts `x.com` and `twitter.com` (including subdomains) with `/status/<id>`.
String? parseStatusId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (_bareStatusId.hasMatch(trimmed)) return trimmed;

  final embedded = _embeddedUrl.firstMatch(trimmed)?.group(0);
  final candidate = _stripTrailingPunctuation(embedded ?? trimmed);
  final direct = Uri.tryParse(candidate);
  final fromDirect = _idFromUri(direct);
  if (fromDirect != null) return fromDirect;
  if (direct != null && direct.host.isNotEmpty) return null;
  return _idFromUri(Uri.tryParse('https://$candidate'));
}

/// Text shown for the current reply target. Bare ids become an x.com URL.
String displayReplyTarget(String stored) {
  final id = parseStatusId(stored);
  if (id == null) return '未設定';
  final trimmed = stored.trim();
  final url = _embeddedUrl.firstMatch(trimmed)?.group(0);
  if (url != null) return _stripTrailingPunctuation(url);
  if (trimmed.contains('://') ||
      trimmed.toLowerCase().contains('x.com') ||
      trimmed.toLowerCase().contains('twitter.com')) {
    return trimmed;
  }
  return 'https://x.com/i/status/$id';
}

/// Id used for `in_reply_to` when the thread toggle is on and the field parses.
String? activeReplyStatusId({
  required bool continueThread,
  required String replyTweet,
}) {
  if (!continueThread) return null;
  return parseStatusId(replyTweet);
}

String _stripTrailingPunctuation(String value) {
  return value.replaceFirst(RegExp(r'[)\].,>]+$'), '');
}

String? _idFromUri(Uri? uri) {
  if (uri == null || uri.host.isEmpty || !_isTweetHost(uri.host)) return null;
  return _statusInPath.firstMatch(uri.path)?.group(1);
}

bool _isTweetHost(String host) {
  final name = host.toLowerCase();
  return name == 'x.com' ||
      name == 'twitter.com' ||
      name.endsWith('.x.com') ||
      name.endsWith('.twitter.com');
}
