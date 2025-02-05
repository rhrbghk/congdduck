import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/nearby_users_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../models/user_model.dart';
import '../../widgets/hobby_item.dart';
import '../../services/ad_service.dart';

class NearbyUsersScreen extends StatefulWidget {
  const NearbyUsersScreen({super.key});

  @override
  State<NearbyUsersScreen> createState() => _NearbyUsersScreenState();
}

class _NearbyUsersScreenState extends State<NearbyUsersScreen> {
  final _nearbyUsersService = NearbyUsersService();
  final _authService = AuthService();
  final _chatService = ChatService();
  final _adService = AdService();

  UserModel? _currentUser;
  List<UserModel> _nearbyUsers = [];
  bool _isLoading = true;
  Timer? _loadingTimer;
  StreamSubscription? _nearbyUsersSubscription;
  bool _hasInitialData = false;
  DateTime? _lastSearchTime;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();

    // Load ads for all platforms
    _loadInitialAd();
  }

  void _loadInitialAd() {
    // Initial ad load
    _adService.loadRewardedAd();

    // Set up periodic ad loading
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _adService.loadRewardedAd();
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        _startLocationAndSearch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _startLocationAndSearch() async {
    try {
      await _nearbyUsersService.startLocationUpdates(_currentUser!.id);
      // 화면 진입 시 한 번만 검색 수행
      _searchNearbyUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _searchNearbyUsers() async {
    if (!mounted || _currentUser == null) return;

    try {
      setState(() => _isLoading = true);

      final users = await _nearbyUsersService.findNearbyUsers(
        _currentUser!.id,
        _currentUser!.preferredMbti,
        _currentUser!.hobbies,
      );

      if (mounted) {
        setState(() {
          _nearbyUsers = users;
          _isLoading = false;
          _hasInitialData = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '주변의 친구를 찾고 있어요...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_nearbyUsers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _searchNearbyUsers,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 64,
                      color: Color(0xFFE0DBEF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '아직 근처에 맞는 친구가 없어요',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFE0DBEF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _searchNearbyUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _nearbyUsers.length,
        itemBuilder: (context, index) {
          final user = _nearbyUsers[index];
          final commonHobbies = _getCommonHobbies(user);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).primaryColor,
                        backgroundImage:
                            user.imageUrl != null && user.imageUrl!.isNotEmpty
                                ? NetworkImage(user.imageUrl!)
                                : null,
                        child: user.imageUrl == null || user.imageUrl!.isEmpty
                            ? Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
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
                              user.name,
                              style: const TextStyle(
                                fontSize: 18,
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
                                user.mbti,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (commonHobbies.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '공통 취미 ${commonHobbies.length}개',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: commonHobbies
                          .map((hobby) => HobbyItem(
                                hobby: hobby,
                                isSelected: true,
                                onTap: () {},
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _startChat(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '채팅하기',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<String> _getCommonHobbies(UserModel otherUser) {
    return _currentUser!.hobbies
        .where((hobby) => otherUser.hobbies.contains(hobby))
        .toList();
  }

  Future<void> _startChat(UserModel otherUser) async {
    try {
      final bool isRewarded = await _adService.showRewardedAd();
      if (!isRewarded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('채팅을 시작하려면 광고를 시청해주세요.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final chatId =
          await _chatService.createChatRoom(_currentUser!.id, otherUser.id);
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat-room',
          arguments: {
            'chatId': chatId,
            'otherUser': otherUser,
          },
        );
      }
    } catch (e) {
      print('채팅방 생성 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('채팅방을 생성할 수 없습니다. 잠시 후 다시 시도해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _refreshNearbyUsers() async {
    try {
      setState(() => _isLoading = true);

      final users = await _nearbyUsersService.findNearbyUsers(
        _currentUser!.id,
        _currentUser!.preferredMbti,
        _currentUser!.hobbies,
      );

      if (mounted) {
        setState(() {
          _nearbyUsers = users;
          _isLoading = false;
          _lastSearchTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  String _getTimeUntilNextSearch() {
    final timeSinceLastSearch = DateTime.now().difference(_lastSearchTime!);
    final timeUntilNext = const Duration(hours: 3) - timeSinceLastSearch;
    final hours = timeUntilNext.inHours;
    final minutes = (timeUntilNext.inMinutes % 60);
    return '${hours}시간 ${minutes}분';
  }

  @override
  void dispose() {
    _nearbyUsersService.stopLocationUpdates();
    _adService.dispose();
    super.dispose();
  }
}
