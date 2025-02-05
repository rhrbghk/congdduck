// lib/widgets/chat/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showTime;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showTime = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && showTime)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildTime(),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).primaryColor
                        : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: _buildMessageContent(context),
                ),
              ),
              if (isMe && showTime)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildTime(),
                ),
            ],
          ),
          if (message.type == MessageType.system)
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final messageTextStyle = TextStyle(
      color: isMe ? Colors.white : Colors.black,
      fontSize: 16,
    );

    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: messageTextStyle,
        );
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.content,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          ),
        );
      case MessageType.location:
        return Text(
          '📍 위치 공유',
          style: messageTextStyle,
        );
      case MessageType.system:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        );
    }
  }

  Widget _buildTime() {
    return Text(
      DateFormat('HH:mm').format(message.timestamp),
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
      ),
    );
  }
}

class MessageStatus extends StatelessWidget {
  final bool isRead;
  final DateTime? readTime;

  const MessageStatus({
    super.key,
    required this.isRead,
    this.readTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRead ? Icons.done_all : Icons.done,
          size: 16,
          color: isRead ? Colors.blue : Colors.grey,
        ),
        if (isRead && readTime != null) ...[
          const SizedBox(width: 4),
          Text(
            DateFormat('HH:mm').format(readTime!),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}