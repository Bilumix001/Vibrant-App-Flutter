// lib/widgets/app_drawer.dart  (NUEVO)
// Drawer lateral compartido por todas las pantallas post-login.
// Incluye: info de usuario, acceso rápido a las últimas 5 conversaciones,
// acceso al mapa, toggle de tema y cerrar sesión.

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
const _drawerBgLight   = Color(0xFFADB5BD);
const _itemBgLight     = Color(0xFFACB4BC);
const _itemActiveLight = Color(0xFF6EC5AA);
const _mapBtnLight     = Color(0xFF14BA83);
const _toggleTrackOn   = Color(0xFF54BE90);

// Equivalentes para modo oscuro, coherentes con la paleta ya usada en el
// resto de la app (no había mockup oscuro del drawer, así que se deriva
// del mismo esquema verde/negro que usan chat_screen_new y map_screen).
const _drawerBgDark   = Color(0xFF141414);
const _itemBgDark     = Color(0xFF1F1F1F);
const _itemActiveDark = Color(0xFF0B4D3A);
const _mapBtnDark     = Color(0xFF047857);

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

    final bg         = isDark ? _drawerBgDark   : _drawerBgLight;
    final itemBg      = isDark ? _itemBgDark     : _itemBgLight;
    final mapBtnColor = isDark ? _mapBtnDark     : _mapBtnLight;
    final textPrimary = isDark ? Colors.white    : const Color(0xFF0B2E22);
    final textMuted   = isDark ? Colors.white60  : const Color(0xFF3A4A44);

    return Drawer(
      backgroundColor: bg,
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
                  CircleAvatar(
                    backgroundColor: _greenDark,
                    radius: 32,
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
                        Text(
                          'Usuario Vibrant',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.name ?? '',
                          style: TextStyle(
                            color: textPrimary,
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
              Text(
                'Navegación principal',
                style: TextStyle(
                  color: isDark ? _greenLight : _greenDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),

              // Conversaciones (título → tab de conversaciones)
              GestureDetector(
                onTap: () => _goToConversations(context),
                child: Text(
                  'Conversaciones',
                  style: TextStyle(
                    color: textPrimary,
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
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                )
              else
                ...last5.map((conv) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DrawerPill(
                        label: conv.title.isNotEmpty
                            ? conv.title
                            : 'Sin título',
                        background: itemBg,
                        textColor: textPrimary,
                        onTap: () => _openConversation(context, conv),
                      ),
                    )),

              const SizedBox(height: 16),
              Text(
                'Mapa Geográfico',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _DrawerPill(
                label: '¡Conoce el Perú como nunca antes!',
                background: mapBtnColor,
                textColor: Colors.white,
                bordered: true,
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
                  GestureDetector(
                    onTap: () =>
                        ref.read(themeProvider.notifier).state = !isDark,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 50,
                      height: 28,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _toggleTrackOn.withValues(alpha: 0.9),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        alignment: isDark
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: _greenBright,
                            shape: BoxShape.circle,
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
                    Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PÍLDORA REUTILIZABLE (items de conversación / botón de mapa) ─────
class _DrawerPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;
  final bool bordered;
  final VoidCallback onTap;

  const _DrawerPill({
    required this.label,
    required this.background,
    required this.textColor,
    required this.onTap,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: bordered
              ? Border.all(color: _greenDark.withValues(alpha: 0.4))
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