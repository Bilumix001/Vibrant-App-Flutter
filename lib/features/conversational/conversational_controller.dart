// lib/features/conversational/conversational_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';
import 'conversational_state.dart';

class ConversationalController extends StateNotifier<ConversationalState> {
  final Ref _ref;
  final _ttsService  = TtsService();
  final _sttService  = SttService();
  final _audioPlayer = AudioPlayer();
  final _recorder    = AudioRecorder();

  bool _stopRequested = false;

  // ✅ FIX INTERRUPCIÓN: bandera para saber si el audio fue interrumpido
  // por el usuario hablando durante la reproducción.
  bool _speakInterrupted = false;

  ConversationalController(this._ref)
      : super(const ConversationalState());

  // ── API PÚBLICA ───────────────────────────────────────

  Future<void> start() async {
    if (state.isActive) return;
    _stopRequested     = false;
    _speakInterrupted  = false;
    await _loop();
  }

  Future<void> stop() async {
    _stopRequested = true;
    await _audioPlayer.stop();
    if (await _recorder.isRecording()) await _recorder.stop();
    state = const ConversationalState(); // idle
  }

  /// Silencia el micrófono durante la grabación.
  Future<void> toggleMute() async {
    if (await _recorder.isRecording()) {
      await _recorder.pause();
    } else if (state.status == ConversationalStatus.listening) {
      await _recorder.resume();
    }
  }

  // ── LOOP PRINCIPAL ────────────────────────────────────

  Future<void> _loop() async {
    while (!_stopRequested) {

      // 1. ESCUCHAR
      // Si el asistente estaba hablando y se interrumpió, el audio ya
      // fue detenido en _listenDuringSpeak(); simplemente continuamos.
      _speakInterrupted = false;
      final audioPath = await _listen();
      if (_stopRequested || audioPath == null) break;

      // 2. TRANSCRIBIR
      state = state.copyWith(status: ConversationalStatus.processing);
      String transcription;
      try {
        transcription = await _sttService.transcribe(audioPath);
      } catch (e) {
        debugPrint('STT error: $e');
        if (!_stopRequested) continue;
        break;
      }

      if (_stopRequested) break;
      if (transcription.trim().isEmpty) continue;

      // Comando de salida por voz
      final lower = transcription.toLowerCase();
      if (['salir', 'adiós', 'terminar', 'chao', 'adios']
          .any((w) => lower.contains(w))) {
        await stop();
        return;
      }

      // 3. ENVIAR AL CHAT
      // playTts: false → el TTS automático de chatProvider está desactivado;
      // lo manejamos nosotros para poder interrumpirlo.
      await _ref
          .read(chatProvider.notifier)
          .sendMessage(transcription, playTts: false);

      if (_stopRequested) break;

      // 4. REPRODUCIR RESPUESTA
      final messages = _ref.read(chatProvider).messages;
      final lastAssistant = messages.lastWhere(
        (m) => m.role == MessageRole.assistant,
        orElse: () => throw StateError('Sin respuesta del asistente'),
      );

      await _speak(lastAssistant.text);
      if (_stopRequested) break;

      // Si el usuario interrumpió mientras hablaba, volvemos a escuchar
      // de inmediato sin pausa extra.
      if (!_speakInterrupted) {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }

    if (!_stopRequested) state = const ConversationalState();
  }

  // ── HELPERS ───────────────────────────────────────────

  /// Graba audio del usuario.
  /// Mientras graba, si el asistente todavía estuviera hablando
  /// (caso de carrera), lo detiene primero.
  Future<String?> _listen() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      state = state.copyWith(error: 'Permiso de micrófono denegado');
      return null;
    }

    // Detener cualquier reproducción activa
    await _audioPlayer.stop();

    state = state.copyWith(
      status: ConversationalStatus.listening,
      error:  null,
    );

    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/conv_recording.wav';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder:     AudioEncoder.wav,
          sampleRate:  16000,
          numChannels: 1,
        ),
        path: path,
      );

      // Graba máximo 15 s
      await Future.delayed(const Duration(seconds: 15));

      if (await _recorder.isRecording()) await _recorder.stop();
      return path;
    } catch (e) {
      debugPrint('Recorder error: $e');
      return null;
    }
  }

  /// Reproduce el TTS de la respuesta del asistente.
  /// ✅ FIX INTERRUPCIÓN: mientras reproduce, escucha en paralelo si el
  /// usuario empieza a hablar (detecta energía del micrófono via Record).
  /// Si hay voz, detiene el audio y salta directo a grabar.
  Future<void> _speak(String texto) async {
    state = state.copyWith(status: ConversationalStatus.speaking);
    try {
      final path = await _ttsService.getAudioPath(texto);
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();

      // Espera a que termine O a que el usuario interrumpa hablando
      await Future.any([
        // Camino 1: reproducción termina sola
        _audioPlayer.playerStateStream.firstWhere(
          (s) =>
              s.processingState == ProcessingState.completed ||
              s.processingState == ProcessingState.idle,
        ),
        // Camino 2: el usuario empieza a hablar (detección de voz)
        _detectVoiceActivity(),
      ]);

      // Si llegamos aquí por voz, detenemos el audio
      if (_audioPlayer.playing) {
        _speakInterrupted = true;
        await _audioPlayer.stop();
      }

    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  /// Detecta actividad de voz del micrófono mientras el asistente habla.
  /// Usa la amplitud del micrófono (Record v5 API).
  /// Resuelve el Future cuando detecta voz sostenida por ≥300 ms.
  Future<void> _detectVoiceActivity() async {
    const checkInterval  = Duration(milliseconds: 100);
    const voiceThreshold = -30.0; // dBFS — ajustar según el dispositivo
    const confirmCount   = 3;     // 3 × 100ms = 300ms de voz continua

    int consecutive = 0;

    while (!_stopRequested) {
      await Future.delayed(checkInterval);
      try {
        final amp = await _recorder.getAmplitude();
        if (amp.current > voiceThreshold) {
          consecutive++;
          if (consecutive >= confirmCount) return; // voz detectada
        } else {
          consecutive = 0;
        }
      } catch (_) {
        // El micrófono puede no estar disponible mientras el player reproduce;
        // en ese caso simplemente no interrumpimos.
        return Future.value();
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

// ── PROVIDER ──────────────────────────────────────────
final conversationalProvider =
    StateNotifierProvider<ConversationalController, ConversationalState>(
  (ref) => ConversationalController(ref),
);