// lib/services/tts_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class TtsService {
  final _auth = AuthService();
  final Map<String, String> _cache = {};

  // ── STREAMING (más rápido) ────────────────────────────
  /// Descarga el WAV en chunks escribiéndolo al disco
  /// y devuelve el path cuando el archivo está completo.
  /// El archivo ya está listo para reproducir con just_audio.
  Future<String> getAudioPathStreaming(String texto) async {
    if (_cache.containsKey(texto)) {
      final cached = _cache[texto]!;
      if (await File(cached).exists()) return cached;
      _cache.remove(texto);
    }

    

    final headers = await _auth.authHeaders();
    headers['Accept'] = 'audio/wav';

    final hash = texto.hashCode.abs();
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/tts_$hash.wav';
    final file = File(path);
    final sink = file.openWrite();

    final client  = http.Client();
    final request = http.Request(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/api/tts/?stream=true'),
    )
      ..headers.addAll(headers)
      ..body = jsonEncode({'texto': texto});

    try {
      final streamed = await client.send(request);
      final t0 = DateTime.now();
      debugPrint('[TIMING] TTS conexión establecida: ${DateTime.now().difference(t0).inMilliseconds}ms');

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw Exception('Error TTS: ${streamed.statusCode} $body');
      }

      bool firstChunk = true;
      await for (final chunk in streamed.stream) {
        if (firstChunk) {
          debugPrint('[TIMING] Primer chunk audio: ${DateTime.now().difference(t0).inMilliseconds}ms');
          firstChunk = false;
        }
        sink.add(chunk);
      }

      debugPrint('[TIMING] TTS descarga completa: ${DateTime.now().difference(t0).inMilliseconds}ms');

      await sink.flush();
      await sink.close();

      _cache[texto] = path;
      return path;
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  // ── COMPLETO (compatibilidad con MessageAudioButton) ──
  Future<String> getAudioPath(String texto) async {
    // Usa streaming internamente — mismo resultado, misma interfaz
    return getAudioPathStreaming(texto);
  }

  Future<void> clearCache() async {
    for (final path in _cache.values) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _cache.clear();
  }
}