import 'package:flutter/material.dart';
import 'package:uspeak/models/passage.dart';
import 'dart:math' as math;

class PassagesList extends StatelessWidget {
  final List<Passage> passages;
  final Function(int) onTap;

  const PassagesList({
    Key? key,
    required this.passages,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: passages.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text('${index + 1}'),
            ),
            title: Text(
              passages[index].title,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1, // 限制标题行数
              overflow: TextOverflow.ellipsis, // 超出省略
            ),
            subtitle: Text(
              '${passages[index].content.substring(0, math.min(50, passages[index].content.length))}...',
              maxLines: 1, // 限制副标题行数
              overflow: TextOverflow.ellipsis, // 超出省略
            ),
            onTap: () => onTap(index),
          ),
        );
      },
    );
  }
}