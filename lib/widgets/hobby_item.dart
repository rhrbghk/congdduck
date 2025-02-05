import 'package:flutter/material.dart';

class HobbyItem extends StatelessWidget {
  final String hobby;
  final bool isSelected;
  final VoidCallback onTap;

  const HobbyItem({
    super.key,
    required this.hobby,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 아이콘이 있는 취미들 매핑
    final hobbyIcons = {
      '영화 관람': 'movie.png',
      '독서': 'Reading.png',
      '음악 감상': 'Listening to music.png',
      '그림 그리기': 'Drawing.png',
      '악기 연주': 'playing musical instruments.png',
      '글쓰기': 'Writing.png',
      '맛집탐방': 'visiting good restaurants.png',
      '술': 'Alcohol.png',
      '요리': 'cooking.png',
      '베이킹': 'Baking.png',
      '보드게임': 'board game.png',
      '퍼즐': 'Puzzle.png',
      '사진 촬영': 'photo shoot.png',
      '뜨개질': 'Knitting.png',
      '피규어/프라모델': 'plastic model.png',
      '홈 가드닝': 'Home Gardening.png',
      '게임': 'game.png',
      '등산': 'hiking.png',
      '헬스': 'Health.png',
      '요가/필라테스': 'Yoga.png',
      '자전거': 'bicycle.png',
      '러닝': 'Running.png',
      '수영': 'swimming.png',
      '배드민턴': 'Badminton.png',
      '테니스': 'Tennis.png',
      '볼링': 'Bowling.png',
      '골프': 'Golf.png',
      '캠핑': 'Camping.png',
      '전시회 관람': 'viewing the exhibition.png',
      '연극 및 뮤지컬 관람': 'drama.png',
      '춤': 'Dance.png',
      '낚시': 'Fishing.png',
    };

    // 해당 취미에 아이콘이 있는 경우
    if (hobbyIcons.containsKey(hobby)) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        )
                      : null,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/${hobbyIcons[hobby]}',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hobby,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 아이콘이 없는 취미들은 기존 스타일 유지
    return FilterChip(
      label: Text(
        hobby,
        style: TextStyle(
          fontSize: 14,
          color: isSelected ? Colors.black : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
}
