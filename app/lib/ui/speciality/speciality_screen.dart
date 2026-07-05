import 'package:flutter/material.dart';

class SpecialityScreen extends StatelessWidget {
  const SpecialityScreen({super.key, required this.changeMode});
  final bool changeMode;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Speciality')));
}
