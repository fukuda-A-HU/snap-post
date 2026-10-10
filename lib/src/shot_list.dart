class Shot {
  const Shot({required this.path, required this.selected});

  final String path;
  final bool selected;
}

/// Captures for the current post. Any number can be kept. At most
/// [maxSelected] may be marked for posting.
class ShotList {
  static const int maxSelected = 4;

  final List<Shot> _shots = <Shot>[];

  List<Shot> get shots => List<Shot>.unmodifiable(_shots);

  List<String> get paths => <String>[for (final shot in _shots) shot.path];

  /// Checked images, in list order.
  List<String> get selectedPaths => <String>[
    for (final shot in _shots)
      if (shot.selected) shot.path,
  ];

  int get length => _shots.length;

  int get selectedCount => _shots.where((shot) => shot.selected).length;

  bool get isEmpty => _shots.isEmpty;

  bool get selectionFull => selectedCount >= maxSelected;

  /// Appends a capture. It is checked when fewer than [maxSelected] are.
  void add(String path) {
    _shots.add(Shot(path: path, selected: selectedCount < maxSelected));
  }

  /// Returns false when checking another image would pass [maxSelected].
  bool setSelected(int index, bool selected) {
    final current = _shots[index];
    if (selected && !current.selected && selectionFull) return false;
    _shots[index] = Shot(path: current.path, selected: selected);
    return true;
  }

  Shot removeAt(int index) => _shots.removeAt(index);

  /// Drops checked images from the list. Files on disk are left alone.
  List<Shot> dropSelected() {
    final removed = _shots.where((shot) => shot.selected).toList();
    _shots.removeWhere((shot) => shot.selected);
    return removed;
  }

  void clear() => _shots.clear();
}
