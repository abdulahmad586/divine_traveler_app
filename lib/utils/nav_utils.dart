import 'package:flutter/material.dart';
import 'package:tahfeex/widgets/app_route.dart';

class NavUtils {
  static void navTo(BuildContext context, Widget dest, {Function(dynamic)? onReturn}) {
    Navigator.push(
      context,
      AppRoute(builder: (context) => dest),
    ).then((value) {
      if(onReturn != null){
        onReturn(value);
      }
    });
  }

  static void navToReplace(BuildContext context, Widget dest, {Function(dynamic)? onReturn}) {
    Navigator.pushReplacement(
      context,
      AppRoute(builder: (context) => dest),
    ).then((value) {
      if(onReturn != null){
        onReturn(value);
      }
    });
  }
}
