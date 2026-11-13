// lib/screens/conversations_screen.dart
// NOTA: esta pantalla ya NO tiene su propio Scaffold/AppBar/FAB.
// Ahora vive dentro de `MainShell` (ver main_shell.dart), que le provee
// el header, el drawer, el bottom nav y el botón "Nuevo chat".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../models/conversation_model.dart';
import 'chat_screen_new.dart';

// ── PALETA ────────────────────────────────────────────
const _greenDark   = Color(0xFF047857);
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);

Color _bg(bool d)            => d ? const Color(0xFF141414) : const Color(0xFFF5FFF9);
Color _surface(bool d)       => d ? const Color(0xFF141414) : const Color(0xFFE8FFF2);
Color _textPrimary(bool d)   => d ? Colors.white             : const Color(0xFF064E3B);
Color _textSecondary(bool d) => d ? Colors.white54           : Colors.black45;
Color _border(bool d)        => d
    ? const Color(0xFF047857)
    : const Color(0xFF34D399);

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

  Future<void> _confirmDelete(
      BuildContext context, ConversationModel conv, bool isDark) async {
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
          '¿Seguro que quieres eliminar '
          '"${conv.title.isNotEmpty ? conv.title : 'esta conversación'}"?',
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
    final convState = ref.watch(conversationProvider);
    final isDark    = ref.watch(themeProvider);

    return Container(
      color: _bg(isDark),
      child: convState.isLoading
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
      confirmDismiss: (_) async {
        onDelete();
        return false;
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
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _greenDark.withValues(alpha: isDark ? 0.2 : 0.12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/withoutImage.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
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