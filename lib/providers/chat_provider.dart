import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/conversation_service.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isRecording;
  final bool isPlayingAudio;
  final String? error;
  final int? conversationId;

  const ChatState({
    this.messages       = const [],
    this.isLoading      = false,
    this.isRecording    = false,
    this.isPlayingAudio = false,
    this.error,
    this.conversationId,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isRecording,
    bool? isPlayingAudio,
    Object? error          = _keep,
    Object? conversationId = _keep,
  }) {
    return ChatState(
      messages:       messages       ?? this.messages,
      isLoading:      isLoading      ?? this.isLoading,
      isRecording:    isRecording    ?? this.isRecording,
      isPlayingAudio: isPlayingAudio ?? this.isPlayingAudio,
      error:          error          == _keep ? this.error          : error          as String?,
      conversationId: conversationId == _keep ? this.conversationId : conversationId as int?,
    );
  }
}

const _keep = Object();

class ChatNotifier extends StateNotifier<ChatState> {
  final _chatService  = ChatService();
  final _ttsService   = TtsService();
  final _sttService   = SttService();
  final _convService  = ConversationService();
  final _audioPlayer  = AudioPlayer();
  final _recorder     = AudioRecorder();

  ChatNotifier() : super(const ChatState());

  // ── Carga conversación existente con sus mensajes ──
  Future<void> loadConversation(int id) async {
    state = const ChatState(isLoading: true);
    try {
      final messages = await _convService.getMessages(id);
      state = ChatState(
        conversationId: id,
        messages: messages,
        isLoading: false,
      );
    } catch (e) {
      state = ChatState(
        conversationId: id,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // ── Nueva conversación vacía ───────────────────────
  void newConversation() => state = const ChatState();

  // ── Enviar mensaje ────────────────────────────────
  Future<void> sendMessage(String texto, {bool playTts = true}) async {
    if (texto.trim().isEmpty) return;

    state = state.copyWith(
      messages: [...state.messages, Message(text: texto, role: MessageRole.user)],
      isLoading: true,
      error: null,
    );

    try {
      final response = await _chatService.sendMessage(
        mensaje:        texto,
        conversationId: state.conversationId,
      );

      state = state.copyWith(
        messages: [
          ...state.messages,
          Message(
            text:    response.respuesta,
            role:    MessageRole.assistant,
            usedRag: response.usarRag,
            sources: response.fuentes,
          ),
        ],
        isLoading:      false,
        conversationId: response.conversationId,
      );

      if (playTts) await _playTts(response.respuesta);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _playTts(String texto) async {
    try {
      state = state.copyWith(isPlayingAudio: true);
      final path = await _ttsService.getAudioPath(texto);
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio no disponible: $e');
    } finally {
      state = state.copyWith(isPlayingAudio: false);
    }
  }

  Future<void> speakLastResponse() async {
    final lastAssistant = state.messages.lastWhere(
      (m) => m.role == MessageRole.assistant,
      orElse: () => throw Exception('No hay respuesta del asistente'),
    );
    state = state.copyWith(isPlayingAudio: true);
    try {
      final path = await _ttsService.getAudioPath(lastAssistant.text);
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error TTS: $e');
    } finally {
      state = state.copyWith(isPlayingAudio: false);
    }
  }

  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      state = state.copyWith(error: 'Permiso de micrófono denegado');
      return;
    }
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/recording.wav';
    await _recorder.start(
      const RecordConfig(
        encoder:     AudioEncoder.wav,
        sampleRate:  16000,
        numChannels: 1,
      ),
      path: path,
    );
    state = state.copyWith(isRecording: true);
  }

  Future<void> stopRecordingAndSend() async {
    final path = await _recorder.stop();
    state = state.copyWith(isRecording: false);
    if (path == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final texto = await _sttService.transcribe(path);
      await sendMessage(texto);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(),
);