import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/service/services.dart';

class SettingsCubit extends Cubit<SettingsState> {
  AppSettings settings = AppSettings();

  SettingsCubit() : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    emit(state.copyWith(
      arabicTextSize:           settings.arabicTextSize,
      englishTextSize:          settings.englishTextSize,
      journeyRemindersEnabled:  settings.journeyRemindersEnabled,
      nudgeNotificationsEnabled: settings.nudgeNotificationsEnabled,
      companionActivityEnabled: settings.companionActivityEnabled,
    ));
  }

  void updateArabicTextSize(int size) {
    settings.arabicTextSize = size;
    emit(state.copyWith(arabicTextSize: size));
  }

  void updateEnglishTextSize(int size) {
    settings.englishTextSize = size;
    emit(state.copyWith(englishTextSize: size));
  }

  void setJourneyReminders(bool enabled) {
    settings.journeyRemindersEnabled = enabled;
    emit(state.copyWith(journeyRemindersEnabled: enabled));
  }

  void setNudgeNotifications(bool enabled) {
    settings.nudgeNotificationsEnabled = enabled;
    emit(state.copyWith(nudgeNotificationsEnabled: enabled));
  }

  void setCompanionActivity(bool enabled) {
    settings.companionActivityEnabled = enabled;
    emit(state.copyWith(companionActivityEnabled: enabled));
  }
}

class SettingsState {
  final int? arabicTextSize;
  final int? englishTextSize;
  final bool journeyRemindersEnabled;
  final bool nudgeNotificationsEnabled;
  final bool companionActivityEnabled;

  SettingsState({
    this.arabicTextSize,
    this.englishTextSize,
    this.journeyRemindersEnabled  = true,
    this.nudgeNotificationsEnabled = true,
    this.companionActivityEnabled = true,
  });

  SettingsState copyWith({
    int? arabicTextSize,
    int? englishTextSize,
    bool? journeyRemindersEnabled,
    bool? nudgeNotificationsEnabled,
    bool? companionActivityEnabled,
  }) =>
      SettingsState(
        arabicTextSize:            arabicTextSize            ?? this.arabicTextSize,
        englishTextSize:           englishTextSize           ?? this.englishTextSize,
        journeyRemindersEnabled:   journeyRemindersEnabled   ?? this.journeyRemindersEnabled,
        nudgeNotificationsEnabled: nudgeNotificationsEnabled ?? this.nudgeNotificationsEnabled,
        companionActivityEnabled:  companionActivityEnabled  ?? this.companionActivityEnabled,
      );
}
