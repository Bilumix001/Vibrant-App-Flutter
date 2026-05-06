import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Config/app_config.dart';
import 'auth_service.dart';

class SttService {
  final _auth = AuthService();

  Future<String> transcribe(String audioPath) async {
    final token   = await _auth.getAccessToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/api/stt/'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        audioPath,
        filename: 'audio.wav',
      ),
    );

    final streamedResponse = await request.send();
    final response         = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['texto'];
    }
    throw Exception('Error STT: ${response.statusCode}');
  }
}