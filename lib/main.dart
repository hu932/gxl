import 'package:flutter/material.dart';

import 'chat_page.dart';
import 'theme.dart';

void main() {
  runApp(const ButterCroissantApp());
}

class ButterCroissantApp extends StatelessWidget {
  const ButterCroissantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '黄油可颂',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const ChatPage(),
    );
  }
}
