import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unistock/constants/controllers.dart';
import 'package:unistock/constants/style.dart';
import 'package:unistock/helpers/responsiveness.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unistock/routing/routes.dart';
import 'package:unistock/widgets/custom_text.dart';

AppBar topNavigation(BuildContext context, GlobalKey<ScaffoldState> key) => AppBar(
  leading: !ResponsiveWidget.isSmallScreen(context)
      ? Row(
    children: [
      Container(
        padding: EdgeInsets.only(left: 14),
      )
    ],
  )
      : IconButton(
    icon: Icon(Icons.menu, color: Colors.white),
    onPressed: () {
      key.currentState?.openDrawer();
    },
  ),
  elevation: 0,
  title: Row(
    children: [
      RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
          children: <TextSpan>[
            TextSpan(text: 'UNI', style: TextStyle(color: Colors.white)),
            TextSpan(text: 'STOCK', style: TextStyle(color: Colors.yellow)),
          ],
        ),
      ),
      Expanded(child: Container()),
      IconButton(
        icon: Icon(
          Icons.settings,
          color: Colors.white.withOpacity(.9),
        ),
        onPressed: () {
          navigationController.navigateTo(SettingsPageRoute);
        },
      ),
      Stack(
        children: [
          IconButton(
            icon: Icon(
              Icons.notifications,
              color: Colors.white.withOpacity(.9),
            ),
            onPressed: () {
              navigationController.navigateTo(AdminNotificationPageRoute);
            },
          ),
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              height: 12,
              width: 12,
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: active,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: light, width: 2),
              ),
            ),
          )
        ],
      ),
      Container(
        width: 1,
        height: 22,
        color: light,
      ),
      SizedBox(
        width: 24,
      ),
      CustomText(
        text: "Hey, Admin!",
        color: Colors.white,
      ),
      SizedBox(
        width: 16,
      ),
    ],
  ),
  iconTheme: IconThemeData(color: dark),
  backgroundColor: active,
);
