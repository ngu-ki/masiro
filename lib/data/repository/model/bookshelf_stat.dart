import 'package:equatable/equatable.dart';

/// Reading statistics of a favorite novel, used for the unread badge on
/// the bookshelf grid.
class BookshelfStat extends Equatable {
  /// Total number of chapters of the novel.
  final int totalChapters;

  /// Number of chapters after the last read chapter.
  final int unreadCount;

  const BookshelfStat({
    required this.totalChapters,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [totalChapters, unreadCount];

  BookshelfStat copyWith({
    int? totalChapters,
    int? unreadCount,
  }) {
    return BookshelfStat(
      totalChapters: totalChapters ?? this.totalChapters,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toJson() => {
        't': totalChapters,
        'u': unreadCount,
      };

  factory BookshelfStat.fromJson(Map<String, dynamic> json) {
    return BookshelfStat(
      totalChapters: (json['t'] as num?)?.toInt() ?? 0,
      unreadCount: (json['u'] as num?)?.toInt() ?? 0,
    );
  }
}
