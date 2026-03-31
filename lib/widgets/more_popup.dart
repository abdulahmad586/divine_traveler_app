import 'package:flutter/material.dart';
import 'package:tahfeex/widgets/widgets.dart';

class MorePopup extends StatelessWidget {
  MorePopup({
    Key? key,
    this.options = const [],
    required this.onAction,
    this.iconBackground = Colors.white,
    this.shape = BoxShape.rectangle,
    this.iconSize = 17,
  }) : super(key: key);
  List<String> options;
  Function(int) onAction;
  Color iconBackground;
  BoxShape shape;
  double iconSize;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      child: AppIconButton(
        icon: Icons.more_horiz,
        iconColor: Theme.of(context).iconTheme.color,
        iconSize: iconSize,
      ),

      itemBuilder: (BuildContext context) {
        return List.generate(
          options.length,
          (index) => PopupMenuItem<String>(
            value: '$index',
            child: Text(
              options[index],
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      },
      onSelected: (String string) {
        onAction(int.parse(string));
      },
    );
  }
}
