import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/service/services.dart';

class AudioFilesCubit extends Cubit<AudioFilesState> {

  final int surahNumber;
  final appStorage = AppStorage();

  AudioFilesCubit(this.surahNumber)
      : super(AudioFilesState(
    errorStr: "",
    error: false,
  )){
      List<SurahAudio> audioFiles = SurahAudio.fromJsonArray(appStorage.getAudioSurahs(surahNumber));
      emit(state.copyWith(audioFiles: audioFiles,));
  }

  void addSurahAudio(SurahAudio surahAudio) {
    if(state.audioFiles != null && !state.audioFiles!.contains(surahAudio)){
      emit(state.copyWith(audioFiles: [...(state.audioFiles!), surahAudio]));
      appStorage.setAudioSurahs(surahNumber, SurahAudio.toJsonArray(state.audioFiles!));
    }
  }

  void updateSurahAudio(SurahAudio surahAudio, int index) {
    if(state.audioFiles != null && state.audioFiles!.length > index){
      final files = [...state.audioFiles!];
      files[index]=surahAudio;
      emit(state.copyWith(audioFiles: files));
      appStorage.setAudioSurahs(surahNumber, SurahAudio.toJsonArray(files));
    }
  }

  void removeSurahAudio(int index){
    if(state.audioFiles != null && state.audioFiles!.length > index){
      final files = [...state.audioFiles!];
      files.removeAt(index);
      emit(state.copyWith(audioFiles: files));
      appStorage.setAudioSurahs(surahNumber, SurahAudio.toJsonArray(files));
    }
  }


}

class AudioFilesState {
  AudioFilesState? lastState;
  String? errorStr;
  bool? error;
  List<SurahAudio>? audioFiles;

  AudioFilesState({this.audioFiles, this.errorStr, this.error = false});

  AudioFilesState copyWith({bool? error, String? errorStr, bool? loggedIn, List<SurahAudio>? audioFiles}) {
    return AudioFilesState(
      error: error ?? this.error,
      errorStr: errorStr ?? this.errorStr,
      audioFiles: audioFiles ?? this.audioFiles,
    );
  }
}
