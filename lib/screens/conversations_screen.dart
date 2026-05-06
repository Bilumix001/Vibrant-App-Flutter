// lib/screens/conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../models/conversation_model.dart';
import 'chat_screen_new.dart';

// ── PALETA ────────────────────────────────────────────
const _greenDark   = Color(0xFF047857);
const _greenMid    = Color(0xFF16a34a);
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);

// Colores que dependen del tema — se calculan en build()
Color _bg(bool d)      => d ? const Color(0xFF0A0A0A) : const Color(0xFFF5FFF9);
Color _surface(bool d) => d ? const Color(0xFF141414) : Colors.white;
Color _textPrimary(bool d)   => d ? Colors.white          : const Color(0xFF064E3B);
Color _textSecondary(bool d) => d ? Colors.white54        : Colors.black45;
Color _border(bool d)  => d
    ? _greenDark.withValues(alpha: 0.2)
    : _greenDark.withValues(alpha: 0.15);

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationProvider.notifier).load();
    });
  }

  void _openChat({int? conversationId}) {
    final chatNotifier = ref.read(chatProvider.notifier);
    if (conversationId != null) {
      chatNotifier.loadConversation(conversationId);
    } else {
      chatNotifier.newConversation();
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreenNew()),
    ).then((_) {
      ref.read(conversationProvider.notifier).load();
    });
  }

  Future<void> _confirmDelete(BuildContext context, ConversationModel conv, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar conversación',
          style: TextStyle(
            color: _textPrimary(isDark),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          '¿Seguro que quieres eliminar "${conv.title.isNotEmpty ? conv.title : 'esta conversación'}"?',
          style: TextStyle(color: _textSecondary(isDark), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: TextStyle(color: _textSecondary(isDark))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(conversationProvider.notifier).delete(conv.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final convState = ref.watch(conversationProvider);
    final isDark    = ref.watch(themeProvider);
    final user      = authState.user;

    return Scaffold(
      backgroundColor: _bg(isDark),
      appBar: AppBar(
        backgroundColor: _bg(isDark),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.8),
          child: Container(
            height: 0.8,
            color: _greenDark.withValues(alpha: isDark ? 0.35 : 0.2),
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
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: CircleAvatar(
            backgroundColor: _greenDark,
            radius: 18,
            child: Text(
              user?.name.isNotEmpty == true
                  ? user!.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        actions: [
          // Toggle tema
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(themeProvider.notifier).state = !isDark,
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
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      size: 12, color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Logout
          IconButton(
            icon: Icon(Icons.logout,
                color: _textSecondary(isDark), size: 20),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChat(),
        backgroundColor: _greenDark,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nuevo chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),

      body: convState.isLoading
          ? Center(
              child: CircularProgressIndicator(color: _greenBright),
            )
          : convState.conversations.isEmpty
              ? _EmptyState(isDark: isDark, onNew: () => _openChat())
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: convState.conversations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final conv = convState.conversations[i];
                    return _ConvTile(
                      conv:     conv,
                      isDark:   isDark,
                      onTap:    () => _openChat(conversationId: conv.id),
                      onDelete: () => _confirmDelete(context, conv, isDark),
                    );
                  },
                ),
    );
  }
}

// ── TILE DE CONVERSACIÓN ──────────────────────────────
class _ConvTile extends StatelessWidget {
  final ConversationModel conv;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConvTile({
    required this.conv,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('conv_${conv.id}'),
      direction: DismissDirection.endToStart,
      // confirmDismiss lanza el diálogo de confirmación
      confirmDismiss: (_) async {
        onDelete();
        return false; // el borrado lo maneja _confirmDelete
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 22),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _surface(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border(isDark), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ícono
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _greenDark.withValues(alpha: isDark ? 0.2 : 0.12),
                ),
                child: Icon(Icons.chat_bubble_outline,
                    color: _greenLight, size: 18),
              ),
              const SizedBox(width: 14),
              // Título + preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.title.isNotEmpty ? conv.title : 'Sin título',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary(isDark),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (conv.preview.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        conv.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary(isDark),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Fecha
              Text(
                _formatDate(conv.updatedAt),
                style: TextStyle(
                  color: _textSecondary(isDark),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}

// ── ESTADO VACÍO ──────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onNew;
  const _EmptyState({required this.isDark, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 52,
              color: _greenDark.withValues(alpha: isDark ? 0.5 : 0.35)),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes conversaciones',
            style: TextStyle(
              color: _textSecondary(isDark),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onNew,
            child: const Text(
              'Iniciar nuevo chat',
              style: TextStyle(
                color: _greenLight,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}