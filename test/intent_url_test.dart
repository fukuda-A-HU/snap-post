import 'package:flutter_test/flutter_test.dart';
import 'package:snap_post/src/app_settings.dart';
import 'package:snap_post/src/hashtags.dart';
import 'package:snap_post/src/intent_url.dart';
import 'package:snap_post/src/reply_target.dart';

void main() {
  test('default hashtags produce the X intent URL', () {
    final settings = AppSettings.defaults();
    expect(settings.hashtags, defaultHashtags);
    expect(settings.fixedText, isEmpty);
    expect(
      buildIntentUrl(
        hashtags: settings.hashtags,
        fixedText: settings.fixedText,
      ),
      'https://x.com/intent/post?text=%23VR%E6%B4%BB%E5%8B%95%E5%A0%B1%E5%91%8A%E5%A4%A7%E4%BC%9A2026%20%23NUMA',
    );
  });

  test('the default URL decodes to the hashtag line', () {
    final url = buildIntentUrl(hashtags: defaultHashtags);
    final uri = Uri.parse(url);
    expect(uri.host, 'x.com');
    expect(uri.path, '/intent/post');
    expect(uri.queryParameters['text'], '#VR活動報告大会2026 #NUMA');
    expect(url.contains('+'), isFalse);
    expect(url.contains('#'), isFalse);
  });

  test('encodes a Japanese message and a newline before the tags', () {
    final url = buildIntentUrl(hashtags: defaultHashtags, fixedText: ' こんにちは ');
    expect(
      Uri.parse(url).queryParameters['text'],
      'こんにちは\n#VR活動報告大会2026 #NUMA',
    );
    expect(
      url.contains('%E3%81%93%E3%82%93%E3%81%AB%E3%81%A1%E3%81%AF'),
      isTrue,
    );
    expect(url.contains('%0A'), isTrue);
  });

  test('encodes reserved characters in the message', () {
    final url = buildIntentUrl(
      hashtags: const <String>[],
      fixedText: 'a&b=c?d #',
    );
    expect(Uri.parse(url).queryParameters['text'], 'a&b=c?d #');
    expect(url.contains('&b'), isFalse);
    expect(url.contains('%26'), isTrue);
  });

  test('adds in_reply_to before text when a thread target is set', () {
    const id = '1234567890';
    final url = buildIntentUrl(hashtags: defaultHashtags, inReplyTo: id);
    expect(
      url,
      'https://x.com/intent/post?in_reply_to=1234567890&text=%23VR%E6%B4%BB%E5%8B%95%E5%A0%B1%E5%91%8A%E5%A4%A7%E4%BC%9A2026%20%23NUMA',
    );
    final uri = Uri.parse(url);
    expect(uri.queryParameters['in_reply_to'], id);
    expect(uri.queryParameters['text'], '#VR活動報告大会2026 #NUMA');
  });

  test('a valid reply target always adds in_reply_to', () {
    final linked = AppSettings.defaults().copyWith(
      replyTweet: 'https://twitter.com/name/status/42?s=20',
    );
    expect(
      buildIntentUrl(
        hashtags: linked.hashtags,
        fixedText: linked.fixedText,
        inReplyTo: activeReplyStatusId(linked.replyTweet),
      ),
      'https://x.com/intent/post?in_reply_to=42&text=%23VR%E6%B4%BB%E5%8B%95%E5%A0%B1%E5%91%8A%E5%A4%A7%E4%BC%9A2026%20%23NUMA',
    );

    final plain = linked.copyWith(replyTweet: 'not a tweet');
    expect(activeReplyStatusId(plain.replyTweet), isNull);
    expect(
      buildIntentUrl(
        hashtags: plain.hashtags,
        inReplyTo: activeReplyStatusId(plain.replyTweet),
      ),
      'https://x.com/intent/post?text=%23VR%E6%B4%BB%E5%8B%95%E5%A0%B1%E5%91%8A%E5%A4%A7%E4%BC%9A2026%20%23NUMA',
    );
  });

  test('omits an empty message and empty tags', () {
    expect(
      buildIntentUrl(hashtags: const <String>[], fixedText: '   '),
      'https://x.com/intent/post?text=',
    );
    expect(
      composePostText(hashtags: const <String>['#NUMA'], fixedText: ''),
      '#NUMA',
    );
  });
}
