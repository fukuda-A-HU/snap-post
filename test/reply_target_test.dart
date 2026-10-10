import 'package:flutter_test/flutter_test.dart';
import 'package:snap_post/src/reply_target.dart';

void main() {
  test('parses x.com and twitter.com status URLs', () {
    expect(
      parseStatusId('https://x.com/name/status/1234567890123456789'),
      '1234567890123456789',
    );
    expect(parseStatusId('https://twitter.com/name/status/42'), '42');
    expect(parseStatusId('https://x.com/i/web/status/9'), '9');
    expect(parseStatusId('https://x.com/name/status/10/photo/1'), '10');
  });

  test('ignores query strings and fragments', () {
    expect(parseStatusId('https://www.x.com/name/status/7?s=20&t=abc'), '7');
    expect(parseStatusId('https://mobile.twitter.com/name/status/8/'), '8');
    expect(
      parseStatusId('http://x.com/name/status/15?next=/status/999#status/1'),
      '15',
    );
    expect(parseStatusId('HTTPS://Twitter.com/name/status/17?s=21'), '17');
  });

  test('accepts a bare numeric id and a URL without a scheme', () {
    expect(parseStatusId('  99  '), '99');
    expect(parseStatusId('x.com/name/status/16'), '16');
    expect(parseStatusId('see https://x.com/name/status/18 thanks'), '18');
  });

  test('rejects empty text, other hosts, and non-ids', () {
    expect(parseStatusId(''), isNull);
    expect(parseStatusId('   '), isNull);
    expect(parseStatusId('https://example.com/status/1'), isNull);
    expect(parseStatusId('https://x.com/home'), isNull);
    expect(parseStatusId('123abc'), isNull);
    expect(parseStatusId('not a url'), isNull);
  });

  test('thread id is used only while the toggle is on', () {
    expect(
      activeReplyStatusId(
        continueThread: true,
        replyTweet: 'https://x.com/name/status/5?s=1',
      ),
      '5',
    );
    expect(
      activeReplyStatusId(
        continueThread: false,
        replyTweet: 'https://x.com/name/status/5',
      ),
      isNull,
    );
    expect(
      activeReplyStatusId(continueThread: true, replyTweet: 'nope'),
      isNull,
    );
  });
}
