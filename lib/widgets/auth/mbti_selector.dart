import 'package:flutter/material.dart';

class MBTISelector extends StatefulWidget {
  final Function(String) onSelected;

  const MBTISelector({Key? key, required this.onSelected}) : super(key: key);

  @override
  _MBTISelectorState createState() => _MBTISelectorState();
}

class _MBTISelectorState extends State<MBTISelector> {
  final List<String> mbtiTypes = [
    'INTJ', 'INTP', 'ENTJ', 'ENTP',
    'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
    'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];

  String? selectedMBTI;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MBTI 유형을 선택하세요',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: mbtiTypes.map((type) => ChoiceChip(
            label: Text(type),
            selected: selectedMBTI == type,
            onSelected: (selected) {
              setState(() {
                selectedMBTI = selected ? type : null;
              });
              if (selected) {
                widget.onSelected(type);
              }
            },
          )).toList(),
        ),
      ],
    );
  }
}