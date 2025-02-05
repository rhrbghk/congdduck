// lib/screens/auth/profile_edit_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/common/custom_button.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../widgets/hobby_item.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _authService = AuthService();
  final primaryColor = const Color(0xFFE0DBEF);
  String? selectedMbti;
  List<String> selectedPreferredMbti = [];
  List<String> hobbies = [];
  bool _isLoading = false;
  UserModel? _initialData;
  File? _imageFile;
  final _imagePicker = ImagePicker();
  String? selectedGender;

  final List<String> mbtiTypes = [
    'INTJ',
    'INTP',
    'ENTJ',
    'ENTP',
    'INFJ',
    'INFP',
    'ENFJ',
    'ENFP',
    'ISTJ',
    'ISFJ',
    'ESTJ',
    'ESFJ',
    'ISTP',
    'ISFP',
    'ESTP',
    'ESFP',
  ];

  final List<String> predefinedHobbies = [
    '영화 관람',
    '연극 및 뮤지컬 관람',
    '독서',
    '음악 감상',
    '그림 그리기',
    '악기 연주',
    '글쓰기',
    '맛집탐방',
    '술',
    '요리',
    '베이킹',
    '보드게임',
    '퍼즐',
    '사진 촬영',
    '뜨개질',
    '피규어/프라모델',
    '홈 가드닝',
    '게임',
    '등산',
    '헬스',
    '요가/필라테스',
    '자전거',
    '러닝',
    '수영',
    '배드민턴',
    '테니스',
    '볼링',
    '골프',
    '캠핑',
    '전시회 관람',
    '춤',
    '낚시'
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userData = ModalRoute.of(context)?.settings.arguments as UserModel?;
    if (userData != null && _initialData == null) {
      setState(() {
        _initialData = userData;
        selectedMbti = userData.mbti;
        selectedPreferredMbti = List.from(userData.preferredMbti);
        hobbies = List.from(userData.hobbies);
        selectedGender = userData.gender;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (selectedMbti == null) {
      _showError('MBTI를 선택해주세요');
      return;
    }

    if (selectedGender == null) {
      _showError('성별을 선택해주세요');
      return;
    }

    if (selectedPreferredMbti.isEmpty) {
      _showError('선호하는 MBTI를 하나 이상 선택해주세요');
      return;
    }

    if (hobbies.isEmpty) {
      _showError('취미를 하나 이상 선택해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _initialData?.imageUrl;

      // 새 이미지가 선택된 경우에만 업로드
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${FirebaseAuth.instance.currentUser!.uid}.jpg');

        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await _authService.updateProfile(
        name: _initialData!.name,
        imageUrl: imageUrl ?? '',
        gender: selectedGender!,
        mbti: selectedMbti!,
        preferredMbti: selectedPreferredMbti,
        hobbies: hobbies,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('프로필 수정',
        style: TextStyle(
          color: Colors.black
        ),),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: primaryColor,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (_initialData?.imageUrl != null &&
                                    _initialData!.imageUrl.isNotEmpty
                                ? NetworkImage(_initialData!.imageUrl)
                                    as ImageProvider
                                : null),
                        child: (_imageFile == null &&
                                (_initialData?.imageUrl == null ||
                                    _initialData!.imageUrl.isEmpty))
                            ? Text(
                                _initialData?.name.isNotEmpty == true
                                    ? _initialData!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.add_a_photo,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'MBTI',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mbtiTypes.map((type) {
                  final isSelected = selectedMbti == type;
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        selectedMbti = selected ? type : null;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor:
                        Theme.of(context).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text(
                '선호하는 MBTI',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Text(
                '여러 개 선택할 수 있어요',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mbtiTypes.map((type) {
                  final isSelected = selectedPreferredMbti.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedPreferredMbti.add(type);
                        } else {
                          selectedPreferredMbti.remove(type);
                        }
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor:
                        Theme.of(context).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text(
                '취미',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Text(
                '여러 개 선택할 수 있어요',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: predefinedHobbies.map((hobby) {
                  final isSelected = hobbies.contains(hobby);
                  return HobbyItem(
                    hobby: hobby,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          hobbies.remove(hobby);
                        } else {
                          hobbies.add(hobby);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text(
                '성별',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildGenderButton('남성', '남성'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGenderButton('여성', '여성'),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              CustomButton(
                text: '프로필 저장',
                onPressed: _saveProfile,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderButton(String label, String value) {
    final isSelected = selectedGender == value;
    return ElevatedButton(
      onPressed: () {
        setState(() => selectedGender = value);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? primaryColor : Colors.grey[200],
        foregroundColor: isSelected ? Colors.black : Colors.grey[600],
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
