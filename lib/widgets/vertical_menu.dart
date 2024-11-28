import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unistock/constants/controllers.dart';
import 'package:unistock/constants/style.dart';
import 'package:unistock/widgets/custom_text.dart';

class VerticalMenu extends StatelessWidget {
  final String itemName;
  final Function() onTap;
  const VerticalMenu({Key? key, required this.itemName, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onHover: (value){
        value?
        menuController.onHover(itemName):
        menuController.onHover("Not Hovering");
      },
      child: Obx (() => Container(
        color: menuController.isHovering(itemName) ?
        lightGrey.withOpacity(.1) : Colors.transparent,

        child: Row(
          children: [
            Visibility(visible: menuController.isHovering(itemName) || menuController.isActive(itemName),
            child: Container(width: 3, height: 72, color: active,),
            maintainSize: true, maintainState: true, maintainAnimation: true,),

            Expanded(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(padding: EdgeInsets.all(16),
                child: menuController.returnIconfor(itemName),),

                if (!menuController.isActive(itemName))
                Flexible(child: CustomText(
                  text: itemName, 
                  color: menuController.isHovering(itemName) ? active: dark,
                ))

                else
                Flexible(child: CustomText(
                  text:itemName, 
                  color: active, 
                  size: 18, 
                  weight: FontWeight.bold,
                ))
              ],
            ))
          ],
        ),
      )),
    );
  }
}