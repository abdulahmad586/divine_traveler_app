import 'dart:convert';

class SurahAudio {
  String audioName;
  String surahNameEnglish;
  String surahNameArabic;
  int surahNumber;
  int totalAyahs;
  int trackDuration;
  String? localFileUrl;
  String? remoteFileUrl;
  List<AyahAudio> ayahs;
  String reciterName;
  String fileHash;
  bool verified;
  bool uploadConsent;
  String? driveFileId;
  String? driveTimingFileId;
  DateTime? lastUpdated;
  String? contributionId;
  String? createdByName;

  SurahAudio({
    required this.audioName,
    required this.surahNumber,
    required this.surahNameArabic,
    required this.surahNameEnglish,
    required this.totalAyahs,
    required this.ayahs,
    required this.reciterName,
    required this.fileHash,
    required this.trackDuration,
    this.localFileUrl,
    this.remoteFileUrl,
    this.verified=false,
    this.uploadConsent=true,
    this.driveFileId,
    this.driveTimingFileId,
    this.lastUpdated,
    this.contributionId,
    this.createdByName,
  });

  Map<String, dynamic> toMap() {
    return {
      'audioName': audioName,
      'surahNumber': surahNumber,
      'surahNameArabic': surahNameArabic,
      'surahNameEnglish': surahNameEnglish,
      'totalAyahs': totalAyahs,
      'trackDuration': trackDuration,
      'ayahs': ayahs.map((e) => e.toMap()).toList(),
      'localFileUrl': localFileUrl,
      'remoteFileUrl': remoteFileUrl,
      'reciterName': reciterName,
      'fileHash': fileHash,
      'verified' : verified,
      'uploadConsent': uploadConsent,
      'driveFileId': driveFileId,
      'driveTimingFileId': driveTimingFileId,
      'lastUpdated':lastUpdated?.toIso8601String(),
      'contributionId': contributionId,
      'createdByName': createdByName,
    };
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  static SurahAudio fromMap(Map<String, dynamic> map) {
    return SurahAudio(
      audioName: map['audioName'],
      surahNumber: map['surahNumber'],
      surahNameArabic: map['surahNameArabic'],
      surahNameEnglish: map['surahNameEnglish'],
      totalAyahs: map['totalAyahs']??0,
      trackDuration: map['trackDuration']??0,
      ayahs: List.generate(map['ayahs'].length, (index) => AyahAudio.fromMap(map['ayahs'][index])),
      localFileUrl: map['localFileUrl'],
      remoteFileUrl: map['remoteFileUrl'],
      reciterName: map['reciterName'] ?? "",
      fileHash: map['fileHash'] ?? "",
      verified: map['verified'] ?? false,
      uploadConsent: map['uploadConsent'] ?? true,
      driveFileId: map['driveFileId'],
      driveTimingFileId: map['driveTimingFileId'],
      lastUpdated: map['lastUpdated'] != null ? DateTime.parse(map['lastUpdated']):null,
      contributionId: map['contributionId'],
      createdByName: map['createdByName'],
    );
  }

  static List<SurahAudio> parseMany(List<dynamic> list){
    return List.generate(list.length, (index) => SurahAudio.fromMap(list[index]));
  }

  static List<SurahAudio> fromJsonArray(String audioSurahs) {
    List<SurahAudio> audioFiles = [];
    if(audioSurahs.isNotEmpty){
      audioFiles.addAll(SurahAudio.parseMany(jsonDecode(audioSurahs) as List<dynamic>));
    }
    return audioFiles;
  }

  static String toJsonArray(List<SurahAudio> list) {

    return jsonEncode(List.generate(list.length, (index) => list[index].toMap()));

  }

}

class AyahAudio {
  int ayahNumber;
  int startFrom;
  int endAt;

  AyahAudio(
      {required this.ayahNumber, required this.startFrom, required this.endAt});

  Map<String, dynamic> toMap() {
    return {'ayahNumber': ayahNumber, 'startFrom': startFrom, 'endAt': endAt};
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  static AyahAudio fromMap(Map<String, dynamic> map) {
    return AyahAudio(
        ayahNumber: map['ayahNumber'],
        startFrom: map['startFrom'],
        endAt: map['endAt']);
  }
}
