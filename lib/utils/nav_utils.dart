import 'package:flutter/material.dart';

class NavUtils {
  static void navTo(BuildContext context, Widget dest, {Function(dynamic)? onReturn}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => dest),
    ).then((value) {
      if(onReturn != null){
        onReturn(value);
      }
    });
  }

  static void navToReplace(BuildContext context, Widget dest, {Function(dynamic)? onReturn}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => dest),
    ).then((value) {
      if(onReturn != null){
        onReturn(value);
      }
    });
  }
}
