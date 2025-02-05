import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'nearby_users_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../widgets/hobby_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../services/matching_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _auth = FirebaseAuth.instance;
  final _matchingService = MatchingService();
  int _currentIndex = 0;
  UserModel? _currentUser;
  int _unreadCount = 0;
  final primaryColor = const Color(0xFFE0DBEF);
  Timer? _matchingTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToUnreadMessages();
    _startPeriodicMatching();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() => _currentUser = user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _listenToUnreadMessages() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> unreadBy = data['unreadBy'] ?? [];
        if (unreadBy.contains(userId)) {
          totalUnread += (data['unreadCount'] as num?)?.toInt() ?? 0;
        }
      }
      if (mounted) {
        setState(() => _unreadCount = totalUnread);
      }
    });
  }

  void _startPeriodicMatching() {
    // 3시간마다 주변 사용자 검색
    _matchingTimer = Timer.periodic(const Duration(hours: 3), (_) async {
      if (_currentUser != null) {
        await _matchingService.checkMatches(
          _currentUser!.id,
          _currentUser!,
        );
      }
    });
  }

  @override
  void dispose() {
    _matchingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const NearbyUsersScreen(),
      const ChatListScreen(),
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo.png',
          height: 30,
        ),
        actions: [
          if (_currentIndex == 2)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              color: Colors.black,
              onPressed: _showLogoutDialog,
            ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            activeIcon: Icon(Icons.location_on),
            label: '주변',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(Icons.chat_bubble_outline),
                if (_unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: Stack(
              children: [
                Icon(Icons.chat_bubble),
                if (_unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: '채팅',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: '프로필',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 이미지와 기본 정보
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).primaryColor,
                    backgroundImage: _currentUser?.imageUrl != null &&
                            _currentUser!.imageUrl.isNotEmpty
                        ? NetworkImage(_currentUser!.imageUrl)
                        : null,
                    child: _currentUser?.imageUrl == null ||
                            _currentUser!.imageUrl.isEmpty
                        ? Text(
                            _currentUser?.name[0].toUpperCase() ?? '?',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.name ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentUser?.mbti ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 선호하는 MBTI
              Text(
                '선호하는 MBTI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _currentUser!.preferredMbti
                    .map((mbti) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Theme.of(context).primaryColor),
                          ),
                          child: Text(
                            mbti,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),

              // 취미
              Text(
                '취미',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _currentUser!.hobbies
                    .map((hobby) => HobbyItem(
                          hobby: hobby,
                          isSelected: true,
                          onTap: () {},
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),

              // 프로필 수정 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/profile-edit',
                      arguments: _currentUser,
                    );
                    if (result == true && mounted) {
                      _loadUserData();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('프로필 수정',
                      style: TextStyle(
                        color: Colors.black
                      ),),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
