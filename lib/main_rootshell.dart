import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
 
import 'screens/root_shell.dart';
 
void main() {
  // ProviderScope must wrap the entire app exactly once, at the root.
  // It's the actual container that holds every provider's state — without
  // it, ref.watch()/ref.read() anywhere in the app throws at runtime.
  runApp(const ProviderScope(child: StrideApp()));
}
 
class StrideApp extends StatelessWidget {
  const StrideApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        brightness: Brightness.dark,
      ),
      home: const RootShell(),
    );
  }
}
 