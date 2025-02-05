import 'package:flutter/material.dart';

class HobbiesInput extends StatefulWidget {
  final Function(List<String>) onChanged;

  const HobbiesInput({Key? key, required this.onChanged}) : super(key: key);

  @override
  _HobbiesInputState createState() => _HobbiesInputState();
}

class _HobbiesInputState extends State<HobbiesInput> {
  final List<String> hobbies = [];
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '취미를 입력하세요',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '취미를 입력하고 추가 버튼을 누르세요',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  setState(() {
                    hobbies.add(_controller.text);
                    _controller.clear();
                    widget.onChanged(hobbies);
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hobbies.map((hobby) => Chip(
            label: Text(hobby),
            onDeleted: () {
              setState(() {
                hobbies.remove(hobby);
                widget.onChanged(hobbies);
              });
            },
          )).toList(),
        ),
      ],
    );
  }
}