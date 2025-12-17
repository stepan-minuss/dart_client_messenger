import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/app_theme.dart';
import '../screens/image_viewer_screen.dart';
import '../utils/image_cache_config.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool isRead;
  final AppTheme theme;
  final DateTime timestamp;
  final String messageType;
  final String? mediaUrl;
  final int index; 
  final VoidCallback? onReply; 
  final VoidCallback? onDelete; 
  final String? replyToText; 
  final String? replyToSenderName; 
  final double cornerRadius; 
  final double messageOpacity; 
  final double messageBlur; 

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.isRead,
    required this.theme,
    required this.timestamp,
    this.messageType = 'text',
    this.mediaUrl,
    this.index = 0,
    this.onReply,
    this.onDelete,
    this.replyToText,
    this.replyToSenderName,
    this.cornerRadius = 18.0,
    this.messageOpacity = 0.6,
    this.messageBlur = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    final animatedWidget = Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: theme.bubbleColorOther,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (messageType == 'text')
                      ListTile(
                        leading: Icon(Icons.copy, color: theme.primaryColor),
                        title: Text('Копировать', style: TextStyle(color: theme.textColor)),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: text));
                          Navigator.pop(context);
                        },
                      ),
                    ListTile(
                      leading: Icon(Icons.reply, color: theme.primaryColor),
                      title: Text('Ответить', style: TextStyle(color: theme.textColor)),
                      onTap: () {
                        Navigator.pop(context);
                        if (onReply != null) {
                          onReply!();
                        }
                      },
                    ),
                    if (isMe && onDelete != null)
                      ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Удалить', style: TextStyle(color: Colors.red)),
                        onTap: () async {
                          Navigator.pop(context);
                          await Future.delayed(const Duration(milliseconds: 150));
                          if (!context.mounted) return;
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: theme.bubbleColorOther,
                              title: Text(
                                'Удалить сообщение?',
                                style: TextStyle(color: theme.textColor),
                              ),
                              content: Text(
                                'Это действие нельзя отменить',
                                style: TextStyle(color: theme.secondaryTextColor),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(
                                    'Отмена',
                                    style: TextStyle(color: theme.secondaryTextColor),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Удалить'),
                                ),
                              ],
                            ),
                          );
                          if (shouldDelete == true && onDelete != null) {
                            onDelete!();
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          },
            child: Builder(
              builder: (context) {
                  final messageContainer = ClipRRect(
                    borderRadius: messageType == 'image' 
                        ? BorderRadius.zero
                        : BorderRadius.only(
                            topLeft: Radius.circular(cornerRadius),
                            topRight: Radius.circular(cornerRadius),
                            bottomLeft: isMe ? Radius.circular(cornerRadius) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : Radius.circular(cornerRadius),
                          ),
                    child: Container(
                      margin: EdgeInsets.zero,
                      padding: messageType == 'image' ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: messageType == 'image' 
                          ? null
                          : BoxDecoration(
                              color: isMe 
                                  ? theme.bubbleColorMe.withOpacity(messageOpacity)
                                  : theme.bubbleColorOther.withOpacity(messageOpacity),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(cornerRadius),
                                topRight: Radius.circular(cornerRadius),
                                bottomLeft: isMe ? Radius.circular(cornerRadius) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : Radius.circular(cornerRadius),
                              ),
                              boxShadow: const [],
                              border: null,
                            ),
                      constraints: BoxConstraints(
                        maxWidth: screenWidth * 0.65,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (replyToText != null && replyToSenderName != null)
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: screenWidth * 0.6, 
                              ),
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isMe 
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border(
                                  left: BorderSide(
                                    color: isMe 
                                        ? Colors.white.withOpacity(0.4)
                                        : theme.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.reply,
                                    color: isMe 
                                        ? Colors.white.withOpacity(0.8)
                                        : theme.primaryColor,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'В ответ $replyToSenderName:',
                                          style: TextStyle(
                                            color: isMe 
                                                ? Colors.white.withOpacity(0.85)
                                                : theme.textColor.withOpacity(0.9),
                                            fontSize: 10,
                                            height: 1.1,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          replyToText!,
                                          style: TextStyle(
                                            color: isMe 
                                                ? Colors.white.withOpacity(0.7)
                                                : theme.textColor.withOpacity(0.7),
                                            fontSize: 10,
                                            height: 1.1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (messageType == 'image' && mediaUrl != null)
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ImageViewerScreen(imageUrl: mediaUrl!),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isMe 
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.5),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Stack(
                                    children: [
                                      ImageCacheConfig.messageMediaImage(
                                        imageUrl: mediaUrl!,
                                        width: screenWidth * 0.5,
                                        height: screenWidth * 0.5,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: screenWidth * 0.5,
                                          height: screenWidth * 0.5,
                                          color: Colors.grey.withOpacity(0.3),
                                          child: const Center(child: CircularProgressIndicator()),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          width: screenWidth * 0.5,
                                          height: screenWidth * 0.5,
                                          color: Colors.grey.withOpacity(0.3),
                                          child: const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.error, color: Colors.red),
                                              SizedBox(height: 8),
                                              Text('Ошибка загрузки', style: TextStyle(color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.fullscreen,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: messageType == 'image' 
                                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                                : EdgeInsets.zero,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('HH:mm').format(timestamp.toLocal()),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 10,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    isRead ? Icons.done_all : Icons.done,
                                    size: 12,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
                  return messageContainer;
                },
              ),
            ),
      ],
    );
    return animatedWidget;
  }
}
