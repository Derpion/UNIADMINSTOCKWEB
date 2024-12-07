import 'package:flutter/material.dart';
import 'package:unistock/constants/style.dart';
import 'package:unistock/helpers/local_navigator.dart';
import 'package:unistock/widgets/side_menu.dart';

class Largescreen extends StatelessWidget {
  const Largescreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
        children: [
          Expanded(child: Container(
            color: light,
            child: SideMenu(),
          )),
          Expanded(
            flex: 4,
            child: localNavigator())
        ],
      );
  }
}