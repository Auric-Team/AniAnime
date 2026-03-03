class AnimeModel {
  final String id;
  final String name;
  final String poster;
  final String? description;
  final String? type;
  final String? duration;
  final int? episodesSub;
  final int? episodesDub;

  AnimeModel({
    required this.id,
    required this.name,
    required this.poster,
    this.description,
    this.type,
    this.duration,
    this.episodesSub,
    this.episodesDub,
  });

  factory AnimeModel.fromJson(Map<String, dynamic> json) {
    return AnimeModel(
      id: json['id'] ?? '',
      name: json['name'] ?? json['title'] ?? '',
      poster: json['poster'] ?? '',
      description: json['description'],
      type: json['type'],
      duration: json['duration'],
      episodesSub: json['episodes']?['sub'],
      episodesDub: json['episodes']?['dub'],
    );
  }
}

class EpisodeModel {
  final String id;
  final int number;
  final String title;
  final bool isFiller;

  EpisodeModel({
    required this.id,
    required this.number,
    required this.title,
    required this.isFiller,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    return EpisodeModel(
      id: json['episodeId'] ?? '',
      number: json['number'] ?? 0,
      title: json['title'] ?? 'Episode ${json['number']}',
      isFiller: json['isFiller'] ?? false,
    );
  }
}
