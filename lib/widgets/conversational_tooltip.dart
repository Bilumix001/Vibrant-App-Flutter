// lib/widgets/conversational_tooltip.dart  (NUEVO)
// Tooltip de onboarding que aparece sobre el botón del micrófono
// la primera vez que el usuario abre el chat.
// Se descarta tocando en cualquier lugar o esperando 5 segundos.

// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/onboarding_provider.dart';

const _greenDark   = Color(0xFF047857);
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);

class ConversationalTooltip extends ConsumerStatefulWidget {
  final bool isDark;
  const ConversationalTooltip({super.key, required this.isDark});

  @override
  ConsumerState<ConversationalTooltip> createState() =>
      _ConversationalTooltipState();
}

class _ConversationalTooltipState
    extends ConsumerState<ConversationalTooltip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Auto-dismiss después de 5 segundos
    Future.delayed(const Duration(seconds: 5), _dismiss);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) ref.read(onboardingProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF1C1C1C)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _greenDark.withValues(alpha: 0.4),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                      alpha: widget.isDark ? 0.35 : 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_greenDark, _greenBright],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Modo conversacional',
                      style: TextStyle(
                        color: widget.isDark
                            ? _greenLight
                            : const Color(0xFF064E3B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mantén presionado el micrófono\npara activarlo',
                      style: TextStyle(
                        color: widget.isDark
                            ? Colors.white54
                            : Colors.black45,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.close,
                    size: 14,
                    color: widget.isDark ? Colors.white24 : Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}