import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/user_model.dart';
import 'dart:async' show Stream, StreamSubscription, Timer, unawaited;
import '../services/chat_service.dart';

class NearbyUsersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  Timer? _locationUpdateTimer;
  StreamSubscription? _nearbyUsersSubscription;

  // 실시간 위치 업데이트 시작
  Future<void> startLocationUpdates(String userId) async {
    // 위치 권한 확인 후 즉시 첫 위치 업데이트를 수행하도록 수정
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }

    // 즉시 첫 위치 업데이트 수행
    final position = await Geolocator.getCurrentPosition();
    await _updateUserLocation(userId, position);

    // 이후 주기적 업데이트
    _locationUpdateTimer =
        Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition();
        await _updateUserLocation(userId, position);
      } catch (e) {
        print('Error updating location: $e');
      }
    });
  }

  // 위치 업데이트 중지
  void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _nearbyUsersSubscription?.cancel();
  }

  // Firestore에 위치 정보 업데이트
  Future<void> _updateUserLocation(String userId, Position position) async {
    await _firestore.collection('users').doc(userId).update({
      'location': GeoPoint(position.latitude, position.longitude),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  // 주변 사용자 찾기 및 알림 보내기
  Stream<List<UserModel>> watchNearbyUsers(
    String currentUserId,
    List<String> preferredMbti,
    List<String> hobbies,
  ) {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    )
        .throttleTime(
      // 업데이트 주기를 5초로 단축
      const Duration(seconds: 5),
    )
        .asyncMap((Position position) async {
      try {
        unawaited(_updateUserLocation(currentUserId, position));
        final nearbyUsers = await _findNearbyUsers(
          currentUserId,
          preferredMbti,
          hobbies,
          position,
        );
        return nearbyUsers;
      } catch (e) {
        print('Error in watchNearbyUsers: $e');
        return <UserModel>[];
      }
    }).distinct();
  }

  Future<List<UserModel>> _findNearbyUsers(
    String currentUserId,
    List<String> preferredMbti,
    List<String> hobbies,
    Position currentPosition,
  ) async {
    try {
      // 현재 사용자 정보 가져오기
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUser = UserModel.fromFirestore(currentUserDoc);

      // 최적화된 쿼리 - isNotEqualTo 필터 제거
      final snapshot = await _firestore
          .collection('users')
          .where('mbti', whereIn: preferredMbti)
          .get();

      print('검색된 총 사용자 수: ${snapshot.docs.length}');

      // 채팅방 존재 여부를 한 번에 확인
      final existingChats = await _chatService.getExistingChats(currentUserId);
      final existingChatUserIds = existingChats
          .map((chat) =>
              chat.participants.firstWhere((id) => id != currentUserId))
          .toSet();

      List<UserModel> nearbyUsers = [];

      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId) continue;

        final userData = UserModel.fromFirestore(doc);

        // 성별 필터링을 메모리에서 수행
        if (userData.gender == currentUser.gender) continue;

        if (userData.location == null) continue;

        if (existingChatUserIds.contains(doc.id)) {
          print('이미 채팅방이 존재하는 사용자: ${doc.id}');
          continue;
        }

        // MBTI 상호 매칭 확인
        if (!userData.preferredMbti.contains(currentUser.mbti)) continue;

        // 거리 계산
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          userData.location!.latitude,
          userData.location!.longitude,
        );

        if (distance <= 10000) {
          nearbyUsers.add(userData);
          print('근처 사용자로 추가됨: ${userData.name}');
        }
      }

      return nearbyUsers;
    } catch (e) {
      print('Error finding nearby users: $e');
      return [];
    }
  }

  Future<void> _sendMatchNotification({
    required String targetUserId,
    required String mbti,
    required int commonHobbiesCount,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': targetUserId,
      'type': 'match',
      'message': '취미가 ${commonHobbiesCount}개 일치하는 $mbti가 주변에 있습니다! 메시지를 보내보세요!',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 일회성 주변 사용자 검색
  Future<List<UserModel>> findNearbyUsers(
    String currentUserId,
    List<String> preferredMbti,
    List<String> hobbies,
  ) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      return _findNearbyUsers(
        currentUserId,
        preferredMbti,
        hobbies,
        position,
      );
    } catch (e) {
      print('Error finding nearby users: $e');
      return [];
    }
  }
}
