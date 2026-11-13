// lib/screens/main_shell.dart
// Shell principal post-login: envuelve Conversaciones y Mapa con un
// header compartido, un Drawer compartido y un bottom nav bar.
// Usa IndexedStack para mantener el estado de ambas pantallas al cambiar
// de pestaña (no se pierde el scroll ni las selecciones del mapa).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/vibrant_header.dart';
import 'conversations_screen.dart';
import 'map_screen.dart';
import 'chat_screen_new.dart';

// ── PALETA ────────────────────────────────────────────
const _greenDark   = Color(0xFF047857);
const _bgDark      = Color(0xFF141414);
const _bgLight     = Color(0xFFE8FFF2);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  void _openNewChat(BuildContext context, WidgetRef ref) {
    ref.read(chatProvider.notifier).newConversation();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreenNew()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final tab    = ref.watch(mainTabProvider);

    return Scaffold(
      backgroundColor: isDark ? _bgDark : _bgLight,
      drawer: const AppDrawer(),
      appBar: VibrantHeader(isDark: isDark),
      body: IndexedStack(
        index: tab,
        children: const [
          ConversationsScreen(),
          MapScreen(),
        ],
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openNewChat(context, ref),
              backgroundColor: _greenDark,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nuevo chat',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      bottomNavigationBar: _BottomNav(
        currentIndex: tab,
        onTap: (i) => ref.read(mainTabProvider.notifier).state = i,
      ),
    );
  }
}

// ── BOTTOM NAV ─────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _greenDark,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavIcon(
              icon: Icons.chat_bubble_outline_rounded,
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavIcon(
              icon: Icons.map_outlined,
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : Colors.white60,
          size: 24,
        ),
      ),
    );
  }
}