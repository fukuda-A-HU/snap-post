import 'package:flutter_test/flutter_test.dart';
import 'package:snap_post/src/pending_batch.dart';

void main() {
  test('keeps capture order and auto-finishes on the fourth image', () {
    final batch = PendingBatch();
    expect(batch.add(const PendingImage('a.png')), BatchAdd.added);
    expect(batch.add(const PendingImage('b.png')), BatchAdd.added);
    expect(batch.add(const PendingImage('c.png')), BatchAdd.added);
    expect(batch.length, 3);
    expect(batch.isFull, isFalse);

    expect(batch.add(const PendingImage('d.png')), BatchAdd.readyToPost);
    expect(batch.paths, <String>['a.png', 'b.png', 'c.png', 'd.png']);
    expect(batch.isFull, isTrue);
    expect(() => batch.add(const PendingImage('e.png')), throwsStateError);
  });

  test('removal keeps the remaining order', () {
    final batch = PendingBatch()..folder = 'batch';
    batch.add(const PendingImage('a.png'));
    batch.add(const PendingImage('b.png'));
    batch.add(const PendingImage('c.png'));

    expect(batch.removeAt(1).path, 'b.png');
    expect(batch.paths, <String>['a.png', 'c.png']);
    expect(batch.folder, 'batch');

    batch.removeAt(0);
    batch.removeAt(0);
    expect(batch.isEmpty, isTrue);
    expect(batch.folder, isNull);
  });

  test('clear drops the queue and its folder', () {
    final batch = PendingBatch()..folder = 'batch';
    batch.add(const PendingImage('a.png'));
    batch.add(const PendingImage('b.png'));
    batch.clear();
    expect(batch.paths, isEmpty);
    expect(batch.folder, isNull);
    expect(batch.add(const PendingImage('c.png')), BatchAdd.added);
    expect(batch.paths, <String>['c.png']);
  });
}
