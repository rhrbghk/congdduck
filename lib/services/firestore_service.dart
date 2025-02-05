import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 사용자 관련 메서드
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 채팅방 관련 메서드
  Future<String> createChat(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    // 이미 존재하는 채팅방 확인
    final existingChat = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (var doc in existingChat.docs) {
      final chat = ChatModel.fromFirestore(doc);
      if (chat.participants.contains(otherUserId)) {
        return chat.id;
      }
    }

    // 새 채팅방 생성
    final chatRef = await _firestore.collection('chats').add({
      'participants': [currentUser.uid, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageTime': null,
      'lastMessage': null,
      'lastRead': {
        currentUser.uid: FieldValue.serverTimestamp(),
        otherUserId: FieldValue.serverTimestamp(),
      },
    });

    return chatRef.id;
  }

  // 채팅 목록 가져오기
  Stream<List<ChatModel>> getChatList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList());
  }

  // 메시지 관련 메서드
  Future<void> sendMessage(String chatId, String content, {MessageType type = MessageType.text}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    final messageRef = _firestore.collection('chats').doc(chatId).collection('messages');
    final chatRef = _firestore.collection('chats').doc(chatId);

    await _firestore.runTransaction((transaction) async {
      // 메시지 추가
      final newMessage = messageRef.doc();
      transaction.set(newMessage, {
        'senderId': currentUser.uid,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type.name,
        'isRead': false,
      });

      // 채팅방 정보 업데이트
      transaction.update(chatRef, {
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    });
  }

  // 메시지 목록 스트림
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50) // 최근 50개 메시지만
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  // 메시지 읽음 처리
  Future<void> markMessagesAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    final chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.update({
      'lastRead.${currentUser.uid}': FieldValue.serverTimestamp(),
    });

    // 읽지 않은 메시지 모두 읽음 처리
    final unreadMessages = await chatRef
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // 채팅방 삭제
  Future<void> deleteChat(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('로그인이 필요합니다.');

    // 메시지 먼저 삭제
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // 채팅방 삭제
    batch.delete(_firestore.collection('chats').doc(chatId));
    await batch.commit();
  }
}