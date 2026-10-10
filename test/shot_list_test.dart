import 'package:flutter_test/flutter_test.dart';
import 'package:snap_post/src/shot_list.dart';

void main() {
  test('stores every capture and auto-checks only the first four', () {
    final shots = ShotList();
    for (var index = 1; index <= 5; index++) {
      shots.add('$index.png');
    }
    expect(shots.length, 5);
    expect(shots.paths, <String>['1.png', '2.png', '3.png', '4.png', '5.png']);
    expect(shots.selectedPaths, <String>['1.png', '2.png', '3.png', '4.png']);
    expect(shots.selectionFull, isTrue);
    expect(shots.setSelected(4, true), isFalse);
    expect(shots.shots[4].selected, isFalse);
  });

  test('unchecking one lets the next capture be checked', () {
    final shots = ShotList();
    for (final name in <String>['a.png', 'b.png', 'c.png', 'd.png']) {
      shots.add(name);
    }
    expect(shots.setSelected(1, false), isTrue);
    shots.add('e.png');
    expect(shots.selectedPaths, <String>['a.png', 'c.png', 'd.png', 'e.png']);
    expect(shots.setSelected(1, true), isFalse);
  });

  test('deletion keeps the remaining order and frees a selection slot', () {
    final shots = ShotList();
    for (final name in <String>['a.png', 'b.png', 'c.png', 'd.png', 'e.png']) {
      shots.add(name);
    }
    expect(shots.removeAt(0).path, 'a.png');
    expect(shots.paths, <String>['b.png', 'c.png', 'd.png', 'e.png']);
    expect(shots.selectedCount, 3);
    expect(shots.setSelected(3, true), isTrue);
    expect(shots.selectedPaths, <String>['b.png', 'c.png', 'd.png', 'e.png']);
    expect(shots.setSelected(0, false), isTrue);
    shots.dropSelected();
    expect(shots.paths, <String>['b.png']);
    expect(shots.shots.single.selected, isFalse);
  });
}
