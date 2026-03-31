
import 'dart:async';

import 'package:circular_seek_bar/circular_seek_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/resources/colors.dart';
import 'package:tahfeex/service/states/app_settings_state.dart';
import 'package:tahfeex/widgets/widgets.dart';

class EnglishTextSizeSettings extends StatelessWidget {
  const EnglishTextSizeSettings({super.key});

  static const int maxTextSize = 42;
  static const int minTextSize = 12;

  @override
  Widget build(BuildContext context) {

    Timer? canceller;
    void debouncer(Duration delay, Function fn) {
      if (canceller?.isActive ?? false) canceller?.cancel();
      canceller = Timer(delay, () {
        fn();
      });
    }

    ValueNotifier<double> progressChange = ValueNotifier((context.read<SettingsCubit>().state.englishTextSize??minTextSize).toDouble());
    progressChange.addListener(() {
      // debouncer(const Duration(milliseconds: 300), (){
        context.read<SettingsCubit>().updateEnglishTextSize((progressChange.value).toInt());
      // });
    });
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        double progress = (state.englishTextSize!).toDouble();
        print("progress: $progress");
        return Container(
          padding: const EdgeInsets.all(10),
          height: 500,
          child: Column(
            children: [
              const SizedBox(height: 10,),
              Text("ENGLISH TEXT SIZE", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),),
              const SizedBox(height: 10,),
              Expanded(
                child: CircularSeekBar(
                  width: double.infinity,
                  height: 250,
                  trackColor: AppColors.primaryColor.withOpacity(0.2),
                  progress: progress,
                  barWidth: 8,
                  minProgress: minTextSize.toDouble(),
                  maxProgress: maxTextSize.toDouble(),
                  startAngle: 90,
                  sweepAngle: 180,
                  strokeCap: StrokeCap.round,
                  progressGradientColors: const [AppColors.primaryColor, AppColors.accentColor, Colors.purple],
                  dashWidth: 50,
                  dashGap: 15,
                  valueNotifier: progressChange,
                  animation: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.englishTextSize!.toString(), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),),
                        Text(getVerse(1, 1), style:Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700], fontSize: (state.englishTextSize??minTextSize).toDouble()),),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      }
    );
  }
}
