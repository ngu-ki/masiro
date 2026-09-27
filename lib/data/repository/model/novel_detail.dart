import 'package:equatable/equatable.dart';
import 'package:masiro/data/repository/model/volume.dart';

class NovelDetail extends Equatable {
  final NovelDetailHeader header;
  final List<Volume> volumes;
  final int lastReadChapterId;

  const NovelDetail({
    required this.volumes,
    required this.header,
    required this.lastReadChapterId,
  });

  NovelDetail copyWith({
    NovelDetailHeader? header,
    List<Volume>? volumes,
    int? lastReadChapterId,
  }) {
    return NovelDetail(
      header: header ?? this.header,
      volumes: volumes ?? this.volumes,
      lastReadChapterId: lastReadChapterId ?? this.lastReadChapterId,
    );
  }

  @override
  List<Object?> get props => [header, volumes, lastReadChapterId];
}

class NovelDetailHeader extends Equatable {
  final String title;
  final String author;
  final List<String> translators;
  final List<String> tags;
  final String status;
  final String originalBook;
  final String brief;
  final int words;
  final bool isFavorite;
  final String csrfToken;
  final String coverImg;

  const NovelDetailHeader({
    required this.title,
    required this.author,
    required this.translators,
    required this.tags,
    required this.status,
    required this.originalBook,
    required this.brief,
    required this.words,
    required this.isFavorite,
    required this.csrfToken,
    required this.coverImg,
  });

  NovelDetailHeader copyWith({
    String? title,
    String? author,
    List<String>? translators,
    List<String>? tags,
    String? status,
    String? originalBook,
    String? brief,
    int? words,
    bool? isFavorite,
    String? csrfToken,
    String? coverImg,
  }) {
    return NovelDetailHeader(
      title: title ?? this.title,
      author: author ?? this.author,
      translators: translators ?? this.translators,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      originalBook: originalBook ?? this.originalBook,
      brief: brief ?? this.brief,
      words: words ?? this.words,
      isFavorite: isFavorite ?? this.isFavorite,
      csrfToken: csrfToken ?? this.csrfToken,
      coverImg: coverImg ?? this.coverImg,
    );
  }

  @override
  List<Object?> get props => [
        title,
        author,
        translators,
        tags,
        status,
        originalBook,
        brief,
        words,
        isFavorite,
        csrfToken,
        coverImg,
      ];
}
