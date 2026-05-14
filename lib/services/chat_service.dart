import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/chat_response.dart';
import 'auth_service.dart';

class ChatService {
  final _auth = AuthService();

  // ── RESPUESTA COMPLETA (mantener para STT/modo conv.) ─
  Future<ChatResponse> sendMessage({
    required String mensaje,
    int? conversationId,
  }) async {
    final body = <String, dynamic>{'mensaje': mensaje};
    if (conversationId != null) body['conversation_id'] = conversationId;

    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/chat/'),
      headers: await _auth.authHeaders(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return ChatResponse.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception('Error ${res.statusCode}: ${res.body}');
  }

  // ── STREAMING ─────────────────────────────────────────
  /// Devuelve un Stream de eventos SSE.
  /// Emite [StreamEvent] de tres tipos:
  ///   - StreamEventMeta     → conversation_id, fuentes, usar_rag
  ///   - StreamEventChunk    → fragmento de texto
  ///   - StreamEventDone     → texto completo final
  Stream<StreamEvent> sendMessageStream({
    required String mensaje,
    int? conversationId,
  }) async* {
    final body = <String, dynamic>{'mensaje': mensaje};
    if (conversationId != null) body['conversation_id'] = conversationId;

    final headers = await _auth.authHeaders();
    headers['Accept'] = 'text/event-stream';

    // http.Client mantiene la conexión abierta para leer chunks
    final client  = http.Client();
    final request = http.Request(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/api/chat/stream/'),
    )
      ..headers.addAll(headers)
      ..body = jsonEncode(body);

    try {
      final streamed = await client.send(request);

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw Exception('Error ${streamed.statusCode}: $body');
      }

      // Buffer para líneas incompletas entre chunks TCP
      final buffer = StringBuffer();

      await for (final bytes in streamed.stream) {
        buffer.write(utf8.decode(bytes));
        final raw = buffer.toString();
        buffer.clear();

        // Cada evento SSE termina en "\n\n"
        final events = raw.split('\n\n');

        // El último elemento puede estar incompleto — lo guardamos
        for (var i = 0; i < events.length - 1; i++) {
          final line = events[i].trim();
          if (!line.startsWith('data:')) continue;

          final jsonStr = line.substring(5).trim();
          if (jsonStr.isEmpty) continue;

          final Map<String, dynamic> data = jsonDecode(jsonStr);
          final type = data['type'] as String?;

          switch (type) {
            case 'meta':
              yield StreamEventMeta(
                conversationId: data['conversation_id'] as int,
                usarRag:        data['usar_rag']        as bool,
                fuentes: (data['fuentes'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [],
              );
            case 'chunk':
              yield StreamEventChunk(text: data['text'] as String);
            case 'done':
              yield StreamEventDone(fullText: data['full_text'] as String);
            case 'error':
              throw Exception(data['detail']);
          }
        }

        // Guardar el fragmento incompleto para el próximo chunk TCP
        if (events.last.isNotEmpty) {
          buffer.write(events.last);
        }
      }
    } finally {
      client.close();
    }
  }
}

// ── MODELOS DE EVENTOS ────────────────────────────────
sealed class StreamEvent {}

class StreamEventMeta extends StreamEvent {
  final int conversationId;
  final bool usarRag;
  final List<String> fuentes;
  StreamEventMeta({
    required this.conversationId,
    required this.usarRag,
    required this.fuentes,
  });
}

class StreamEventChunk extends StreamEvent {
  final String text;
  StreamEventChunk({required this.text});
}

class StreamEventDone extends StreamEvent {
  final String fullText;
  StreamEventDone({required this.fullText});
}