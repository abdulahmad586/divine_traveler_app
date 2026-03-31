import 'package:flutter/material.dart';

class AlertUtls{
  static void showModal(BuildContext context, Widget child) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15), topRight: Radius.circular(15))),
        builder: ((context) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: child,
          );
        }));
  }

  static void toast(BuildContext context, {String message = "", Color? color}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message),backgroundColor: color, dismissDirection: DismissDirection.startToEnd,));
  }
}