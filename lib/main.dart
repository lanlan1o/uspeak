import 'package:flutter/material.dart';
import 'package:uspeak/screens/home_screen.dart';

void main() {
  runApp(const UspeakApp());
}

class UspeakApp extends StatelessWidget {
  const UspeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '英语朗读练习系统',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}