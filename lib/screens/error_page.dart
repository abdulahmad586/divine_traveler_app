import 'package:flutter/material.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/widgets/widgets.dart';

class ErrorPage extends StatelessWidget{

  final Function(BuildContext) onButtonPress;
  final String message, title, buttonLabel;
  final Widget? errorWidget;
  const ErrorPage({super.key, this.title="Oops!", this.errorWidget, this.buttonLabel="Close", required this.message, required this.onButtonPress});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            const Expanded(child: SizedBox()),
            errorWidget ?? const Text("⚠", style: TextStyle(fontSize: 70,color: Colors.red),),
            // const Text("🎇", style: TextStyle(fontSize: 70),),
            const SizedBox(height: 40,),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange),),
            const SizedBox(height: 10,),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).hintColor),),
            const Expanded(child: SizedBox()),
            AppButton(label: buttonLabel, labelColor: AppColors.primaryColor, onTap: (){
              onButtonPress(context);
            },),
          ],
        ),
      ),
    );
  }
}