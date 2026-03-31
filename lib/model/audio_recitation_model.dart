class AudioResponse {
  final int? surahNo;
  final int? ayahNo;
  final List<AudioRecitation> recitations;

  AudioResponse({
    this.surahNo,
    this.ayahNo,
    required this.recitations,
  });

  factory AudioResponse.fromJson(
    Map<String, dynamic> json, {
    int? surahNo,
    int? ayahNo,
  }) {
    final recitations = json.entries.map((entry) {
      return AudioRecitation.fromJson(
        entry.value,
        reciterId: int.tryParse(entry.key),
      );
    }).toList();

    return AudioResponse(
      surahNo: surahNo,
      ayahNo: ayahNo,
      recitations: recitations,
    );
  }
}

class AudioRecitation {
  final int? reciterId;
  final String reciter;
  final String url;
  final String originalUrl;

  AudioRecitation({
    required this.reciterId,
    required this.reciter,
    required this.url,
    required this.originalUrl,
  });

  factory AudioRecitation.fromJson(
    Map<String, dynamic> json, {
    int? reciterId,
  }) {
    return AudioRecitation(
      reciterId: reciterId,
      reciter: json['reciter'],
      url: json['url'],
      originalUrl: json['originalUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reciter': reciter,
      'url': url,
      'originalUrl': originalUrl,
    };
  }
}
