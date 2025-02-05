import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 사용자의 Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 현재 로그인된 사용자 가져오기
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    }
    return null;
  }

  // 이메일/비밀번호로 회원가입
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Firestore에 사용자 정보 저장
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'id': userCredential.user!.uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileCompleted': false,
        'imageUrl': '',
        'gender': '',
        'mbti': '',
        'preferredMbti': [],
        'hobbies': [],
        'location': null,
        'lastLocationUpdate': null,
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // 이메일/비밀번호로 로그인
  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 프로필 업데이트
  Future<void> updateProfile({
    required String name,
    required String imageUrl,
    required String gender,
    required String mbti,
    required List<String> preferredMbti,
    required List<String> hobbies,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다');

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': name,
      'imageUrl': imageUrl,
      'gender': gender,
      'mbti': mbti,
      'preferredMbti': preferredMbti,
      'hobbies': hobbies,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 회원 탈퇴
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('사용자가 로그인되어 있지 않습니다.');

    // Firestore 데이터 삭제
    await _firestore.collection('users').doc(user.uid).delete();

    // Authentication 계정 삭제
    await user.delete();
  }

  // Firebase Auth 예외 처리
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return Exception('이미 사용 중인 이메일 주소입니다.');
      case 'invalid-email':
        return Exception('유효하지 않은 이메일 형식입니다.');
      case 'operation-not-allowed':
        return Exception('이메일/비밀번호 로그인이 비활성화되어 있습니다.');
      case 'weak-password':
        return Exception('비밀번호가 너무 약합니다.');
      case 'user-disabled':
        return Exception('해당 계정이 비활성화되었습니다.');
      case 'user-not-found':
        return Exception('등록되지 않은 이메일입니다.');
      case 'wrong-password':
        return Exception('잘못된 비밀번호입니다.');
      default:
        return Exception('인증 오류가 발생했습니다: ${e.message}');
    }
  }

  // 로그인 메서드
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return await getCurrentUser();
      }
      return null;
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }
}
