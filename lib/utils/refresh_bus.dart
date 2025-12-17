import 'package:flutter/foundation.dart';

class RefreshBus {
  static final ValueNotifier<int> activeChatsVersion = ValueNotifier<int>(0);

  static void notifyActiveChats() {
    activeChatsVersion.value++;
  }
}

