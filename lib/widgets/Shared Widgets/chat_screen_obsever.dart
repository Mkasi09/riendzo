import 'package:flutter/material.dart';

class ChatScreenObserver extends NavigatorObserver {
  final Function(bool) onChatScreenPushed;

  ChatScreenObserver({required this.onChatScreenPushed});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == 'ChatScreen') {
      onChatScreenPushed(true);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route.settings.name == 'ChatScreen') {
      onChatScreenPushed(false);
    }
  }
}
