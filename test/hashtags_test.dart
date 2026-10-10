import 'package:flutter_test/flutter_test.dart';
import 'package:snap_post/src/hashtags.dart';

void main() {
  test('adds a hash and keeps Japanese text', () {
    expect(normalizeHashtags('VR活動報告大会2026 NUMA'), <String>[
      '#VR活動報告大会2026',
      '#NUMA',
    ]);
  });

  test('keeps an existing hash and collapses separators', () {
    expect(normalizeHashtags('  #VR活動報告大会2026,  #NUMA、extra，more  '), <String>[
      '#VR活動報告大会2026',
      '#NUMA',
      '#extra',
      '#more',
    ]);
  });

  test('accepts a fullwidth hash and repeated hashes', () {
    expect(normalizeHashtags('＃NUMA ##twice'), <String>['#NUMA', '#twice']);
  });

  test('drops empty pieces and deduplicates case-insensitively', () {
    expect(normalizeHashtags('# #Foo foo FOO'), <String>['#Foo']);
    expect(normalizeHashtags(''), isEmpty);
    expect(normalizeHashtags('   , 、 '), isEmpty);
  });

  test('default tags format with a single space', () {
    expect(formatHashtags(defaultHashtags), '#VR活動報告大会2026 #NUMA');
    expect(normalizeHashtags(formatHashtags(defaultHashtags)), defaultHashtags);
  });
}
