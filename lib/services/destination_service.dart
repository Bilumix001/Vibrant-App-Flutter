// ════════════════════════════════════════════════════════
// lib/services/destination_service.dart
// ════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/destination_model.dart';
import 'auth_service.dart';

class DestinationService {
  final _auth = AuthService();

  Future<List<DestinationModel>> getDestinations() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/destinations/'),
      headers: await _auth.authHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data =
          jsonDecode(utf8.decode(response.bodyBytes));
      return data
          .map((json) => DestinationModel.fromJson(json))
          .toList();
    }
    throw Exception('Error cargando destinos: ${response.statusCode}');
  }
}


