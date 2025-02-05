// lib/screens/auth/profile_setup_screen.dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/hobby_item.dart';
import 'package:flutter/services.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _authService = AuthService();
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? selectedMbti;
  String? selectedGender;
  List<String> selectedPreferredMbti = [];
  List<String> hobbies = [];
  File? _imageFile;
  bool _isLoading = false;

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

  final List<String> genderOptions = ['남성', '여성'];

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
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedGender == null) {
      _showError('성별을 선택해주세요');
      return;
    }
    if (selectedMbti == null) {
      _showError('MBTI를 선택해주세요');
      return;
    }
    if (selectedPreferredMbti.isEmpty) {
      _showError('선호하는 MBTI를 선택해주세요');
      return;
    }
    if (hobbies.isEmpty) {
      _showError('취미를 하나 이상 선택해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('사용자 인증 필요');

      String imageUrl;
      if (_imageFile != null) {
        final ref = _storage.ref().child('profile_images/$userId.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      } else {
        final defaultImageBytes =
            await rootBundle.load('assets/images/default_profile.png');
        final ref = _storage.ref().child('default_profile.png');
        await ref.putData(defaultImageBytes.buffer.asUint8List());
        imageUrl = await ref.getDownloadURL();
      }

      await _authService.updateProfile(
        name: _nameController.text,
        imageUrl: imageUrl,
        gender: selectedGender!,
        mbti: selectedMbti!,
        preferredMbti: selectedPreferredMbti.toList(),
        hobbies: hobbies.toList(),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e, stackTrace) {
      print('Error saving profile: $e');
      print('Stack trace: $stackTrace');
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          '프로필 설정',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                          backgroundColor: Theme.of(context).primaryColor,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : null,
                          child: _imageFile == null
                              ? Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text[0].toUpperCase()
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
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '사용하실 닉네임을 입력해주세요',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '닉네임을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text('성별', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: genderOptions.map((gender) {
                    return ChoiceChip(
                      label: Text(gender),
                      selected: selectedGender == gender,
                      onSelected: (selected) {
                        setState(() {
                          selectedGender = selected ? gender : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  '당신의 MBTI는?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: mbtiTypes.map((type) {
                    final isSelected = selectedMbti == type;
                    return FilterChip(
                      label: Text(
                        type,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected ? Colors.black : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      showCheckmark: false,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                Text(
                  '어떤 MBTI를 만나고 싶나요?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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
                  children: mbtiTypes.map((type) {
                    final isSelected = selectedPreferredMbti.contains(type);
                    return FilterChip(
                      label: Text(
                        type,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected ? Colors.black : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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
                      backgroundColor: Colors.white,
                      selectedColor:
                          Theme.of(context).primaryColor.withOpacity(0.2),
                      checkmarkColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      showCheckmark: false,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                Text(
                  '당신의 취미는?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 1.5,
                        ),
                      ),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          )
                        : const Text(
                            '프로필 저장',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
