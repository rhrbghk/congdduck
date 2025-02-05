import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  final primaryColor = const Color(0xFFE0DBEF);

  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getChatList(_currentUser!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // deletedBy 필터링 및 정렬
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final deletedBy = List<String>.from(data['deletedBy'] ?? []);
          return !deletedBy.contains(_currentUser!.id);
        }).toList()
          ..sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime']
                as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime']
                as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildChatItem(docs[index]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('아직 채팅이 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('근처 친구를 찾아 대화를 시작해보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildChatItem(DocumentSnapshot doc) {
    final chatData = doc.data() as Map<String, dynamic>;
    final otherUserId = (chatData['participants'] as List)
        .firstWhere((id) => id != _currentUser!.id);

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();

        final otherUser = UserModel.fromFirestore(userSnapshot.data!);
        return _buildChatListItem(doc, chatData, otherUser);
      },
    );
  }

  Widget _buildChatListItem(
    DocumentSnapshot doc,
    Map<String, dynamic> chatData,
    UserModel otherUser,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: primaryColor,
          backgroundImage: otherUser.imageUrl.isNotEmpty
              ? NetworkImage(otherUser.imageUrl)
              : null,
          child: otherUser.imageUrl.isEmpty
              ? Text(
                  otherUser.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Text(otherUser.name),
            const SizedBox(width: 8),
            Text(
              _formatTime(chatData['lastMessageTime']),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chatData['lastMessage'] ?? '새로운 채팅방',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (chatData['unreadBy']?.contains(_currentUser?.id) ?? false)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${chatData['unreadCount'] ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => Navigator.pushNamed(
          context,
          '/chat-room',
          arguments: {
            'chatId': doc.id,
            'otherUser': otherUser,
          },
        ),
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
      return '${date.month}/${date.day}';
    }
  }
}
