import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:tahfeex/resources/resources.dart';

class AppButton extends StatelessWidget {
  const AppButton({super.key,
    this.label,
    this.onTap,
    this.icon,
    this.iconSize,
    this.height,
    this.width,
    this.widthPercentage,
    this.iconColor,
    this.borderColor,
    this.backgroundColor,
    this.labelColor,
    this.loading,
    this.progressPercentage
  });

  final Function()? onTap;
  final IconData? icon;
  final double? iconSize, height, width, widthPercentage;
  final Color? iconColor, borderColor, backgroundColor, labelColor;
  final String? label;
  final bool? loading;
  final int? progressPercentage;

  @override
  Widget build(BuildContext context) {


    return Material(
        type: MaterialType
            .transparency, //Makes it usable on any background color, thanks @IanSmith
        child: Ink(
          width: width ??
            ((widthPercentage ?? 100) / 100) *
        MediaQuery.of(context).size.width,
          height: 50,
          decoration: BoxDecoration(
              border: Border.all(
                  color: borderColor ?? AppColors.primaryColor, width: 1.0),
              color: (loading ?? false) ? backgroundColor?.withOpacity(0.7) :backgroundColor,
              shape: BoxShape.rectangle,
              borderRadius: const BorderRadius.all(Radius.circular(10))),

          child: InkWell(
            //This keeps the splash effect within the circle
            borderRadius: BorderRadius.circular(400), //Something large to ensure a circle
            onTap: loading !=null && loading! ? null: onTap,
            child: Center(
              // padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  (loading??false) ? const SizedBox(
                    width: 50,
                    height: 30,
                    child: LoadingIndicator(
                        indicatorType: Indicator.ballScaleRippleMultiple,

                        colors: [
                          Color(0xff191a19),
                          AppColors.accentColor,
                          AppColors.primaryColor,
                          Color(0xffd8e9a8),
                        ],
                        strokeWidth: 2,
                        pathBackgroundColor: Colors.black),
                  ):Text(label??'', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: labelColor),),
                  progressPercentage == null ? const SizedBox(): Text(" ($progressPercentage%)", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: labelColor),),
                ],
              )
            ),
          ),
        ));
  }
}
