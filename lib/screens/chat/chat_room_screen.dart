import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'image_view_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final primaryColor = const Color(0xFFE0DBEF);
  final secondaryColor = const Color(0xFFFDFD96);

  UserModel? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    if (_currentUser != null) {
      _chatService.markAsRead(widget.chatId, _currentUser!.id);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currentUser != null) {
      _chatService.getChatMessages(widget.chatId).listen((_) {
        if (mounted) {
          _chatService.markAsRead(widget.chatId, _currentUser!.id);
        }
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    setState(() => _currentUser = user);
    if (user != null) {
      _chatService.markAsRead(widget.chatId, user.id);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await _chatService.sendMessage(
        widget.chatId,
        _currentUser!.id,
        _messageController.text.trim(),
      );
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메시지 전송 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('채팅방 나가기'),
          content: const Text('채팅 내용이 모두 삭제됩니다.\n계속하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('나가기'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await _chatService.markChatAsDeleted(widget.chatId, _currentUser!.id);
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('채팅방 나가기', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null && _currentUser != null) {
        setState(() => _isLoading = true);

        await _chatService.sendImageMessage(
          widget.chatId,
          _currentUser!.id,
          File(pickedFile.path),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 전송 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    if (_currentUser != null) {
      _chatService.markAsRead(widget.chatId, _currentUser!.id);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).primaryColor,
              backgroundImage: widget.otherUser.imageUrl.isNotEmpty
                  ? NetworkImage(widget.otherUser.imageUrl)
                  : null,
              child: widget.otherUser.imageUrl.isEmpty
                  ? Text(
                      widget.otherUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  widget.otherUser.mbti,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('오류가 발생했습니다: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == _currentUser?.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: message['type'] == 'system'
                          ? Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  message['message'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          : message['type'] == 'image'
                              ? Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: isMe
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      children: [
                                        if (!isMe) ...[
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: primaryColor,
                                            backgroundImage: widget.otherUser
                                                    .imageUrl.isNotEmpty
                                                ? NetworkImage(
                                                    widget.otherUser.imageUrl)
                                                : null,
                                            child: widget
                                                    .otherUser.imageUrl.isEmpty
                                                ? Text(
                                                    widget.otherUser.name[0]
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7,
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ImageViewScreen(
                                                      imageUrl:
                                                          message['message'],
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Image.network(
                                                message['message'],
                                                fit: BoxFit.cover,
                                                loadingBuilder:
                                                    (context, child, progress) {
                                                  if (progress == null)
                                                    return child;
                                                  return Container(
                                                    width: 200,
                                                    height: 200,
                                                    color: Colors.grey[200],
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        value: progress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? progress
                                                                    .cumulativeBytesLoaded /
                                                                progress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _formatTime(message['timestamp']),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: isMe
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      children: [
                                        if (!isMe) ...[
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: primaryColor,
                                            backgroundImage: widget.otherUser
                                                    .imageUrl.isNotEmpty
                                                ? NetworkImage(
                                                    widget.otherUser.imageUrl)
                                                : null,
                                            child: widget
                                                    .otherUser.imageUrl.isEmpty
                                                ? Text(
                                                    widget.otherUser.name[0]
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? primaryColor
                                                : Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            message['message'],
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.black
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _formatTime(message['timestamp']),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _pickAndSendImage,
                  icon: const Icon(Icons.image),
                  color: Colors.grey[600],
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
