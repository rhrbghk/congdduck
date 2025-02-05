import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 채팅방 존재 여부 확인
  Future<bool> isChatExists(String currentUserId, String otherUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in querySnapshot.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        if (participants.contains(otherUserId)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking chat existence: $e');
      return false;
    }
  }

  // 채팅방 생성 또는 기존 채팅방 반환
  Future<String> createChatRoom(String user1Id, String user2Id) async {
    try {
      // 이미 존재하는 채팅방 확인
      final existingChat = await _firestore
          .collection('chats')
          .where('participants', arrayContainsAny: [user1Id]).get();

      for (var doc in existingChat.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants']);
        final deletedBy = List<String>.from(data['deletedBy'] ?? []);

        if (participants.contains(user2Id) && !deletedBy.contains(user1Id)) {
          // 이미 존재하는 채팅방이면 deletedBy에서 현재 사용자 제거
          await doc.reference.update({
            'deletedBy': FieldValue.arrayRemove([user1Id])
          });
          return doc.id;
        }
      }

      // 새 채팅방 생성
      final chatDoc = await _firestore.collection('chats').add({
        'participants': [user1Id, user2Id],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
        'lastRead': {
          user1Id: FieldValue.serverTimestamp(),
          user2Id: FieldValue.serverTimestamp(),
        },
        'deletedBy': [], // 채팅방 삭제 사용자 목록 초기화
      });

      return chatDoc.id;
    } catch (e) {
      print('Error creating chat room: $e');
      throw e;
    }
  }

  // 채팅방 목록 스트림 - 삭제되지 않은 채팅방만 표시
  Stream<QuerySnapshot> getChatList(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // 채팅 메시지 스트림
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // 메시지 전송
  Future<void> sendMessage(
      String chatId, String senderId, String message) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final chatRef = _firestore.collection('chats').doc(chatId);
        final chatDoc = await transaction.get(chatRef);

        if (!chatDoc.exists) {
          throw Exception('채팅방을 찾을 수 없습니다.');
        }

        final data = chatDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants']);
        final receiverId = participants.firstWhere((id) => id != senderId);

        // 채팅방 업데이트
        transaction.update(chatRef, {
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadBy': [receiverId],
          'unreadCount': (data['unreadCount'] ?? 0) + 1,
        });

        // 메시지 저장
        final messageRef = chatRef.collection('messages').doc();
        transaction.set(messageRef, {
          'senderId': senderId,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'text',
        });
      });
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  // 메시지 읽음 처리
  Future<void> markAsRead(String chatId, String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'unreadBy': FieldValue.arrayRemove([userId]),
        'unreadCount': 0, // 읽으면 카운트 초기화
        'lastRead.$userId': FieldValue.serverTimestamp(), // lastRead 시간 업데이트
      });
    } catch (e) {
      print('Error marking messages as read: $e');
      rethrow;
    }
  }

  // 채팅방 완전 삭제
  Future<void> deleteChat(String chatId) async {
    try {
      final batch = _firestore.batch();

      // 메시지 삭제
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // 채팅방 삭제
      batch.delete(_firestore.collection('chats').doc(chatId));

      await batch.commit();
    } catch (e) {
      print('Error deleting chat: $e');
      throw e;
    }
  }

  // 채팅방 나가기 (삭제 표시)
  Future<void> markChatAsDeleted(String chatId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final chatRef = _firestore.collection('chats').doc(chatId);
        final chatDoc = await transaction.get(chatRef);

        if (!chatDoc.exists) {
          // 이미 채팅방이 삭제된 경우 조용히 리턴
          return;
        }

        final data = chatDoc.data() as Map<String, dynamic>;
        final deletedBy = List<String>.from(data['deletedBy'] ?? []);
        final participants = List<String>.from(data['participants']);

        // 상대방 ID 찾기
        final otherId = participants.firstWhere((id) => id != userId);

        if (!deletedBy.contains(userId)) {
          deletedBy.add(userId);

          // 시스템 메시지 추가
          final messageRef = chatRef.collection('messages').doc();
          transaction.set(messageRef, {
            'message': '상대방이 채팅방을 나가셨습니다.',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'system',
            'senderId': 'system'
          });

          // 채팅방 마지막 메시지 업데이트
          transaction.update(chatRef, {
            'lastMessage': '상대방이 채팅방을 나가셨습니다.',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'unreadBy': [otherId],
            'unreadCount': (data['unreadCount'] ?? 0) + 1,
          });
        }

        if (deletedBy.length >= participants.length) {
          await deleteChat(chatId);
        } else {
          transaction.update(chatRef, {
            'deletedBy': deletedBy,
          });
        }
      });
    } catch (e) {
      print('Error marking chat as deleted: $e');
      // 에러가 발생해도 조용히 처리
      return;
    }
  }

  // 읽지 않은 메시지 수 가져오기
  Future<int> getUnreadMessageCount(String chatId, String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  Future<List<ChatModel>> getExistingChats(String userId) async {
    final snapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .get();

    return snapshot.docs
        .map((doc) => ChatModel.fromFirestore(doc))
        .where((chat) => !(chat.deletedBy?.contains(userId) ?? false))
        .toList();
  }

  Future<void> sendImageMessage(
    String chatId,
    String senderId,
    File imageFile,
  ) async {
    try {
      // 이미지를 Firebase Storage에 업로드
      final ref = _storage
          .ref()
          .child('chat_images')
          .child(chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      await _firestore.runTransaction((transaction) async {
        final chatRef = _firestore.collection('chats').doc(chatId);
        final chatDoc = await transaction.get(chatRef);

        if (!chatDoc.exists) {
          throw Exception('채팅방을 찾을 수 없습니다.');
        }

        final data = chatDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants']);
        final receiverId = participants.firstWhere((id) => id != senderId);

        // 채팅방 업데이트
        transaction.update(chatRef, {
          'lastMessage': '사진',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadBy': [receiverId],
          'unreadCount': (data['unreadCount'] ?? 0) + 1,
        });

        // 메시지 저장
        final messageRef = chatRef.collection('messages').doc();
        transaction.set(messageRef, {
          'senderId': senderId,
          'message': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'image',
        });
      });
    } catch (e) {
      print('Error sending image message: $e');
      throw e;
    }
  }

  Future<String> createChat(String userId1, String userId2) async {
    final chatDoc = await _firestore.collection('chats').add({
      'participants': [userId1, userId2],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageTime': null,
      'lastMessage': null,
      'deletedBy': [],
      'unreadBy': [],
      'unreadCount': 0,
    });
    return chatDoc.id;
  }
}
