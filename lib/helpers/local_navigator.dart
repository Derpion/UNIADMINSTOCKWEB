import 'package:flutter/material.dart';
import 'package:unistock/constants/controllers.dart';
import 'package:unistock/routing/router.dart';
import 'package:unistock/routing/routes.dart';

Navigator localNavigator() => Navigator(
  key: navigationController.navigationKey,
  initialRoute: OverviewPageRoute,
  onGenerateRoute: generateRoute,
);