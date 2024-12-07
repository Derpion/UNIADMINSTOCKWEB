import 'package:flutter/material.dart';
import 'package:unistock/helpers/responsiveness.dart';
import 'package:unistock/widgets/largeScreen.dart';
import 'package:unistock/widgets/side_menu.dart';
import 'package:unistock/widgets/smallScreen.dart';
import 'package:unistock/widgets/top_nav.dart';

class SiteLayout extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: topNavigation(context, scaffoldKey),
      drawer: const Drawer(
        child: SideMenu(),
      ),
      body: ResponsiveWidget(
        largeScreen: const Largescreen(),
        smallScreen: Smallscreen(),
      ),
    );
  }
}