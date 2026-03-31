import 'package:flutter/material.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/widgets/widgets.dart';

class SuccessPage extends StatelessWidget{

  final Function(BuildContext) onProceed;
  final String message, title, buttonLabel;
  const SuccessPage({super.key, this.title="Success!", this.buttonLabel="Continue your journey", required this.message, required this.onProceed});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            const Expanded(child: SizedBox()),
            const Text("🎉", style: TextStyle(fontSize: 70),),
            // const Text("🎇", style: TextStyle(fontSize: 70),),
            const SizedBox(height: 40,),
            Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),),
            const SizedBox(height: 10,),
            Text(message, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).hintColor),),
            const Expanded(child: SizedBox()),
            AppButton(label: buttonLabel, labelColor: AppColors.primaryColor, onTap: (){
              onProceed(context);
            },),
          ],
        ),
      ),
    );
  }
}