// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 위치 권한 확인
  Future<bool> checkLocationPermission() async {
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

    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
    }

    return true;
  }

  // 현재 위치 가져오기
  Future<Position> getCurrentLocation() async {
    await checkLocationPermission();
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // 위치 업데이트 스트림 가져오기
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10미터마다 업데이트
      ),
    );
  }

  // Firestore에 위치 업데이트
  Future<void> updateUserLocation(String userId) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      await _firestore.collection('users').doc(userId).update({
        'location': GeoPoint(position.latitude, position.longitude),
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  double calculateDistance(GeoPoint point1, GeoPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
}
