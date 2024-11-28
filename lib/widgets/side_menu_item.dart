import 'package:flutter/material.dart';
import 'package:unistock/helpers/responsiveness.dart';
import 'package:unistock/widgets/horizontal_menu.dart';
import 'package:unistock/widgets/vertical_menu.dart';

class SideMenuItem extends StatelessWidget {
  final String itemName;
  final Function() onTap;
  const SideMenuItem({Key? key, required this.itemName, required this.onTap}) :super(key: key);

  @override
  Widget build(BuildContext context) {
    if(ResponsiveWidget.isCustomScreen(context))
    return VerticalMenu(itemName: itemName, onTap: onTap,);

    return HorizontalMenu(itemName: itemName, onTap: onTap);
  }
}