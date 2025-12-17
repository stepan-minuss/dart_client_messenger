class OpenChatTracker {
  static final Set<int> _openChatUserIds = {};
  
  static void registerOpenChat(int userId) {
    _openChatUserIds.add(userId);
    print('Чат с пользователем $userId открыт');
  }
  
  static void unregisterOpenChat(int userId) {
    _openChatUserIds.remove(userId);
    print('Чат с пользователем $userId закрыт');
  }
  
  static bool isChatOpen(int userId) {
    return _openChatUserIds.contains(userId);
  }
  
  static Set<int> getOpenChats() {
    return Set.from(_openChatUserIds);
  }
  
  static void clearAll() {
    _openChatUserIds.clear();
  }
}

