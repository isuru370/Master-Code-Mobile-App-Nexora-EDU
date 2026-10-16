import 'package:flutter/material.dart';

/// Global keys so code outside the widget tree (e.g. the HTTP client)
/// can navigate or show a SnackBar.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showMessage(String message) {
    messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
