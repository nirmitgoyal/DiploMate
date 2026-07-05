import 'package:flutter/material.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen.browse({super.key, required this.qnaId, this.topicId})
      : isQueue = false;
  const ReaderScreen.queuePlaceholder({super.key})
      : qnaId = null,
        topicId = null,
        isQueue = true;

  final String? qnaId;
  final String? topicId;
  final bool isQueue;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Reader')));
}
