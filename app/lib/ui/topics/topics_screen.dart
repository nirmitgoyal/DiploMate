import 'package:flutter/material.dart';

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key, required this.chapterId});
  final String chapterId;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Topics')));
}
