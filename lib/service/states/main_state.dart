import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/service/services.dart';

class MainCubit extends Cubit<MainState> {
  MainCubit()
      : super(MainState(
    errorStr: "",
    error: false,
    loggedIn: false,
    currentPage: 1,
    currentVerse: 1,
  )){
    if(state.appStorage == null){
      AppStorage storage= AppStorage();
      emit(state.copyWith(appStorage: storage, currentPage: storage.currentPage, currentVerse: storage.currentVerse));
    }
  }

  void updateCurrentPage (int currentPage){
    // print("Updating appStorage: ${state.appStorage}");
    state.appStorage?.currentPage = currentPage;
    emit(state.copyWith(appStorage: state.appStorage, currentPage: currentPage));
  }

  void updateCurrentVerse (int currentVerse){
    state.appStorage?.currentVerse = currentVerse;
    emit(state.copyWith(appStorage: state.appStorage, currentVerse: currentVerse));
  }

}

class MainState {
  MainState? lastState;
  String? errorStr;
  bool? error;
  bool? loggedIn;
  AppStorage? appStorage;
  int? currentPage;
  int? currentVerse;

  MainState({this.appStorage, this.errorStr, this.error = false, this.loggedIn, this.currentPage=1, this.currentVerse=1});

  MainState copyWith({bool? error, String? errorStr, bool? loggedIn, AppStorage? appStorage, int? currentPage, int? currentVerse}) {
    return MainState(
      error: error ?? this.error,
      errorStr: errorStr ?? this.errorStr,
      loggedIn: loggedIn ?? this.loggedIn,
      appStorage: appStorage ?? this.appStorage,
      currentPage: currentPage ?? this.currentPage,
      currentVerse: currentVerse ?? this.currentVerse,
    );
  }
}
