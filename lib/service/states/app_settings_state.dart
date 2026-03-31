import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/service/services.dart';

class SettingsCubit extends Cubit<SettingsState> {
  AppSettings settings = AppSettings();

  SettingsCubit()
      : super(SettingsState()){
    _loadSettings();
  }

  _loadSettings(){
    emit(state.copyWith(arabicTextSize: settings.arabicTextSize, englishTextSize: settings.englishTextSize));
  }

  void updateArabicTextSize (int size){
    settings.arabicTextSize = size;
    emit(state.copyWith(arabicTextSize: size));
  }

  void updateEnglishTextSize (int size){
    settings.englishTextSize = size;
    emit(state.copyWith(englishTextSize: size));
  }

}

class SettingsState {
  int? arabicTextSize;
  int? englishTextSize;

  SettingsState({this.arabicTextSize, this.englishTextSize});

  SettingsState copyWith({int? arabicTextSize, int? englishTextSize}) {
    return SettingsState(
      arabicTextSize: arabicTextSize ?? this.arabicTextSize,
      englishTextSize: englishTextSize ?? this.englishTextSize,
    );
  }
}
