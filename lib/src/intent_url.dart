import 'hashtags.dart';

/// Post body: optional fixed text, then the hashtags on the following line.
String composePostText({
  required List<String> hashtags,
  String fixedText = '',
}) {
  final tags = formatHashtags(hashtags);
  final message = fixedText.trim();
  if (message.isEmpty) return tags;
  if (tags.isEmpty) return message;
  return '$message\n$tags';
}

/// X compose URL. Spaces are `%20` and `#` is `%23`, including non-ASCII tags.
///
/// [Uri.encodeComponent] is used on purpose. [Uri.encodeQueryComponent] would
/// turn the space between hashtags into `+`.
String buildIntentUrl({
  required List<String> hashtags,
  String fixedText = '',
  String? inReplyTo,
}) {
  final text = composePostText(hashtags: hashtags, fixedText: fixedText);
  final encoded = Uri.encodeComponent(text);
  if (inReplyTo != null && inReplyTo.isNotEmpty) {
    return 'https://x.com/intent/post?in_reply_to=$inReplyTo&text=$encoded';
  }
  return 'https://x.com/intent/post?text=$encoded';
}
