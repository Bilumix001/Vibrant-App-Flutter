import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Config/app_config.dart';
import '../models/conversation_model.dart';
import '../models/message.dart';
import 'auth_service.dart';

class ConversationService {
  final _auth = AuthService();

  Future<List<ConversationModel>> getConversations() async {
    final res = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/chat/conversations/'),
      headers: await _auth.authHeaders(),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((e) => ConversationModel.fromJson(e)).toList();
    }
    throw Exception('Error al cargar conversaciones');
  }

  Future<List<Message>> getMessages(int conversationId) async {
    final res = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/chat/conversations/$conversationId/'),
      headers: await _auth.authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final List msgs = data['messages'];
      return msgs.map((m) => Message(
        text: m['text'],
        role: m['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      )).toList();
    }
    throw Exception('Error al cargar mensajes');
  }

  Future<void> deleteConversation(int id) async {
    await http.delete(
      Uri.parse('${AppConfig.baseUrl}/api/chat/conversations/$id/'),
      headers: await _auth.authHeaders(),
    );
  }
}