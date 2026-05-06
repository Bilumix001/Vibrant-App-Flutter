import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/conversations_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isDark    = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:     _buildTheme(false), // light
      darkTheme: _buildTheme(true),  // dark
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: authState.isChecking
          ? const SplashScreen()
          : authState.isAuthenticated
              ? const ConversationsScreen()
              : const AuthScreen(),
    );
  }

  ThemeData _buildTheme(bool isDark) {
    return isDark
        ? ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0A0A0A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0A0A0A),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          )
        : ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5FFF9),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          );
  }
}