// Mapea exactamente tu ChatResponse de Pydantic
class ChatResponse {
  final String respuesta;
  final bool usarRag;
  final List<String> fuentes;
  final int conversationId;

  ChatResponse({
    required this.respuesta,
    required this.usarRag,
    required this.fuentes,
    required this.conversationId,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      respuesta: json['respuesta'],
      usarRag: json['usar_rag'],
      fuentes: List<String>.from(json['fuentes'] ?? []),
      conversationId: json['conversation_id'],
    );
  }
}