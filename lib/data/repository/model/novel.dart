import 'package:equatable/equatable.dart';

final class Novel extends Equatable {
  final int id;
  final String title;
  final String brief;
  final int rank;
  final String coverImg;
  final String? author;
  final String? lastUpdated;
  final String? lastUpdatedTime;
  final int lvLimit;
  final int words;

  const Novel({
    required this.id,
    required this.title,
    required this.brief,
    required this.rank,
    required this.coverImg,
    required this.author,
    required this.lastUpdated,
    required this.lastUpdatedTime,
    required this.lvLimit,
    required this.words,
  });

  factory Novel.fromJson(Map<String, dynamic> json) {
    return Novel(
      id: json['id'] as int,
      title: json['title'] as String,
      brief: json['brief'] as String,
      rank: json['rank'] as int,
      coverImg: json['coverImg'] as String,
      author: json['author'] as String?,
      lastUpdated: json['lastUpdated'] as String?,
      lastUpdatedTime: json['lastUpdatedTime'] as String?,
      lvLimit: json['lvLimit'] as int,
      words: json['words'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'brief': brief,
      'rank': rank,
      'coverImg': coverImg,
      'author': author,
      'lastUpdated': lastUpdated,
      'lastUpdatedTime': lastUpdatedTime,
      'lvLimit': lvLimit,
      'words': words,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        brief,
        rank,
        coverImg,
        author,
        lastUpdated,
        lastUpdatedTime,
        lvLimit,
        words,
      ];
}
