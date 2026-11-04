import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'brand.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState()..init(),
      child: const VogelzuchtApp(),
    ),
  );
}

class VogelzuchtApp extends StatelessWidget {
  const VogelzuchtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vogelzucht',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return state.loggedIn ? const HomeScreen() : const LoginScreen();
  }
}
