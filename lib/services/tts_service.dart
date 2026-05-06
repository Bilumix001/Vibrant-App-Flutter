import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../Config/app_config.dart';
import 'auth_service.dart';

class TtsService {
  final _auth = AuthService();

  Future<String> getAudioPath(String texto) async {
    final headers = await _auth.authHeaders();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/tts/'),
      headers: headers,
      body: jsonEncode({'texto': texto}),
    );

    if (response.statusCode == 200) {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_response.mp3');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    }
    throw Exception('Error TTS: ${response.statusCode}');
  }
}