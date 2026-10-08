import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'chat_page.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ChatStore.init();
  // 探测服务端点：8080 优先，不通则自动改用 80 端口反代
  await DifyConfig.resolve();
  runApp(const ButterCroissantApp());
}

class ButterCroissantApp extends StatelessWidget {
  const ButterCroissantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '黄油可颂',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(dark: false),
      darkTheme: buildTheme(dark: true),
      themeMode: ThemeMode.system,
      // 声明中文支持：否则 iOS 可能只给英文键盘（切不了中文输入法）
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      home: const ChatPage(),
    );
  }
}
