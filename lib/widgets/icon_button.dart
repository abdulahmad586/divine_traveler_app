import 'package:flutter/material.dart';

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor, iconColor;
  final double? iconSize;

  const AppIconButton(
      {super.key,
      required this.icon,
      this.onPressed,
      this.backgroundColor,
      this.iconColor,
      this.iconSize});

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      onPressed: onPressed,
      fillColor: backgroundColor ?? Colors.white,
      shape: const CircleBorder(),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      child: Icon(
        icon,
        color: iconColor ?? Colors.black,
        size: iconSize,
      ),
    );
  }
}
