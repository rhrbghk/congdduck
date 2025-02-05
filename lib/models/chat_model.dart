import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final DateTime createdAt;
  final DateTime? lastMessageTime;
  final String? lastMessage;
  final Map<String, DateTime> lastRead;
  final List<String>? deletedBy;
  final List<String>? unreadBy;
  final int? unreadCount;

  ChatModel({
    required this.id,
    required this.participants,
    required this.createdAt,
    this.lastMessageTime,
    this.lastMessage,
    required this.lastRead,
    this.deletedBy,
    this.unreadBy,
    this.unreadCount,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // 마지막 읽은 시간 변환
    Map<String, DateTime> lastReadMap = {};
    if (data['lastRead'] != null) {
      (data['lastRead'] as Map<String, dynamic>).forEach((key, value) {
        if (value is Timestamp) {
          lastReadMap[key] = value.toDate();
        }
      });
    }

    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessage: data['lastMessage'],
      lastRead: lastReadMap,
      deletedBy: data['deletedBy'] != null
          ? List<String>.from(data['deletedBy'])
          : null,
      unreadBy:
          data['unreadBy'] != null ? List<String>.from(data['unreadBy']) : null,
      unreadCount: data['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    // lastRead Map을 Timestamp로 변환
    Map<String, Timestamp> lastReadTimestamps = {};
    lastRead.forEach((key, value) {
      lastReadTimestamps[key] = Timestamp.fromDate(value);
    });

    return {
      'participants': participants,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageTime':
          lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessage': lastMessage,
      'lastRead': lastReadTimestamps,
      'deletedBy': deletedBy,
      'unreadBy': unreadBy,
      'unreadCount': unreadCount,
    };
  }
}
