import 'package:equatable/equatable.dart';

/// Reading statistics of a favorite novel, used for the unread badge on
/// the bookshelf grid.
class BookshelfStat extends Equatable {
  /// Total number of chapters of the novel.
  final int totalChapters;

  /// Number of chapters after the last read chapter.
  final int unreadCount;

  /// The ID of the last read chapter.
  final int lastReadChapterId;

  /// Timestamp of the most recent reading session (milliseconds since
  /// epoch), recorded locally. Null when the novel has never been read
  /// locally; used by the "recently read" sort.
  final int? lastReadAt;

  const BookshelfStat({
    required this.totalChapters,
    required this.unreadCount,
    this.lastReadChapterId = 0,
    this.lastReadAt,
  });

  @override
  List<Object?> get props => [
        totalChapters,
        unreadCount,
        lastReadChapterId,
        lastReadAt,
      ];

  BookshelfStat copyWith({
    int? totalChapters,
    int? unreadCount,
    int? lastReadChapterId,
    int? lastReadAt,
  }) {
    return BookshelfStat(
      totalChapters: totalChapters ?? this.totalChapters,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadChapterId: lastReadChapterId ?? this.lastReadChapterId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  Map<String, dynamic> toJson() => {
        't': totalChapters,
        'u': unreadCount,
        'l': lastReadChapterId,
        'r': lastReadAt,
      };

  factory BookshelfStat.fromJson(Map<String, dynamic> json) {
    return BookshelfStat(
      totalChapters: (json['t'] as num?)?.toInt() ?? 0,
      unreadCount: (json['u'] as num?)?.toInt() ?? 0,
      lastReadChapterId: (json['l'] as num?)?.toInt() ?? 0,
      lastReadAt: (json['r'] as num?)?.toInt(),
    );
  }
}
