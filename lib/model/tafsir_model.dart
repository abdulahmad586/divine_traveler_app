class TafsirResponse {
  final String surahName;
  final int surahNo;
  final int ayahNo;
  final List<Tafsir> tafsirs;

  TafsirResponse({
    required this.surahName,
    required this.surahNo,
    required this.ayahNo,
    required this.tafsirs,
  });

  factory TafsirResponse.fromJson(Map<String, dynamic> json) {
    return TafsirResponse(
      surahName: json['surahName'],
      surahNo: json['surahNo'],
      ayahNo: json['ayahNo'],
      tafsirs:
          (json['tafsirs'] as List).map((e) => Tafsir.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surahName': surahName,
      'surahNo': surahNo,
      'ayahNo': ayahNo,
      'tafsirs': tafsirs.map((e) => e.toJson()).toList(),
    };
  }
}

class Tafsir {
  final String author;
  final String? groupVerse;
  final String content;

  Tafsir({
    required this.author,
    required this.groupVerse,
    required this.content,
  });

  factory Tafsir.fromJson(Map<String, dynamic> json) {
    return Tafsir(
      author: json['author'],
      groupVerse: json['groupVerse'],
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'groupVerse': groupVerse,
      'content': content,
    };
  }
}
