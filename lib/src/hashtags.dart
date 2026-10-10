/// Hashtags used until the user saves a settings file.
const List<String> defaultHashtags = <String>['#VR活動報告大会2026', '#NUMA'];

final RegExp _separator = RegExp(r'[\s,、，]+');

/// Splits [input] into tags. A leading `#` or `＃` is optional and is not
/// repeated. Tags are separated by spaces in [formatHashtags].
List<String> normalizeHashtags(String input) {
  final seen = <String>{};
  final tags = <String>[];
  for (final part in input.split(_separator)) {
    var body = part.trim();
    if (body.isEmpty) continue;
    while (body.startsWith('#') || body.startsWith('＃')) {
      body = body.substring(1).trim();
    }
    if (body.isEmpty) continue;
    final tag = '#$body';
    if (seen.add(tag.toLowerCase())) {
      tags.add(tag);
    }
  }
  return tags;
}

/// Space-separated `#tag` list.
String formatHashtags(List<String> tags) => tags.join(' ');
