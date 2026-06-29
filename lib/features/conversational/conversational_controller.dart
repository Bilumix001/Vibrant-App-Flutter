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

  bool _stopRequested    = false;
  bool _speakInterrupted = false;

  // ── CONFIGURACIÓN DE SILENCIO ─────────────────────────
  // Ajusta estos valores según tu ambiente:
  //
  // silenceThresholdDb: nivel por debajo del cual se considera silencio.
  //   Ambiente silencioso → -45.0
  //   Ambiente con ruido  → -35.0
  //
  // silenceDuration: cuánto tiempo de silencio continuo para parar.
  //   Respuestas cortas   → 1500ms
  //   Respuestas largas   → 2500ms
  //
  // maxRecordingDuration: límite absoluto de grabación.
  static const double _silenceThresholdDb    = -40.0;
  static const int    _silenceDurationMs     = 2000;  // 2s de silencio → para
  static const int    _maxRecordingSeconds   = 20;    // límite absoluto

  // Tiempo mínimo de grabación antes de empezar a detectar silencio.
  // Evita que pare inmediatamente si el usuario tarda en empezar a hablar.
  static const int    _minRecordingMs        = 1500;

  ConversationalController(this._ref)
      : super(const ConversationalState());

  // ── API PÚBLICA ───────────────────────────────────────

  Future<void> start() async {
    if (state.isActive) return;
    _stopRequested    = false;
    _speakInterrupted = false;
    await _loop();
  }

  Future<void> stop() async {
    _stopRequested = true;
    await _audioPlayer.stop();
    if (await _recorder.isRecording()) await _recorder.stop();
    state = const ConversationalState();
  }

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
      _speakInterrupted = false;

      final audioPath = await _listen();
      if (_stopRequested || audioPath == null) break;

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

      await _ref
          .read(chatProvider.notifier)
          .sendMessage(transcription, playTts: false);

      if (_stopRequested) break;

      final messages = _ref.read(chatProvider).messages;
      final lastAssistant = messages.lastWhere(
        (m) => m.role == MessageRole.assistant,
        orElse: () => throw StateError('Sin respuesta del asistente'),
      );

      await _speak(lastAssistant.text);
      if (_stopRequested) break;

      if (!_speakInterrupted) {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }

    if (!_stopRequested) state = const ConversationalState();
  }

  // ── ESCUCHAR CON DETECCIÓN DE SILENCIO ───────────────

  Future<String?> _listen() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      state = state.copyWith(error: 'Permiso de micrófono denegado');
      return null;
    }

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
          encoder:     AudioEncoder.opus,
          sampleRate:  16000,
          numChannels: 1,
        ),
        path: path,
      );

      // Espera hasta silencio o límite máximo
      await _recordUntilSilence();

      if (await _recorder.isRecording()) await _recorder.stop();
      return path;
    } catch (e) {
      debugPrint('Recorder error: $e');
      return null;
    }
  }

  /// Para de grabar cuando detecta silencio sostenido.
  ///
  /// Lógica:
  /// 1. Espera _minRecordingMs antes de empezar a chequear silencio
  ///    (para que el usuario tenga tiempo de empezar a hablar).
  /// 2. Chequea la amplitud cada 100ms.
  /// 3. Si la amplitud está por debajo de _silenceThresholdDb durante
  ///    _silenceDurationMs consecutivos → para.
  /// 4. Si el usuario vuelve a hablar, resetea el contador de silencio.
  /// 5. Límite absoluto de _maxRecordingSeconds.
  Future<void> _recordUntilSilence() async {
    const checkInterval  = Duration(milliseconds: 100);
    final silenceChecks  = _silenceDurationMs ~/ 100; // cuántos checks = silencio
    final deadline       = DateTime.now().add(
        Duration(seconds: _maxRecordingSeconds));

    int  silenceCount  = 0;
    bool voiceDetected = false; // ¿el usuario ya habló algo?

    // Fase 1: esperar el mínimo antes de detectar silencio
    await Future.delayed(Duration(milliseconds: _minRecordingMs));

    // Fase 2: detección activa
    while (!_stopRequested && DateTime.now().isBefore(deadline)) {
      await Future.delayed(checkInterval);

      try {
        final amp = await _recorder.getAmplitude();
        final db  = amp.current;

        if (db > _silenceThresholdDb) {
          // Hay voz
          voiceDetected = true;
          silenceCount  = 0;
          debugPrint('[MIC] Voz detectada: ${db.toStringAsFixed(1)} dBFS');
        } else {
          // Silencio
          if (voiceDetected) {
            // Solo contamos silencio si el usuario ya habló algo
            silenceCount++;
            debugPrint(
              '[MIC] Silencio: ${db.toStringAsFixed(1)} dBFS '
              '($silenceCount/$silenceChecks)',
            );

            if (silenceCount >= silenceChecks) {
              debugPrint('[MIC] Silencio sostenido → parando grabación');
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Amplitude error: $e');
        // Si falla la lectura de amplitud, esperar el tiempo máximo
        await Future.delayed(
            Duration(seconds: _maxRecordingSeconds - _minRecordingMs ~/ 1000));
        break;
      }
    }
  }

  // ── HABLAR ────────────────────────────────────────────

  Future<void> _speak(String texto) async {
    state = state.copyWith(status: ConversationalStatus.speaking);
    try {
      final path = await _ttsService.getAudioPath(texto);
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();

      await Future.any([
        _audioPlayer.playerStateStream.firstWhere(
          (s) =>
              s.processingState == ProcessingState.completed ||
              s.processingState == ProcessingState.idle,
        ),
        _detectVoiceActivity(),
      ]);

      if (_audioPlayer.playing) {
        _speakInterrupted = true;
        await _audioPlayer.stop();
      }
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  /// Detecta si el usuario empieza a hablar mientras el asistente habla.
  /// Resuelve el Future cuando detecta voz sostenida por ≥300ms.
  Future<void> _detectVoiceActivity() async {
    const checkInterval  = Duration(milliseconds: 100);
    const voiceThreshold = -30.0;
    const confirmCount   = 3; // 3 × 100ms = 300ms de voz continua

    int consecutive = 0;

    while (!_stopRequested) {
      await Future.delayed(checkInterval);
      try {
        final amp = await _recorder.getAmplitude();
        if (amp.current > voiceThreshold) {
          consecutive++;
          if (consecutive >= confirmCount) return;
        } else {
          consecutive = 0;
        }
      } catch (_) {
        return;
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