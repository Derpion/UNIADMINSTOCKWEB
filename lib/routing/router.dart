import 'package:flutter/material.dart';
import 'package:unistock/pages/SettingsPage.dart';
import 'package:unistock/pages/authentication/authentication.dart';
import 'package:unistock/pages/inventory_stocks/inventory_stocks.dart';
import 'package:unistock/pages/overview/overview.dart';
import 'package:unistock/pages/reservation_list/reservation_list.dart';
import 'package:unistock/pages/pre_order/pre_order.dart';
import 'package:unistock/pages/sales_history/sales_history.dart';
import 'package:unistock/pages/sales_statistics/sales_statistics.dart';
import 'package:unistock/pages/release/ReleasePage.dart';
import 'package:unistock/pages/walk-in(preorder)/walk-in(preorder).dart';
import 'package:unistock/pages/walk-in/walk-in.dart';
import 'package:unistock/pages/NotificationPage.dart';
import 'package:unistock/routing/routes.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case OverviewPageRoute:
      return _getPageRoute(OverviewPage());
    case InventoryPageRoute:
      return _getPageRoute(InventoryPage());
    case ReservationListPageRoute:
      return _getPageRoute(ReservationListPage());
    case PreOrderPageRoute:
      return _getPageRoute(PreOrderPage());
    case SalesHistoryPageRoute:
      return _getPageRoute(SalesHistoryPage());
    case SalesStatisticsPageRoute:
      return _getPageRoute(SalesStatisticsPage());
    case WalkinPageRoute:
      return _getPageRoute(WalkinPage());
    case WalkinPagePreOrderRoute:
      return _getPageRoute(WalkinPagePreOrder());
    case SettingsPageRoute:
      return _getPageRoute(SettingsPage());
    case ReleasePageRoute:
      return _getPageRoute(ReleasePage());
    case AdminNotificationPageRoute:
      return _getPageRoute(AdminNotificationPage());
    default:
      return _getPageRoute(AuthenticationPage());
  }
}

PageRoute _getPageRoute(Widget child) {
  return MaterialPageRoute(builder: (context) => child);
}
