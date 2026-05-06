// lib/screens/chat_screen_new.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../providers/chat_provider.dart';
import '../models/message.dart' as app_models;
import '../features/conversational/conversational_controller.dart' as conv_ctrl;
import '../features/conversational/conversational_overlay.dart';
import '../features/conversational/message_audio_button.dart';
import '../providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';      // AGREGAR
import '../widgets/conversational_tooltip.dart';     // AGREGAR

// ── PALETA ────────────────────────────────────────────
const _bg           = Color(0xFF0A0A0A);
const _surface      = Color(0xFF141414);
const _greenDark    = Color(0xFF047857);
const _greenMid     = Color(0xFF16a34a);
const _greenBright  = Color(0xFF05c46b);
const _greenLight   = Color(0xFF34d399);
const _bgLight      = Color(0xFFF5FFF9);
const _surfaceLight = Color(0xFFE8FFF2);

// ── TEMAS ─────────────────────────────────────────────
ChatTheme _chatTheme(bool isDark) => ChatTheme(
  colors: isDark
      ? ChatColors.dark().copyWith(
          primary:              _greenDark,
          surface:              _bg,
          surfaceContainer:     _surface,
          surfaceContainerHigh: Colors.transparent,
          surfaceContainerLow:  _greenDark.withValues(alpha: 0.25),
          onPrimary:            Colors.white,
          onSurface:            _greenLight,
        )
      : ChatColors.light().copyWith(
          primary:              _greenMid,
          surface:              _bgLight,
          surfaceContainer:     _surfaceLight,
          surfaceContainerHigh: const Color(0xFFBBF7D0),
          onPrimary:            Colors.white,
          onSurface:            const Color(0xFF064E3B),
        ),
  typography: ChatTypography.standard(),
  shape: const BorderRadius.all(Radius.circular(18)),
);

ThemeData _appTheme(bool isDark) => isDark
    ? ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor:          Colors.transparent,
            statusBarBrightness:     Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
      )
    : ThemeData.light().copyWith(
        scaffoldBackgroundColor: _bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF047857),
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor:          Colors.transparent,
            statusBarBrightness:     Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
      );

// ── PANTALLA ──────────────────────────────────────────
class ChatScreenNew extends ConsumerStatefulWidget {
  const ChatScreenNew({super.key});

  @override
  ConsumerState<ChatScreenNew> createState() => _ChatScreenNewState();
}

class _ChatScreenNewState extends ConsumerState<ChatScreenNew> {
  late final InMemoryChatController _chatController;
  static const _currentUserId = 'user';

  int _syncedCount = 0;
  Future<void> _syncQueue = Future.value();
  ProviderSubscription<ChatState>? _chatSub;

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = ref.read(chatProvider).messages;
      if (initial.isNotEmpty) _syncMessages(initial);

      _chatSub = ref.listenManual<ChatState>(chatProvider, (prev, next) {
        if (next.messages.length > _syncedCount) {
          _syncMessages(next.messages);
        }
      });
    });
  }

  @override
  void dispose() {
    _chatSub?.close();
    _chatController.dispose();
    super.dispose();
  }

  void _syncMessages(List<app_models.Message> messages) {
    _syncQueue = _syncQueue.then((_) => _doSync(messages));
  }

  Future<void> _doSync(List<app_models.Message> messages) async {
    final pending = messages.skip(_syncedCount).toList();
    for (final msg in pending) {
      if (!mounted) break;
      final id = 'msg_${_syncedCount}_${DateTime.now().microsecondsSinceEpoch}';
      await _chatController.insertMessage(
        Message.text(
          id:        id,
          authorId:  msg.role == app_models.MessageRole.user ? 'user' : 'assistant',
          text:      msg.text,
          createdAt: DateTime.now(),
        ),
      );
      _syncedCount++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final notifier  = ref.read(chatProvider.notifier);
    final isDark    = ref.watch(themeProvider);
    final convState = ref.watch(conv_ctrl.conversationalProvider);
    final convCtrl  = ref.read(conv_ctrl.conversationalProvider.notifier);
    final onboardingSeen = ref.watch(onboardingProvider);
    final isConvActive = convState.isActive;

    return Theme(
      data: _appTheme(isDark),
      child: Scaffold(

        // ── APP BAR ──────────────────────────────────────
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: isDark
                ? BoxDecoration(
                    color: _bg,
                    border: Border(
                      bottom: BorderSide(
                        color: _greenDark.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                  )
                : const BoxDecoration(color: Color(0xFF047857)),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7, height: 7,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _greenBright,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _greenBright.withValues(alpha: 0.7),
                          blurRadius: 6, spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [_greenLight, _greenBright],
                    ).createShader(b),
                    child: const Text(
                      'Vibrant App',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: chatState.isPlayingAudio
                      ? Padding(
                          key: const ValueKey('audio'),
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.graphic_eq_rounded,
                              color: _greenLight, size: 20),
                        )
                      : const SizedBox.shrink(key: ValueKey('no-audio')),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
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
                            : Colors.white.withValues(alpha: 0.3),
                        border: Border.all(
                          color: isDark
                              ? _greenBright.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.6),
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
              ],
            ),
          ),
        ),

        // ── BODY ─────────────────────────────────────────
        body: Stack(
          children: [

            // ── CHAT ───────────────────────────────────────
            Chat(
              currentUserId: _currentUserId,
              chatController: _chatController,
              resolveUser: (id) async => id == 'user'
                  ? const User(id: 'user',      name: 'Tú')
                  : const User(id: 'assistant', name: 'Asistente'),
              onMessageSend: (text) => notifier.sendMessage(text),
              theme: _chatTheme(isDark),
              backgroundColor: isDark ? _bg : _bgLight,
              builders: Builders(
                // Bienvenida cuando no hay mensajes
                emptyChatListBuilder: (context) =>
                    _WelcomeState(isDark: isDark),

                // ── BURBUJA MESSENGER ─────────────────────
                textMessageBuilder: (
                  context,
                  message,
                  messageIndex, {
                  required bool isSentByMe,
                  MessageGroupStatus? groupStatus,
                }) {
                  final isAssistant = !isSentByMe;
                  final parts = message.id.split('_');
                  final idx   = parts.length >= 2 ? int.tryParse(parts[1]) : null;
                  final appMsg = (isAssistant && idx != null && idx < chatState.messages.length)
                      ? chatState.messages[idx]
                      : null;

                  // Colores de burbuja
                  final bubbleColor = isSentByMe
                      ? (isDark ? _greenDark : _greenMid)
                      : (isDark ? _surface   : Colors.white);

                  // Color de texto — CORREGIDO: usuario siempre blanco
                  final textColor = isSentByMe
                      ? Colors.white
                      : (isDark ? _greenLight : const Color(0xFF1A3C2E));

                  // Forma messenger: cola en esquina inferior del lado del remitente
                  final bubbleRadius = BorderRadius.only(
                    topLeft:     const Radius.circular(18),
                    topRight:    const Radius.circular(18),
                    bottomLeft:  Radius.circular(isSentByMe ? 18 : 4),
                    bottomRight: Radius.circular(isSentByMe ? 4 : 18),
                  );

                  return Align(
                    alignment: isSentByMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      margin: EdgeInsets.only(
                        top:    2,
                        bottom: 2,
                        left:   isSentByMe ? 56 : 8,
                        right:  isSentByMe ? 8  : 56,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: bubbleRadius,
                        boxShadow: [
                          BoxShadow(
                            color: (isSentByMe ? _greenBright : Colors.black)
                                .withValues(alpha: isDark ? 0.25 : 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: (!isSentByMe && !isDark)
                            ? Border.all(
                                color: _greenMid.withValues(alpha: 0.18),
                                width: 0.8,
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.text,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                          if (isAssistant && appMsg != null) ...[
                            const SizedBox(height: 8),
                            MessageAudioButton(
                              text:   appMsg.text,
                              isDark: isDark,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── INDICADOR "ESCRIBIENDO" ─────────────────────
            if (chatState.isLoading)
              Positioned(
                bottom: 88,
                left: 0, right: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? _surface : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _greenDark.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _greenBright.withValues(alpha: 0.18),
                            blurRadius: 16, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TypingDots(isDark: isDark),
                          const SizedBox(width: 10),
                          Text(
                            'Escribiendo',
                            style: TextStyle(
                              color: isDark
                                  ? _greenLight.withValues(alpha: 0.9)
                                  : const Color(0xFF047857),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── BOTÓN MICRÓFONO ─────────────────────────────
            if (!isConvActive)
              Positioned(
                bottom: 122,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: chatState.isRecording
                          ? [Colors.red.shade700, Colors.red.shade400]
                          : [_greenDark, _greenBright],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (chatState.isRecording
                                ? Colors.red
                                : _greenBright)
                            .withValues(alpha: 0.45),
                        blurRadius: 16, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onLongPress: chatState.isLoading
                        ? null
                        : () async {
                            // ✅ Feedback háptico al activar modo conversacional
                            await HapticFeedback.mediumImpact();
                            await convCtrl.start();
                          },
                    child: FloatingActionButton(
                      heroTag: 'mic_fab',
                      onPressed: chatState.isLoading
                          ? null
                          : () async {
                              if (chatState.isRecording) {
                                await notifier.stopRecordingAndSend();
                              } else {
                                await notifier.startRecording();
                              }
                            },
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Icon(
                        chatState.isRecording
                            ? Icons.stop_rounded
                            : Icons.mic,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            if (!onboardingSeen && !isConvActive)
              Positioned(
                bottom: 178, // justo encima del botón mic
                right: 16,
                child: ConversationalTooltip(isDark: isDark),
              ),

            // ── OVERLAY CONVERSACIONAL ──────────────────────
            const ConversationalOverlay(),

            // ── BANNER DE ERROR ─────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: chatState.error != null ? 10 : -80,
              left: 16, right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: chatState.error != null ? 1.0 : 0.0,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.shade800.withValues(alpha: 0.7),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.15),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            chatState.error ?? '',
                            style: const TextStyle(
                              color: Colors.white70, fontSize: 13,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => notifier.clearError(),
                          child: const Icon(Icons.close,
                              color: Colors.white38, size: 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ESTADO VACÍO / BIENVENIDA ─────────────────────────
class _WelcomeState extends StatelessWidget {
  final bool isDark;
  const _WelcomeState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: isDark
                  ? _greenDark.withValues(alpha: 0.5)
                  : _greenMid.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Hola! Soy tu guía virtual.\n¿En qué puedo ayudarte?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? _greenLight.withValues(alpha: 0.7)
                    : const Color(0xFF047857),
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Escribe un mensaje o mantén presionado el micrófono\npara activar el modo conversacional.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white24 : Colors.black26,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PUNTOS "ESCRIBIENDO" ──────────────────────────────
class _TypingDots extends StatefulWidget {
  final bool isDark;
  const _TypingDots({required this.isDark});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _anims = List.generate(3, (i) {
      final start = i * 0.2;
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, start + 0.4, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final op = _anims[i].value;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 5, height: 5,
            decoration: BoxDecoration(
              color: _greenBright.withValues(alpha: op),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _greenBright.withValues(alpha: op * 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}