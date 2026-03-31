import 'package:dropdown_textfield/dropdown_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:tahfeex/resources/resources.dart';

class AppTextField extends StatelessWidget {
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final double? widthPercentage;
  final double? width;
  final String? hintText;
  final String? labelText;
  final IconData? icon;
  final Widget? suffixIcon;
  final bool? hidePassword;
  final bool? enabled, autoFocus;
  final Color? itemsColor;
  final int? minLines, maxLines;
  final TextEditingController? controller;
  final Function()? onTap;
  final Function()? onEditingComplete;
  final Function(String)? onChange;

  const AppTextField(
      {super.key,
      this.keyboardType,
      this.validator,
      this.widthPercentage,
      this.width,
      this.hintText,
      this.labelText,
      this.icon,
      this.suffixIcon,
      this.hidePassword,
      this.enabled,
      this.autoFocus,
      this.itemsColor,
      this.minLines,
      this.maxLines,
      this.controller,
      this.onEditingComplete,
      this.onChange,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width ??
            ((widthPercentage ?? 100) / 100) *
                MediaQuery.of(context).size.width,
        child: TextFormField(
          obscureText: hidePassword ?? false,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines ?? 1,
          onTap: onTap,
          onChanged: onChange,
          validator: validator ??
              (value) {
                return null;
              },
          keyboardType: keyboardType,
          onEditingComplete: onEditingComplete,
          autofocus: autoFocus ?? false,
          style: Theme.of(context).textTheme.bodyMedium,
          controller: controller,
          decoration: InputDecoration(
            alignLabelWithHint: true,
            isDense: true,
            suffixIcon: suffixIcon ??
                (icon == null
                    ? null
                    : Icon(
                        icon,
                        size: 15,
                        color: itemsColor,
                      )),
            hintText: hintText,
            labelText: labelText,
            fillColor: Theme.of(context).highlightColor.withAlpha(30),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Colors.grey[100]!, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Colors.grey[100]!, width: 1.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Colors.red[100]!, width: 1.0),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.0),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ));
  }
}

class AppTextDropdown extends StatelessWidget {
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final double? widthPercentage;
  final double? width;
  final String? hintText;
  final String? labelText;
  final IconData? icon;
  final Widget? suffixIcon;
  final bool? hidePassword;
  final List<String> list;
  final void Function(dynamic)? onChanged;
  final bool? enableSearch, isEnabled;
  final dynamic initialValue;

  const AppTextDropdown(
      {super.key,
      this.keyboardType,
      this.validator,
      this.widthPercentage,
      this.width,
      this.hintText,
      this.labelText,
      this.icon,
      this.suffixIcon,
      this.hidePassword,
      required this.list,
      this.onChanged,
      this.enableSearch,
      this.initialValue,
      this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width ??
            ((widthPercentage ?? 100) / 100) *
                MediaQuery.of(context).size.width,
        child: DropDownTextField(
          validator: validator ??
              (value) {
                return null;
              },
          keyboardType: keyboardType,
          // style: Theme.of(context).textTheme.labelLarge,
          searchDecoration: InputDecoration(hintText: hintText),
          onChanged: onChanged,
          isEnabled: isEnabled ?? true,
          enableSearch: enableSearch ?? true,
          initialValue: initialValue,
          textFieldDecoration: InputDecoration(
            isDense: true,
            suffixIcon:
                suffixIcon ?? (icon == null ? null : Icon(icon, size: 15)),
            hintText: hintText,
            labelText: labelText,
            fillColor: Colors.grey[100],
            filled: true,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Colors.grey[100]!, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Colors.grey[100]!, width: 1.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Colors.red[100]!, width: 1.0),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.0),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          dropDownList: List.generate(
              list.length,
              (index) =>
                  DropDownValueModel(name: list[index], value: list[index])),
        ));
  }
}

class AppSearchField extends StatelessWidget {
  AppSearchField({
    required this.loader,
    required this.itemBuilder,
    this.keyboardType,
    this.validator,
    this.widthPercentage,
    this.width,
    this.hintText,
    this.labelText,
    this.icon,
    this.suffixIcon,
    this.hidePassword,
    this.enabled,
    this.autoFocus,
    this.itemsColor,
    this.minLines,
    this.maxLines,
    this.controller,
    this.onEditingComplete,
    this.onSuggestionSelected,
    this.fillColor,
    this.onChange,
    this.onTap,
    this.suggestionsController, // New optional controller
    this.hideOnEmpty, // New parameter
    this.hideOnLoading, // New parameter
    this.hideOnError, // New parameter
  });

  final Future<List<dynamic>> Function(String) loader;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final double? widthPercentage;
  final double? width;
  final String? hintText;
  final String? labelText;
  final IconData? icon;
  final Widget? suffixIcon;
  final bool? hidePassword;
  final bool? enabled;
  final bool? autoFocus;
  final Color? itemsColor;
  final Color? fillColor;
  final int? minLines;
  final int? maxLines;
  final TextEditingController? controller;
  final Function()? onTap;
  final Function()? onEditingComplete;
  final dynamic Function(dynamic)? onSuggestionSelected;
  final Function(String)? onChange;
  final Widget Function(BuildContext, dynamic) itemBuilder;

  // New parameters for version 5.x
  final SuggestionsController? suggestionsController;
  final bool? hideOnEmpty;
  final bool? hideOnLoading;
  final bool? hideOnError;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ??
          ((widthPercentage ?? 100) / 100) * MediaQuery.of(context).size.width,
      child: TypeAheadField(
        // 1. Use the new 'builder' property instead of 'textFieldConfiguration'
        builder: (context, controller, focusNode) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            style: DefaultTextStyle.of(context)
                .style
                .copyWith(fontStyle: FontStyle.italic),
            decoration: InputDecoration(
              alignLabelWithHint: true,
              isDense: true,
              suffixIcon: suffixIcon ??
                  (icon == null
                      ? null
                      : Icon(
                          icon,
                          size: 15,
                          color: itemsColor,
                        )),
              hintText: hintText,
              labelText: labelText,
              fillColor:
                  fillColor ?? Theme.of(context).highlightColor.withAlpha(30),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Colors.grey[100]!, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Colors.grey[100]!, width: 1.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Colors.red[100]!, width: 1.0),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.primaryColor, width: 1.0),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onTap: onTap,
            onChanged: onChange,
            onEditingComplete: onEditingComplete,
            keyboardType: keyboardType,
            minLines: minLines,
            maxLines: maxLines,
            obscureText: hidePassword ?? false,
            enabled: enabled ?? true,
            autofocus: autoFocus ?? false,
          );
        },
        suggestionsCallback: (pattern) async {
          return await loader(pattern);
        },
        itemBuilder: itemBuilder,
        // 2. Parameter renamed from 'onSuggestionSelected' to 'onSelected'
        onSelected: onSuggestionSelected ?? (s) {},
        // 3. Pass the controller, focus node, and other parameters to TypeAheadField
        controller: controller,
        suggestionsController: suggestionsController,
        hideOnEmpty: hideOnEmpty,
        hideOnLoading: hideOnLoading,
        hideOnError: hideOnError,
        hideOnSelect: true, // Hides suggestions when one is selected
      ),
    );
  }
}
