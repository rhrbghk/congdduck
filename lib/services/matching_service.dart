import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/nearby_users_service.dart';

class MatchingService {
  final _firestore = FirebaseFirestore.instance;
  final _nearbyUsersService = NearbyUsersService();

  Future<bool> findAndNotifyMatches(UserModel currentUser) async {
    try {
      // 마지막 검색 시간 확인
      final userDoc =
          await _firestore.collection('users').doc(currentUser.id).get();
      final lastSearchTime = userDoc.data()?['lastSearchTime'] as Timestamp?;

      if (lastSearchTime != null) {
        final timeDiff = DateTime.now().difference(lastSearchTime.toDate());
        if (timeDiff.inHours < 3) {
          return false;
        }
      }

      // 근처 사용자 검색
      final nearbyUsers = await _nearbyUsersService.findNearbyUsers(
        currentUser.id,
        currentUser.preferredMbti,
        currentUser.hobbies,
      );

      if (nearbyUsers.isNotEmpty) {
        // 검색 시간 업데이트
        await _firestore.collection('users').doc(currentUser.id).update({
          'lastSearchTime': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error in findAndNotifyMatches: $e');
      return false;
    }
  }

  Future<void> checkMatches(String userId, UserModel currentUser) async {
    if (currentUser.location == null) return;

    final nearbyUsers = await _firestore
        .collection('users')
        .where('gender', isNotEqualTo: currentUser.gender)
        .get()
        .then((snapshot) async {
      final users = <DocumentSnapshot>[];
      for (var doc in snapshot.docs) {
        final otherLocation = doc.data()?['location'] as GeoPoint?;
        if (otherLocation != null) {
          final distance = await LocationService().calculateDistance(
            currentUser.location!,
            otherLocation,
          );
          if (distance <= 10000) {
            users.add(doc);
          }
        }
      }
      return users;
    });

    for (var doc in nearbyUsers) {
      final otherUser = UserModel.fromFirestore(doc);
      if (_isMatch(currentUser, otherUser)) {}
    }
  }

  bool _isMatch(UserModel user1, UserModel user2) {
    // MBTI 매칭 확인
    final mbtiMatch = user1.preferredMbti.contains(user2.mbti) &&
        user2.preferredMbti.contains(user1.mbti);

    // 공통 취미 확인 (최소 1개 이상)
    final commonHobbies =
        user1.hobbies.where((hobby) => user2.hobbies.contains(hobby)).toList();
    final hasCommonHobbies = commonHobbies.isNotEmpty;

    return mbtiMatch && hasCommonHobbies;
  }
}
