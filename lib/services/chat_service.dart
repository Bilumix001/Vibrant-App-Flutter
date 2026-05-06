import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Config/app_config.dart';
import '../models/chat_response.dart';
import 'auth_service.dart';

class ChatService {
  final _auth = AuthService();

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
}