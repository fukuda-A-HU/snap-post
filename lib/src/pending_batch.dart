class PendingImage {
  const PendingImage(this.path);

  final String path;
}

enum BatchAdd { added, readyToPost }

/// In-memory queue of screenshots for one X post. At most [maxImages].
class PendingBatch {
  static const int maxImages = 4;

  final List<PendingImage> _images = <PendingImage>[];

  /// Folder created for the current batch. Cleared when the queue is empty.
  String? folder;

  List<PendingImage> get images => List<PendingImage>.unmodifiable(_images);

  List<String> get paths => <String>[for (final image in _images) image.path];

  int get length => _images.length;

  bool get isEmpty => _images.isEmpty;

  bool get isFull => _images.length >= maxImages;

  /// Appends [image]. The fourth image returns [BatchAdd.readyToPost].
  BatchAdd add(PendingImage image) {
    if (_images.length >= maxImages) {
      throw StateError('a batch holds at most $maxImages images');
    }
    _images.add(image);
    return _images.length == maxImages ? BatchAdd.readyToPost : BatchAdd.added;
  }

  PendingImage removeAt(int index) {
    final removed = _images.removeAt(index);
    if (_images.isEmpty) folder = null;
    return removed;
  }

  void clear() {
    _images.clear();
    folder = null;
  }
}
