import 'package:equatable/equatable.dart';

/// Reading statistics of a favorite novel, used for the unread badge on
/// the bookshelf grid.
class BookshelfStat extends Equatable {
  /// Total number of chapters of the novel.
  final int totalChapters;

  /// Number of chapters after the last read chapter.
  final int unreadCount;

  /// The ID of the last read chapter, used as a proxy for "recently read"
  /// sorting (a higher chapter ID generally means more recently read).
  final int lastReadChapterId;

  const BookshelfStat({
    required this.totalChapters,
    required this.unreadCount,
    this.lastReadChapterId = 0,
  });

  @override
  List<Object?> get props => [totalChapters, unreadCount, lastReadChapterId];

  BookshelfStat copyWith({
    int? totalChapters,
    int? unreadCount,
    int? lastReadChapterId,
  }) {
    return BookshelfStat(
      totalChapters: totalChapters ?? this.totalChapters,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadChapterId: lastReadChapterId ?? this.lastReadChapterId,
    );
  }

  Map<String, dynamic> toJson() => {
        't': totalChapters,
        'u': unreadCount,
        'l': lastReadChapterId,
      };

  factory BookshelfStat.fromJson(Map<String, dynamic> json) {
    return BookshelfStat(
      totalChapters: (json['t'] as num?)?.toInt() ?? 0,
      unreadCount: (json['u'] as num?)?.toInt() ?? 0,
      lastReadChapterId: (json['l'] as num?)?.toInt() ?? 0,
    );
  }
}
