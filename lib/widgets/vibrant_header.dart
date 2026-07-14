// lib/widgets/vibrant_header.dart
// Header compartido por todas las pantallas post-login:
// ☰ (abre el Drawer) — "Vibrant App" — avatar con inicial del usuario.
//
// Se usa dentro de `MainShell` (Conversaciones / Mapa) y en `ChatScreenNew`.
// No incluye toggle de tema ni logout: ambos viven ahora en el Drawer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

// ── PALETA ────────────────────────────────────────────
const _greenDark   = Color(0xFF047857);
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);
const _bgDark      = Color(0xFF141414);
const _bgLight     = Color(0xFFE8FFF2);

class VibrantHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool isDark;

  /// Widget extra opcional a la izquierda del avatar (ej. indicador de audio
  /// en la pantalla de chat). Se muestra entre el título y el avatar.
  final Widget? trailingExtra;

  const VibrantHeader({
    super.key,
    required this.isDark,
    this.trailingExtra,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final initial =
        (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _bgDark : _bgLight,
        border: Border(
          bottom: BorderSide(
            color: _greenDark.withValues(alpha: isDark ? 0.35 : 0.18),
            width: 0.8,
          ),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: isDark ? _greenLight : _greenDark,
            ),
            tooltip: 'Menú',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [_greenLight, _greenBright],
          ).createShader(b),
          child: const Text(
            'Vibrant App',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          if (trailingExtra != null) trailingExtra!,
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              backgroundColor: _greenDark,
              radius: 17,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}