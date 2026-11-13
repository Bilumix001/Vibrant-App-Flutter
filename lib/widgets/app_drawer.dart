// lib/widgets/app_drawer.dart  (NUEVO)
// Drawer lateral compartido por todas las pantallas post-login.
// Incluye: info de usuario, acceso rápido a las últimas 5 conversaciones,
// acceso al mapa, toggle de tema y cerrar sesión.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/navigation_provider.dart';
import '../models/conversation_model.dart';
import '../screens/chat_screen_new.dart';

// ── PALETA ────────────────────────────────────────────
const _greenDark   = Color(0xFF047857);
const _greenMid    = Color(0xFF16a34a);
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);

// Colores propios del drawer (extraídos del diseño Figma)
const _drawerBgLight = Color(0xFFADB5BD);
const _drawerBgDark  = Color(0xFF141414);

const _shadowColorLight = Color(0xFF000000);
const _shadowColorDark  = Color(0xFFF5FFF9);

// Común a ambos temas
const _textAccent       = Color(0xFF166534); // "Usuario Vibrant", nombre, títulos de sección
const _convPillBg       = Color(0xFFADB5BD); // fondo píldora de conversación
const _convPillBorder   = Color(0xFF7B7E89);
const _convPillText     = Color(0xFF7B7E89);
const _avatarGradient   = [Color(0xFF34D399), Color(0xFF166534)];
const _mapPillTextColor = Color(0xFFF5FFF9);

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(conversationProvider).conversations.isEmpty) {
        ref.read(conversationProvider.notifier).load();
      }
    });
  }

  // Cierra el drawer y va a la pestaña de Conversaciones del shell principal.
  void _goToConversations(BuildContext context) {
    Navigator.pop(context); // cierra el drawer
    ref.read(mainTabProvider.notifier).state = 0;
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  // Cierra el drawer y va a la pestaña de Mapa del shell principal.
  void _goToMap(BuildContext context) {
    Navigator.pop(context);
    ref.read(mainTabProvider.notifier).state = 1;
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  // Cierra el drawer y abre una conversación específica.
  void _openConversation(BuildContext context, ConversationModel conv) {
    Navigator.pop(context);
    ref.read(chatProvider.notifier).loadConversation(conv.id);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreenNew()),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = ref.watch(themeProvider);
    final user      = ref.watch(authProvider).user;
    final convState = ref.watch(conversationProvider);
    final last5     = convState.conversations.take(5).toList();

    final bg          = isDark ? _drawerBgDark    : _drawerBgLight;
    final shadowColor = isDark ? _shadowColorDark : _shadowColorLight;

    const drawerRadius = BorderRadius.only(
      topRight: Radius.circular(40),
      bottomRight: Radius.circular(40),
    );

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: drawerRadius),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── SOMBRA ────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: drawerRadius,
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.25),
                    offset: const Offset(4, 4),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),

          // ── FONDO CON BLUR ────────────────────────────
          ClipRRect(
            borderRadius: drawerRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                color: bg.withValues(alpha: 0.25),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── HEADER: AVATAR + NOMBRE ───────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _avatarGradient,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Usuario Vibrant',
                                    style: TextStyle(
                                      color: _textAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user?.name ?? '',
                                    style: const TextStyle(
                                      color: _textAccent,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ── NAVEGACIÓN PRINCIPAL ──────────────────────
                        const Text(
                          'Navegación principal',
                          style: TextStyle(
                            color: _textAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Conversaciones (título → tab de conversaciones)
                        GestureDetector(
                          onTap: () => _goToConversations(context),
                          child: const Text(
                            'Conversaciones',
                            style: TextStyle(
                              color: _textAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Últimas 5 conversaciones
                        if (last5.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Sin conversaciones aún',
                              style: TextStyle(
                                  color: _convPillText.withValues(alpha: 0.8),
                                  fontSize: 12),
                            ),
                          )
                        else
                          ...last5.map((conv) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _DrawerPill(
                                  label: conv.title.isNotEmpty
                                      ? conv.title
                                      : 'Sin título',
                                  background:
                                      _convPillBg.withValues(alpha: 0.25),
                                  borderColor: _convPillBorder,
                                  textColor: _mapPillTextColor,
                                  onTap: () => _openConversation(context, conv),
                                ),
                              )),

                        const SizedBox(height: 16),
                        const Text(
                          'Mapa Geográfico',
                          style: TextStyle(
                            color: _textAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DrawerPill(
                          label: '¡Conoce el Perú como nunca antes!',
                          gradient: const LinearGradient(
                            colors: _avatarGradient,
                          ),
                          textColor: _mapPillTextColor,
                          onTap: () => _goToMap(context),
                        ),

                        const Spacer(),

                        // ── TEMA ───────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tema',
                              style: TextStyle(
                                color: isDark ? _greenLight : _greenDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            // Switch reutilizado de conversations_screen.dart
                            GestureDetector(
                              onTap: () => ref
                                  .read(themeProvider.notifier)
                                  .state = !isDark,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                width: 50, height: 26,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  color: isDark
                                      ? _greenDark.withValues(alpha: 0.4)
                                      : _greenMid.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: isDark
                                        ? _greenBright.withValues(alpha: 0.5)
                                        : _greenDark.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  alignment: isDark
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.all(3),
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDark
                                            ? [_greenDark, _greenBright]
                                            : [_greenLight, _greenMid],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isDark
                                          ? Icons.dark_mode
                                          : Icons.light_mode,
                                      size: 12, color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── CERRAR SESIÓN ────────────────────────────
                        GestureDetector(
                          onTap: () => _confirmLogout(context),
                          child: Row(
                            children: const [
                              Text(
                                'Cerrar Sesión',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.logout,
                                  color: Colors.redAccent, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PÍLDORA REUTILIZABLE (items de conversación / botón de mapa) ─────
class _DrawerPill extends StatelessWidget {
  final String label;
  final Color? background;
  final Gradient? gradient;
  final Color? borderColor;
  final Color textColor;
  final VoidCallback onTap;

  const _DrawerPill({
    required this.label,
    required this.textColor,
    required this.onTap,
    this.background,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: gradient == null ? background : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null
              ? Border.all(color: borderColor!)
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}