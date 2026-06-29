// lib/services/tts_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class TtsService {
  final _auth = AuthService();
  final Map<String, String> _cache = {};

  // ── STREAMING (rápido) ────────────────────────────────
  Future<String> getAudioPathStreaming(String texto) async {
    if (_cache.containsKey(texto)) {
      final cached = _cache[texto]!;
      if (await File(cached).exists()) return cached;
      _cache.remove(texto);
    }

    final headers = await _auth.authHeaders();
    headers['Accept'] = 'audio/mpeg'; // ← MP3 ahora

    final hash = texto.hashCode.abs();
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/tts_$hash.mp3'; // ← extensión mp3
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
      debugPrint('[TTS] Conexión establecida');

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw Exception('Error TTS: ${streamed.statusCode} $body');
      }

      bool firstChunk = true;
      await for (final chunk in streamed.stream) {
        if (firstChunk) {
          debugPrint('[TTS] Primer chunk recibido');
          firstChunk = false;
        }
        sink.add(chunk);
      }

      await sink.flush();
      await sink.close();
      debugPrint('[TTS] Descarga completa');

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

  // getAudioPath usa streaming internamente — misma interfaz para todo el código
  Future<String> getAudioPath(String texto) =>
      getAudioPathStreaming(texto);

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