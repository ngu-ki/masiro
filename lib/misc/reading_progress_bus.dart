import 'dart:async';

/// Carries the outcome of a reading session so the bookshelf can move the
/// just-read novel to the top of the "recently read" sort immediately,
/// regardless of which screen launched the reader.
class ReadingProgressUpdate {
  final int novelId;
  final int lastReadChapterId;
  final int lastReadAt;

  const ReadingProgressUpdate({
    required this.novelId,
    required this.lastReadChapterId,
    required this.lastReadAt,
  });
}

/// A broadcast channel for reading-progress updates. The favorites bloc
/// listens to it so that reading sessions started from the novel detail
/// page (which has no direct access to the favorites bloc) still re-sort
/// the bookshelf in real time.
class ReadingProgressBus {
  final StreamController<ReadingProgressUpdate> _controller =
      StreamController<ReadingProgressUpdate>.broadcast();

  Stream<ReadingProgressUpdate> get stream => _controller.stream;

  void publish(ReadingProgressUpdate update) {
    if (!_controller.isClosed) {
      _controller.add(update);
    }
  }

  void dispose() => _controller.close();
}
