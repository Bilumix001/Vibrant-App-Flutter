// lib/features/conversational/conversational_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'conversational_controller.dart';
import 'conversational_state.dart';

// ── PALETA ────────────────────────────────────────────
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);
const _greenDark   = Color(0xFF047857);

/// Overlay que reemplaza el input bar del chat cuando el modo
/// conversacional está activo. Diseño inspirado en Gemini mobile.
class ConversationalOverlay extends ConsumerWidget {
  const ConversationalOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convState  = ref.watch(conversationalProvider);
    final controller = ref.read(conversationalProvider.notifier);

    if (!convState.isActive) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _OverlayBar(
        status:     convState.status,
        onMute:     () => controller.toggleMute(),
        onStop:     () => controller.stop(),
      ),
    );
  }
}

class _OverlayBar extends StatelessWidget {
  final ConversationalStatus status;
  final VoidCallback onMute;
  final VoidCallback onStop;

  const _OverlayBar({
    required this.status,
    required this.onMute,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(32, 20, 32, 20 + bottomPad),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(
          top: BorderSide(
            color: _greenDark.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── INDICADOR DE ESTADO ─────────────────────────
          _StatusLabel(status: status),
          const SizedBox(height: 24),

          // ── BOTONES ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón micrófono (mute/unmute)
              _CircleButton(
                icon: status == ConversationalStatus.listening
                    ? Icons.mic
                    : Icons.mic_off,
                color: const Color(0xFF2A2A2A),
                iconColor: status == ConversationalStatus.listening
                    ? _greenBright
                    : Colors.white54,
                glowColor: status == ConversationalStatus.listening
                    ? _greenBright
                    : null,
                onTap: onMute,
                size: 64,
                iconSize: 28,
              ),
              const SizedBox(width: 28),
              // Botón X — volver al chat
              _CircleButton(
                icon: Icons.close,
                color: Colors.red.shade700,
                iconColor: Colors.white,
                onTap: onStop,
                size: 64,
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── LABEL DE ESTADO ───────────────────────────────────
class _StatusLabel extends StatelessWidget {
  final ConversationalStatus status;
  const _StatusLabel({required this.status});

  String get _label => switch (status) {
    ConversationalStatus.listening  => 'Escuchando…',
    ConversationalStatus.processing => 'Procesando…',
    ConversationalStatus.speaking   => 'Hablando…',
    ConversationalStatus.idle       => '',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PulsingDot(status: status),
        const SizedBox(width: 10),
        Text(
          _label,
          style: TextStyle(
            color: _statusColor(status),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Color _statusColor(ConversationalStatus s) => switch (s) {
    ConversationalStatus.listening  => _greenBright,
    ConversationalStatus.processing => _greenLight,
    ConversationalStatus.speaking   => _greenLight,
    ConversationalStatus.idle       => Colors.transparent,
  };
}

// ── DOT PULSANTE ──────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final ConversationalStatus status;
  const _PulsingDot({required this.status});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.status == ConversationalStatus.listening
        ? _greenBright
        : _greenLight;

    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.7),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ── BOTÓN CIRCULAR ────────────────────────────────────
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final Color? glowColor;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    required this.size,
    required this.iconSize,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glowColor != null
              ? [
                  BoxShadow(
                    color: glowColor!.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}