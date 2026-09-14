import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/root_shell.dart';

void main() {
  runApp(
    const ProviderScope(
      child: StrideApp(),
    ),
  );
}

class StrideApp extends StatelessWidget {
  const StrideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F5D50),
          surface: const Color(0xFFF5F3ED),
        ),
      ),
      home: const RootShell(),
    );
  }
}